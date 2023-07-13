//
// XmppSessionLogic.swift
//
// TigaseSwift
// Copyright (C) 2016 "Tigase, Inc." <office@tigase.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. Look for COPYING file in the top folder.
// If not, see http://www.gnu.org/licenses/.
//

import Foundation
import TigaseLogging
import Combine

extension StreamFeatures.StreamFeature {
    public static let startTLS = StreamFeatures.StreamFeature(name: "starttls", xmlns: "urn:ietf:params:xml:ns:xmpp-tls");
    public static let compressionZLIB = StreamFeatures.StreamFeature(.init(name: "compression", xmlns: "http://jabber.org/features/compress", value: nil), .init(name: "method", xmlns: nil, value: "zlib"));
}

/// Protocol which is used by other class to interact with classes responsible for session logic.
public protocol XmppSessionLogic: AnyObject {
    
    var state:XMPPClient.State { get }
    var statePublisher: Published<XMPPClient.State>.Publisher { get }
    
    var connector: Connector { get }
    
    var streamLogger: StreamLogger? { get set }
    
    func start();
    func stop(force: Bool) async;
    
    /// Register to listen for events
    func bind();
    /// Unregister to stop listening for events
    func unbind() async;
        
    func send(stanza: Stanza) async throws;
    
    /// Called to send data to keep connection open
    func keepalive() async throws;
    
}

/** 
 Implementation of XmppSessionLogic protocol which is resposible for
 following XMPP session logic for socket connections.
 */
open class SocketSessionLogic: XmppSessionLogic {
    
    let logger = Logger(subsystem: "TigaseSwift", category: "SocketSessionLogic")
        
    private weak var context: Context?;
    private let modulesManager: XmppModulesManager;
    
    public let connector: Connector;
    private let responseManager:ResponseManager;

    public var streamLogger: StreamLogger? {
        get {
            return connector.streamLogger;
        }
        set {
            connector.streamLogger = newValue;
        }
    }
    
    /// Keeps state of XMPP stream - this is not the same as state of `SocketConnection`
    @Published
    open private(set) var state: XMPPClient.State = .disconnected();
    public var statePublisher: Published<XMPPClient.State>.Publisher {
        return $state;
    }

    private let queue = DispatchQueue(label: "SocketSessionLogic");
    private var seeOtherHost: ConnectorEndpoint? = nil;
    
    private let connectionConfiguration: ConnectionConfiguration;
    private var userJid: BareJID {
        return connectionConfiguration.userJid;
    }
    private var streamManagementModule: StreamManagementModule?;
    
    private var socketSubscriptions: Set<AnyCancellable> = [];
    private var moduleSubscriptions: Set<AnyCancellable> = [];
        
    public init(connector: Connector, responseManager: ResponseManager, context: Context, seeOtherHost: ConnectorEndpoint?) {
        self.modulesManager = context.modulesManager;
        self.connector = connector;
        self.connectionConfiguration = context.connectionConfiguration;
        self.context = context;
        self.responseManager = responseManager;
        self.seeOtherHost = seeOtherHost;
        self.streamManagementModule = context.moduleOrNil(.streamManagement);
        
        connector.statePublisher.removeDuplicates().dropFirst(1).receive(on: self.queue).sink(receiveValue: { [weak self] newState in
            guard newState != .connected else {
                return;
            }
            guard let that = self else {
                return;
            }
            switch newState {
            case .connecting:
                that.state = .connecting;
            case .connected:
                break;
            case .disconnecting:
                that.state = .disconnecting;
            case .disconnected(let reason):
                if case .streamError(let errorElem) = reason {
                    guard that.onStreamError(errorElem) else {
                        return;
                    }
                }
                if let authModule = that.modulesManager.moduleOrNil(.auth) {
                    if case .error(let error) = authModule.state {
                        that.state = .disconnected(.authenticationFailure(error));
                        return;
                    }
                }
                that.state = .disconnected(reason.clientDisconnectionReason);
            }
        }).store(in: &socketSubscriptions);
        connector.streamEventsPublisher.receive(on: queue).sink(receiveValue: { [weak self] event in
            guard let that = self else {
                return;
            }
            switch event {
            case .streamOpen(_):
                break;
            case .streamStart:
                that.startStream();
            case .streamClose:
                that.onStreamClose(completionHandler: nil);
            case .stanza(let stanza):
                that.receivedIncomingStanza(stanza);
            case .streamTerminate:
                that.onStreamTerminate();
            }
        }).store(in: &socketSubscriptions);
    }
        
    open func bind() {
        context?.module(.streamFeatures).$streamFeatures.receive(on: self.queue).sink(receiveValue: { [weak self] streamFeatures in self?.processStreamFeatures(streamFeatures) }).store(in: &moduleSubscriptions);

        //responseManager.start();
    }
    
    open func unbind() async {
        for subscription in socketSubscriptions {
            subscription.cancel();
        }
        for subscription in moduleSubscriptions {
            subscription.cancel();
        }
        moduleSubscriptions.removeAll();
        await responseManager.stop();
    }
    
    open func start() {
        connector.start(endpoint: self.serverToConnectDetails());
    }
    
    @discardableResult
    open func stop(force: Bool = false) -> Future<Void,Never> {
        return connector.stop(force: force);
    }
    
    // async-await support
    open func stop(force: Bool) async {
        await connector.stop(force: force);
    }
    
    open func serverToConnectDetails() -> ConnectorEndpoint? {
        if let redirect = self.seeOtherHost {
            defer {
                self.seeOtherHost = nil;
            }
            return redirect;
        }
        return modulesManager.moduleOrNil(.streamManagement)?.resumptionLocation;
    }
    
    private func onStreamClose(completionHandler: (() -> Void)?) {
        if let streamManagementModule = modulesManager.moduleOrNil(.streamManagement) {
            streamManagementModule.request();
            streamManagementModule.sendAck();
        }
        if let completionHandler = completionHandler {
            queue.async {
                completionHandler();
            }
        }
    }
        
    private func onStreamError(_ streamErrorEl: Element) -> Bool {
        if let seeOtherHostEl = streamErrorEl.firstChild(name: "see-other-host", xmlns: "urn:ietf:params:xml:ns:xmpp-streams"), let seeOtherHost = SocketConnector.preprocessConnectionDetails(string: seeOtherHostEl.value) {
//            if let streamFeaturesWithPipelining = modulesManager.moduleOrNil(.streamFeatures) as? StreamFeaturesModuleWithPipelining {
//                streamFeaturesWithPipelining.connectionRestarted();
//            }
            
            self.logger.log("reconnecting via see-other-host to host \(seeOtherHost.0)");
            self.seeOtherHost = connector.prepareEndpoint(withSeeOtherHost: seeOtherHostEl.value);
            self.connector.start(endpoint: self.serverToConnectDetails());
            return false;
        }
        return true;
    }
    
    private func onStreamTerminate() {
        // we may need to adjust those condition....
        if self.connector.state == .connecting {
            modulesManager.moduleOrNil(.streamManagement)?.reset(scopes: [.stream,.session]);
        }
    }
    
    // we can process only 1 stanza at once..
    private let semaphore = DispatchSemaphore(value: 1);
    private var authTask: Task<Void,Never>?;
    
    private func receivedIncomingStanza(_ stanza:Stanza) {
        semaphore.wait();
        Task {
            defer {
                print("releasing semaphore")
                semaphore.signal();
            }
            do {
                print("received stanza: \(stanza)")
                if streamManagementModule?.processIncoming(stanza: stanza) ?? false {
                    return;
                }
            
                if let continuation = await self.responseManager.continuation(for: stanza) {
                    // FIXME: this is not blocking and causes continuation to be processed after another stanza may be processed!!
                    continuation(stanza);
                    print("continuation processing finished for: \(stanza)")
                    return;
                }
                            
                guard stanza.name != "iq" || (stanza.type != StanzaType.result && stanza.type != StanzaType.error) else {
                    return;
                }
                
                _ = await authTask?.result
            
                let processors = self.modulesManager.findProcessors(for: stanza);
                guard !processors.isEmpty else {
                    self.logger.debug("\(self.userJid) - feature-not-implemented \(stanza, privacy: .public)");
                    throw XMPPError(condition: .feature_not_implemented);
                }
                
                for processor in processors {
                    try await processor.process(stanza: stanza);
                }
                print("stanza processing finished: \(stanza)")
            } catch {
                Task {
                    do {
                        let errorStanza = try stanza.errorResult(of: error as? XMPPError ?? .undefined_condition);
                        try await self.send(stanza: errorStanza);
                    } catch {
                        self.logger.debug("\(self.userJid) - error: \(error), while processing \(stanza)")
                    }
                }
            }
        }
    }
    
    open func send(stanza: Stanza) async throws {
        let state = self.state;
        guard state == .connected() || state == .connecting else {
           throw XMPPError(condition: .not_authorized, message: "You are not connected to the XMPP server");
        }
        
        let (requestAck, task) = streamManagementModule?.processOutgoing(stanza: stanza) ?? (false, nil);
        if let task {
            connector.send(.stanza(stanza), completion: .none);
            if requestAck {
                streamManagementModule?.request();
            }
            try await task.value;
        } else {
            try await connector.send(.stanza(stanza));
            if requestAck {
                streamManagementModule?.request();
            }
        }
    }
    
    open func keepalive() async throws {
        if let pingModule = modulesManager.moduleOrNil(.ping) {
            do {
                try await pingModule.ping(userJid.jid());
            } catch {
                if (error as? XMPPError)?.condition == .remote_server_timeout {
                    self.logger.debug("\(self.userJid) - no response on ping packet - possible that connection is broken, reconnecting...");
                }
                throw error;
            }
        }
    }
                
    private func processSessionBindedAndEstablished(streamFeatures: StreamFeatures) {
        let resumed = modulesManager.moduleOrNil(.streamManagement)?.wasResumed ?? false;
        state = .connected(resumed: resumed);
        self.logger.debug("\(self.userJid) - session binded and established");
        Task {
            try await modulesManager.moduleOrNil(.streamManagement)?.process(streamFeatures: streamFeatures);
        }
        if let discoveryModule = modulesManager.moduleOrNil(.disco) {
            Task {
                try await discoveryModule.serverFeatures()
            }
            Task {
                try await discoveryModule.accountFeatures();
            }
        }
    }
    
    private func processStreamFeatures(_ streamFeatures: StreamFeatures) {
        guard !streamFeatures.isNone else {
            return;
        }
        
        self.logger.debug("\(self.userJid) - processing stream features:\n \(streamFeatures)");
        // it looks like, this is called before auth task finishes, while it should be executed after task finishes
        let authorized = (modulesManager.moduleOrNil(.auth)?.state ?? .notAuthorized) == .authorized(streamRestartRequired: false);
        
        if (!connector.activeFeatures.contains(.TLS)) && connector.availableFeatures.contains(.TLS)
            && (!connectionConfiguration.disableTLS) && streamFeatures.contains(.startTLS) {
            connector.activate(feature: .TLS);
        } else if ((!connector.activeFeatures.contains(.ZLIB)) && connector.availableFeatures.contains(.ZLIB) && (!connectionConfiguration.disableCompression) && streamFeatures.contains(.compressionZLIB)) {
            connector.activate(feature: .ZLIB);
        } else if !authorized {
            if let authModule: AuthModule = modulesManager.moduleOrNil(.auth) {
                self.logger.debug("\(self.userJid) - starting authentication");
                authTask = Task {
                    do {
                        try await authModule.login();
                        if case let .authorized(streamRestartRequired) = authModule.state, streamRestartRequired {
                            self.startStream();
                        }
                    } catch {
                        await self.stop(force: true);
                    }
                }
            } else if modulesManager.moduleOrNil(.inBandRegistration) != nil {
                self.logger.debug("\(self.userJid) - marking client as connected and ready for registration")
                self.state = .connected(resumed: false);
            }
        } else if authorized {
            Task {
                do {
                    try await self.streamAuthenticated(streamFeatures: streamFeatures);
                } catch {
                    self.stop();
                }
            }
        }
        self.logger.debug("\(self.userJid) - finished processing stream features");
    }
    
    private func streamAuthenticated(streamFeatures: StreamFeatures) async throws {
        try await modulesManager.moduleOrNil(.streamManagement)?.process(streamFeatures: streamFeatures);
        if context?.boundJid == nil {
            // normal connection or stream resumption failed
            if let bindModule = self.modulesManager.moduleOrNil(.resourceBind) {
                _ = try await bindModule.bind();
                try await modulesManager.module(.sessionEstablishment).establish();
            } else {
                throw XMPPError(condition: .undefined_condition, message: "BindModule is not registered!")
            }
        }
        self.processSessionBindedAndEstablished(streamFeatures: streamFeatures);
    }
    
    private func startStream() {
        // replace with this first one to enable see-other-host feature
        //self.send("<stream:stream from='\(userJid)' to='\(userJid.domain)' version='1.0' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>")
        let domain = userJid.domain
        var attributes: [String: String] = ["to": domain];
        if self.connectionConfiguration.useSeeOtherHost && userJid.localPart != nil && (self.connectionConfiguration.disableTLS || self.connector.activeFeatures.contains(.TLS)) {
            attributes["from"] = userJid.description;
        }
        self.connector.send(.streamOpen(attributes: attributes));
        
//        if let streamFeaturesWithPipelining = self.modulesManager.moduleOrNil(.streamFeatures) as? StreamFeaturesModuleWithPipelining {
//            streamFeaturesWithPipelining.streamStarted();
//        }
    }
    
}

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
    func stop(force: Bool) -> Future<Void,Never>;
    
    /// Register to listen for events
    func bind();
    /// Unregister to stop listening for events
    func unbind();
        
    func send(stanza: Stanza, completionHandler: ((Result<Void,XMPPError>)->Void)?);
    
    /// Called to send data to keep connection open
    func keepalive();

    // async-await support
    func stop(force: Bool) async;
}

extension XmppSessionLogic {
    
    public func send(stanza: Stanza) {
        send(stanza: stanza, completionHandler: nil);
    }
    
    public func send(stanza: Stanza) async throws {
        try await withUnsafeThrowingContinuation({ continuation in
            send(stanza: stanza, completionHandler: continuation.resume(with:));
        })
    }
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
    
    
    private var socketSubscriptions: Set<AnyCancellable> = [];
    private var moduleSubscriptions: Set<AnyCancellable> = [];
        
    public init(connector: Connector, responseManager: ResponseManager, context: Context, seeOtherHost: ConnectorEndpoint?) {
        self.modulesManager = context.modulesManager;
        self.connector = connector;
        self.connectionConfiguration = context.connectionConfiguration;
        self.context = context;
        self.responseManager = responseManager;
        self.seeOtherHost = seeOtherHost;
        
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
        context?.moduleOrNil(.auth)?.$state.receive(on: queue).sink(receiveValue: { [weak self] state in self?.authStateChanged(state) }).store(in: &moduleSubscriptions);
        context?.module(.streamFeatures).$streamFeatures.receive(on: self.queue).sink(receiveValue: { [weak self] streamFeatures in self?.processStreamFeatures(streamFeatures) }).store(in: &moduleSubscriptions);

        responseManager.start();
    }
    
    private func authStateChanged(_ state: AuthModule.AuthorizationStatus) {
        switch state {
        case .authorized:
            let streamFeaturesWithPipelining = modulesManager.moduleOrNil(.streamFeatures) as? StreamFeaturesModuleWithPipelining;

            if !(streamFeaturesWithPipelining?.active ?? false) {
                connector.restartStream();
            }
        case .expectedAuthorization:
            guard let streamFeaturesWithPipelining = modulesManager.moduleOrNil(.streamFeatures) as? StreamFeaturesModuleWithPipelining else {
                return;
            }
            
            // current version of Tigase is not capable of pipelining auth with <stream> as get features is called before authentication is done!!
            if streamFeaturesWithPipelining.active {
                self.startStream();
            }
        case .error(_):
            _ = self.stop(force: true);
        default:
            logger.debug("Received auth state: \(state)")
        }
    }
    
    open func unbind() {
        for subscription in socketSubscriptions {
            subscription.cancel();
        }
        for subscription in moduleSubscriptions {
            subscription.cancel();
        }
        moduleSubscriptions.removeAll();
        responseManager.stop();
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
            if let streamFeaturesWithPipelining = modulesManager.moduleOrNil(.streamFeatures) as? StreamFeaturesModuleWithPipelining {
                streamFeaturesWithPipelining.connectionRestarted();
            }
            
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
            modulesManager.moduleOrNil(.streamManagement)?.reset();
        }
    }
    
    private func receivedIncomingStanza(_ stanza:Stanza) {
//        dispatcher.async {
            do {
                for filter in self.modulesManager.filters {
                    if filter.processIncoming(stanza: stanza) {
                        return;
                    }
                }
            
                if let iq = stanza as? Iq, let handler = self.responseManager.getResponseHandler(for: iq) {
                    handler(iq);
                    return;
                }
            
                guard stanza.name != "iq" || (stanza.type != StanzaType.result && stanza.type != StanzaType.error) else {
                    return;
                }
            
                let modules = self.modulesManager.findModules(for: stanza);
//                self.log("stanza:", stanza, "will be processed by", modules);
                if !modules.isEmpty {
                    for module in modules {
                        try module.process(stanza: stanza);
                    }
                } else {
                    self.logger.debug("\(self.userJid) - feature-not-implemented \(stanza, privacy: .public)");
                    throw XMPPError(condition: .feature_not_implemented);
                }
            } catch {
                do {
                    let errorStanza = try stanza.errorResult(of: error as? XMPPError ?? .undefined_condition);
                    self.sendingOutgoingStanza(errorStanza);
                } catch {
                    self.logger.debug("\(self.userJid) - error: \(error), while processing \(stanza)")
                }
            }
//        }
    }
    
    open func send(stanza: Stanza, completionHandler: ((Result<Void,XMPPError>)->Void)?) {
        queue.async {
            let state = self.state;
            guard state == .connected() || state == .connecting else {
                completionHandler?(.failure(XMPPError(condition: .not_authorized, message: "You are not connected to the XMPP server")));
                return;
            }
            
            for filter in self.modulesManager.filters {
                filter.processOutgoing(stanza: stanza);
            }
            if let completionHandler = completionHandler {
                self.connector.send(.stanza(stanza), completion: .written({ result in
                    completionHandler(result.mapError({ _ in XMPPError(condition: .remote_server_timeout) }));
                }));
            } else {
                self.connector.send(.stanza(stanza), completion: .none);
            }
        }
    }

    
    private func sendingOutgoingStanza(_ stanza: Stanza) {
        queue.async {
            for filter in self.modulesManager.filters {
                filter.processOutgoing(stanza: stanza);
            }
            self.connector.send(.stanza(stanza));
        }
    }
    
    open func keepalive() {
        if let pingModule = modulesManager.moduleOrNil(.ping) {
            Task {
                do {
                    try await pingModule.ping(userJid.jid());
                } catch {
                    if (error as? XMPPError)?.condition == .remote_server_timeout {
                        self.logger.debug("\(self.userJid) - no response on ping packet - possible that connection is broken, reconnecting...");
                    }
                }
            }
        }
    }
                
    private func processSessionBindedAndEstablished(resumed: Bool) {
        state = .connected(resumed: resumed);
        self.logger.debug("\(self.userJid) - session binded and established");
        if let discoveryModule = modulesManager.moduleOrNil(.disco) {
            Task {
                try await discoveryModule.serverFeatures()
            }
            Task {
                try await discoveryModule.accountFeatures();
            }
        }
        
        if !resumed, let streamManagementModule = modulesManager.moduleOrNil(.streamManagement) {
            if streamManagementModule.isAvailable {
                Task {
                    try await streamManagementModule.enable();
                }
            }
        }
    }
    
    private func processStreamFeatures(_ streamFeatures: StreamFeatures) {
        guard !streamFeatures.isNone else {
            return;
        }
        
        self.logger.debug("\(self.userJid) - processing stream features");
        let authorized = (modulesManager.moduleOrNil(.auth)?.state ?? .notAuthorized) == .authorized;
        
        if (!connector.activeFeatures.contains(.TLS)) && connector.availableFeatures.contains(.TLS)
            && (!connectionConfiguration.disableTLS) && streamFeatures.contains(.startTLS) {
            connector.activate(feature: .TLS);
        } else if ((!connector.activeFeatures.contains(.ZLIB)) && connector.availableFeatures.contains(.ZLIB) && (!connectionConfiguration.disableCompression) && streamFeatures.contains(.compressionZLIB)) {
            connector.activate(feature: .ZLIB);
        } else if !authorized {
            if let authModule:AuthModule = modulesManager.moduleOrNil(.auth) {
                self.logger.debug("\(self.userJid) - starting authentication");
                if authModule.state != .inProgress {
                    authModule.login();
                } else {
                    self.logger.debug("\(self.userJid) - skipping authentication as it is already in progress!");
                    Task {
                        do {
                            try await self.streamAuthenticated();
                        } catch {
                            self.stop();
                        }
                    }
                }
            } else if modulesManager.moduleOrNil(.inBandRegistration) != nil {
                self.logger.debug("\(self.userJid) - marking client as connected and ready for registration")
                self.state = .connected(resumed: false);
            }
        } else if authorized {
            Task {
                do {
                    try await self.streamAuthenticated();
                } catch {
                    self.stop();
                }
            }
        }
        self.logger.debug("\(self.userJid) - finished processing stream features");
    }
    
    private func streamAuthenticated() async throws {
        do {
            // handling stream resumption
            if let streamManagementModule = modulesManager.moduleOrNil(.streamManagement),  streamManagementModule.resumptionEnabled && streamManagementModule.isAvailable {
                try await streamManagementModule.resume();
                processSessionBindedAndEstablished(resumed: true);
                return;
            }
        } catch {
            context?.reset(scopes: [.session]);
        }
        
        // normal connection or stream resumption failed
        if let bindModule = self.modulesManager.moduleOrNil(.resourceBind) {
            _ = try await bindModule.bind();
            try await modulesManager.module(.sessionEstablishment).establish();
            self.processSessionBindedAndEstablished(resumed: false);
        } else {
            throw XMPPError(condition: .undefined_condition, message: "BindModule is not registered!")
        }
    }
    
    private func startStream() {
        // replace with this first one to enable see-other-host feature
        //self.send("<stream:stream from='\(userJid)' to='\(userJid.domain)' version='1.0' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>")
        let domain = userJid.domain
        var attributes: [String: String] = ["to": domain];
        if self.connectionConfiguration.useSeeOtherHost && userJid.localPart != nil {
            attributes["from"] = userJid.description;
        }
        self.connector.send(.streamOpen(attributes: attributes));
        
        if let streamFeaturesWithPipelining = self.modulesManager.moduleOrNil(.streamFeatures) as? StreamFeaturesModuleWithPipelining {
            streamFeaturesWithPipelining.streamStarted();
        }
    }
    
}

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

/// Protocol which is used by other class to interact with classes responsible for session logic.
public protocol XmppSessionLogic: class {
    
//    public enum State {
//        case connecting
//        case connected
//        case disconnecting
//        // this should be only "after" we process the last received stanza!!
//        case disconneted
//    }
//    -- should we use different state? This would help use with details about authentication, etc...
    
    /// Keeps state of XMPP stream - this is not the same as state of `SocketConnection`
    var state:SocketConnector.State { get }
    var statePublisher: Published<SocketConnector.State>.Publisher { get }
    
    var connector: Connector { get }
    
    var streamLogger: StreamLogger? { get set }
    
    func start();
    func stop(force: Bool, completionHandler: (()->Void)?);
    
    /// Register to listen for events
    func bind();
    /// Unregister to stop listening for events
    func unbind();
        
    func send(stanza: Stanza, completionHandler: ((Result<Void,XMPPError>)->Void)?);
    
    /// Called to send data to keep connection open
    func keepalive();
    /// Using properties set decides which name use to connect to XMPP server
    func serverToConnectDetails() -> XMPPSrvRecord?;
}

extension XmppSessionLogic {
    
    public func send(stanza: Stanza) {
        send(stanza: stanza, completionHandler: nil);
    }
    
}

/** 
 Implementation of XmppSessionLogic protocol which is resposible for
 following XMPP session logic for socket connections.
 */
open class SocketSessionLogic: XmppSessionLogic, EventHandler {
    
    let logger = Logger(subsystem: "TigaseSwift", category: "SocketSessionLogic")
        
    private weak var context: Context?;
    private let modulesManager: XmppModulesManager;
    
    public var connector: Connector {
        return socketConnector;
    }
    private let socketConnector: SocketConnector;
    private let eventBus: EventBus;
    private let responseManager:ResponseManager;

    public var streamLogger: StreamLogger? {
        get {
            return socketConnector.streamLogger;
        }
        set {
            socketConnector.streamLogger = newValue;
        }
    }
    
    /// Keeps state of XMPP stream - this is not the same as state of `SocketConnection`
    @Published
    open private(set) var state:SocketConnector.State = .disconnected;
    public var statePublisher: Published<SocketConnector.State>.Publisher {
        return $state;
    }

    private let dispatcher: QueueDispatcher = QueueDispatcher(label: "SocketSessionLogic");
    private var seeOtherHost: XMPPSrvRecord? = nil;
    
    private let connectionConfiguration: ConnectionConfiguration;
    private var userJid: BareJID {
        return connectionConfiguration.userJid;
    }
    
    
    private var socketSubscriptions: [Cancellable] = [];
    
    public init(connector: SocketConnector, responseManager: ResponseManager, context: Context, seeOtherHost: XMPPSrvRecord?) {
        self.modulesManager = context.modulesManager;
        self.socketConnector = connector;
        self.eventBus = context.eventBus;
        self.connectionConfiguration = context.connectionConfiguration;
        self.context = context;
        self.responseManager = responseManager;
        self.seeOtherHost = seeOtherHost;
        
        socketSubscriptions.append(connector.$state.sink(receiveValue: { [weak self] newState in
            guard newState != .connected else {
                return;
            }
            guard let that = self else {
                return;
            }
            that.dispatcher.async {
                that.state = newState;
            }
        }));
        socketSubscriptions.append(connector.streamEvents.sink(receiveValue: { [weak self] event in
            guard let that = self else {
                return;
            }
            that.dispatcher.async {
                switch event {
                case .streamOpen:
                    that.startStream();
                case .streamClose:
                    that.onStreamClose(completionHandler: nil);
                case .streamReceived(let stanza):
                    that.receivedIncomingStanza(stanza);
                case .streamTerminate:
                    that.onStreamTerminate();
                case .streamError(let errorEl):
                    that.onStreamError(errorEl)
                }
            }
        }))
    }
    
    deinit {
        for subscription in socketSubscriptions {
            subscription.cancel();
        }
        self.dispatcher.sync {
            if state != .disconnected {
                state = .disconnected;
            }
        }
    }
    
    open func bind() {
        eventBus.register(handler: self, for: StreamFeaturesReceivedEvent.TYPE);
        eventBus.register(handler: self, for: AuthModule.AuthSuccessEvent.TYPE, AuthModule.AuthFailedEvent.TYPE, AuthModule.AuthFinishExpectedEvent.TYPE);
        eventBus.register(handler: self, for: ResourceBinderModule.ResourceBindSuccessEvent.TYPE, ResourceBinderModule.ResourceBindErrorEvent.TYPE);
        eventBus.register(handler: self, for: StreamManagementModule.FailedEvent.TYPE, StreamManagementModule.ResumedEvent.TYPE);
        responseManager.start();
    }
    
    open func unbind() {
        eventBus.unregister(handler: self, for: StreamFeaturesReceivedEvent.TYPE);
        eventBus.unregister(handler: self, for: AuthModule.AuthSuccessEvent.TYPE, AuthModule.AuthFailedEvent.TYPE, AuthModule.AuthFinishExpectedEvent.TYPE);
        eventBus.unregister(handler: self, for: ResourceBinderModule.ResourceBindSuccessEvent.TYPE, ResourceBinderModule.ResourceBindErrorEvent.TYPE);
        eventBus.unregister(handler: self, for: StreamManagementModule.FailedEvent.TYPE, StreamManagementModule.ResumedEvent.TYPE);
        responseManager.stop();
    }
    
    open func start() {
        socketConnector.start();
    }
    
    open func stop(force: Bool = false, completionHandler: (()->Void)? = nil) {
        if force {
            socketConnector.forceStop(completionHandler: completionHandler);
        } else {
            socketConnector.stop(completionHandler: completionHandler)
        }
    }
    
    open func serverToConnectDetails() -> XMPPSrvRecord? {
        if let redirect: XMPPSrvRecord = self.seeOtherHost {
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
            dispatcher.async {
                completionHandler();
            }
        }
    }
        
    private func onStreamError(_ streamErrorEl: Element) {
        if let seeOtherHostEl = streamErrorEl.findChild(name: "see-other-host", xmlns: "urn:ietf:params:xml:ns:xmpp-streams"), let seeOtherHost = SocketConnector.preprocessConnectionDetails(string: seeOtherHostEl.value), let lastConnectionDetails: XMPPSrvRecord = self.socketConnector.currentConnectionDetails {
            if let streamFeaturesWithPipelining = modulesManager.moduleOrNil(.streamFeatures) as? StreamFeaturesModuleWithPipelining {
                streamFeaturesWithPipelining.connectionRestarted();
            }
            
            self.seeOtherHost = XMPPSrvRecord(port: seeOtherHost.1 ?? lastConnectionDetails.port, weight: 1, priority: 1, target: seeOtherHost.0, directTls: lastConnectionDetails.directTls);
            socketConnector.reconnect();
            return;
        }
        let errorName = streamErrorEl.findChild(xmlns: "urn:ietf:params:xml:ns:xmpp-streams")?.name;
        let streamError = errorName == nil ? nil : StreamError(rawValue: errorName!);
        if let context = self.context {
            eventBus.fire(ErrorEvent.init(context: context, streamError: streamError));
        }
    }
    
    private func onStreamTerminate() {
        // we may need to adjust those condition....
        if self.socketConnector.state == .connecting {
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
                    throw ErrorCondition.feature_not_implemented;
                }
            } catch let error as XMPPError {
                let errorStanza = error.createResponse(stanza);
                self.sendingOutgoingStanza(errorStanza);
            } catch let error as ErrorCondition {
                let errorStanza = error.createResponse(stanza);
                self.sendingOutgoingStanza(errorStanza);
            } catch {
                let errorStanza = ErrorCondition.undefined_condition.createResponse(stanza);
                self.sendingOutgoingStanza(errorStanza);
                self.logger.debug("\(self.userJid) - unknown unhandled exception \(error)")
            }
//        }
    }
    
    open func send(stanza: Stanza, completionHandler: ((Result<Void,XMPPError>)->Void)?) {
        dispatcher.async {
            let state = self.state;
            guard state == .connected || state == .connecting else {
                completionHandler?(.failure(.not_authorized("You are not connected to the XMPP server")));
                return;
            }
            
            for filter in self.modulesManager.filters {
                filter.processOutgoing(stanza: stanza);
            }
            self.socketConnector.send(.stanza(stanza));
            completionHandler?(.success(Void()));
        }
    }

    
    private func sendingOutgoingStanza(_ stanza: Stanza) {
        dispatcher.async {
            for filter in self.modulesManager.filters {
                filter.processOutgoing(stanza: stanza);
            }
            self.socketConnector.send(.stanza(stanza));
        }
    }
    
    open func keepalive() {
        if let pingModule = modulesManager.moduleOrNil(.ping) {
            pingModule.ping(JID(userJid), callback: { (stanza) in
                if stanza == nil {
                    self.logger.debug("\(self.userJid) - no response on ping packet - possible that connection is broken, reconnecting...");
                }
            });
        } else {
            socketConnector.keepAlive();
        }
    }
    
    open func handle(event: Event) {
        switch event {
        case is StreamFeaturesReceivedEvent:
            processStreamFeatures((event as! StreamFeaturesReceivedEvent).featuresElement);
        case is AuthModule.AuthFailedEvent:
            processAuthFailed(event as! AuthModule.AuthFailedEvent);
        case is AuthModule.AuthSuccessEvent:
            processAuthSuccess(event as! AuthModule.AuthSuccessEvent);
        case is ResourceBinderModule.ResourceBindSuccessEvent:
            processResourceBindSuccess(event as! ResourceBinderModule.ResourceBindSuccessEvent);
        case let re as StreamManagementModule.ResumedEvent:
            processSessionBindedAndEstablished();
        case is StreamManagementModule.FailedEvent:
            if let bindModule = modulesManager.moduleOrNil(.resourceBind) {
                bindModule.bind();
            }
        case is AuthModule.AuthFinishExpectedEvent:
            processAuthFinishExpected();
        default:
            self.logger.debug("\(self.userJid) - received unhandled event: \(event)");
        }
    }
    
    private func processAuthFailed(_ event:AuthModule.AuthFailedEvent) {
        self.logger.debug("\(self.userJid) - Authentication failed");
    }
    
    private func processAuthSuccess(_ event:AuthModule.AuthSuccessEvent) {
        let streamFeaturesWithPipelining = modulesManager.moduleOrNil(.streamFeatures) as? StreamFeaturesModuleWithPipelining;

        if !(streamFeaturesWithPipelining?.active ?? false) {
            socketConnector.restartStream();
        }
    }
    
    private func processAuthFinishExpected() {
        guard let streamFeaturesWithPipelining = modulesManager.moduleOrNil(.streamFeatures) as? StreamFeaturesModuleWithPipelining else {
            return;
        }
        
        // current version of Tigase is not capable of pipelining auth with <stream> as get features is called before authentication is done!!
        if streamFeaturesWithPipelining.active {
            self.startStream();
        }
    }
    
    private func processResourceBindSuccess(_ event:ResourceBinderModule.ResourceBindSuccessEvent) {
        modulesManager.module(.sessionEstablishment).establish(completionHandler: { result in
            switch result {
            case .success(_):
                self.processSessionBindedAndEstablished();
            case .failure(_):
                //TODO: Should we handle failure somehow?
                break;
            }
        });
    }
    
    private func processSessionBindedAndEstablished() {
        state = .connected;
        self.logger.debug("\(self.userJid) - session binded and established");
        if let discoveryModule = modulesManager.moduleOrNil(.disco) {
            discoveryModule.discoverServerFeatures(completionHandler: nil);
            discoveryModule.discoverAccountFeatures(completionHandler: nil);
        }
        
        if let streamManagementModule = modulesManager.moduleOrNil(.streamManagement) {
            if streamManagementModule.isAvailable() {
                streamManagementModule.enable();
            }
        }
    }
    
    private func processStreamFeatures(_ featuresElement: Element) {
        self.logger.debug("\(self.userJid) - processing stream features");
        let authorized = (modulesManager.moduleOrNil(.auth)?.state ?? .notAuthorized) == .authorized;
        let streamManagementModule = modulesManager.moduleOrNil(.streamManagement);
        let resumption = (streamManagementModule?.resumptionEnabled ?? false) && (streamManagementModule?.isAvailable() ?? false);
        
        if (!socketConnector.isTLSActive)
            && (!connectionConfiguration.disableTLS) && self.isStartTLSAvailable() {
            socketConnector.startTLS();
        } else if ((!socketConnector.isCompressionActive) && (!connectionConfiguration.disableCompression) && self.isZlibAvailable()) {
            socketConnector.startZlib();
        } else if !authorized {
            if let authModule:AuthModule = modulesManager.moduleOrNil(.auth) {
                self.logger.debug("\(self.userJid) - starting authentication");
                if authModule.state != .inProgress {
                    authModule.login();
                } else {
                    self.logger.debug("\(self.userJid) - skipping authentication as it is already in progress!");
                    if resumption {
                        streamManagementModule!.resume();
                    } else {
                        if let bindModule:ResourceBinderModule = modulesManager.moduleOrNil(.resourceBind) {
                            bindModule.bind();
                        }
                    }
                }
            }
        } else if authorized {
            if resumption {
                streamManagementModule!.resume();
            } else {
                if let bindModule:ResourceBinderModule = modulesManager.moduleOrNil(.resourceBind) {
                    bindModule.bind();
                }
            }
        }
        self.logger.debug("\(self.userJid) - finished processing stream features");
    }
    
    private func isStartTLSAvailable() -> Bool {
        self.logger.debug("\(self.userJid) - checking TLS");
        return (modulesManager.module(.streamFeatures).streamFeatures?.findChild(name: "starttls", xmlns: "urn:ietf:params:xml:ns:xmpp-tls")) != nil;
    }
    
    private func isZlibAvailable() -> Bool {
        return modulesManager.module(.streamFeatures).streamFeatures?.getChildren(name: "compression", xmlns: "http://jabber.org/features/compress").firstIndex(where: {(e) in e.findChild(name: "method")?.value == "zlib" }) != nil;
    }
    
    private func startStream() {
        // replace with this first one to enable see-other-host feature
        //self.send("<stream:stream from='\(userJid)' to='\(userJid.domain)' version='1.0' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>")
        let domain = userJid.domain
        let seeOtherHost = (self.connectionConfiguration.useSeeOtherHost && userJid.localPart != nil) ? " from='\(userJid)'" : ""
        self.socketConnector.send(.string("<stream:stream to='\(domain)'\(seeOtherHost) version='1.0' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>"));
        
        if let streamFeaturesWithPipelining = self.modulesManager.moduleOrNil(.streamFeatures) as? StreamFeaturesModuleWithPipelining {
            streamFeaturesWithPipelining.streamStarted();
        }
    }
    
    /// Event fired when XMPP stream error happens
    open class ErrorEvent: AbstractEvent {
        
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ErrorEvent();
        
        /// Type of stream error which was received - may be nil if it is not known
        public let streamError:StreamError?;
        
        init() {
            streamError = nil;
            super.init(type: "errorEvent");
        }
        
        public init(context: Context, streamError: StreamError?) {
            self.streamError = streamError;
            super.init(type: "errorEvent", context: context)
        }
    }
}

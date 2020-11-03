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
    
    /// Keeps state of XMPP stream - this is not the same as state of `SocketConnection`
    var state:SocketConnector.State { get }
    
    /// Register to listen for events
    func bind();
    /// Unregister to stop listening for events
    func unbind();
    
    /// Called when stream should be started
    func startStream();
    
    /// Called when stanza is received
    func receivedIncomingStanza(_ stanza:Stanza);
    /// Called when stanza is about to be send
    func sendingOutgoingStanza(_ stanza:Stanza);
    /// Called to send data to keep connection open
    func keepalive();
    /// Called when stream is closing
    func onStreamClose(completionHandler: @escaping ()->Void);
    /// Called when stream error happens
    func onStreamError(_ streamError:Element);
    /// Called when stream is terminated abnormally
    func onStreamTerminate();
    /// Using properties set decides which name use to connect to XMPP server
    func serverToConnect() -> String;
    func serverToConnectDetails() -> XMPPSrvRecord?;
}

/** 
 Implementation of XmppSessionLogic protocol which is resposible for
 following XMPP session logic for socket connections.
 */
open class SocketSessionLogic: XmppSessionLogic, EventHandler {
    
    let logger = Logger(subsystem: "TigaseSwift", category: "SocketSessionLogic")
    
    public var debugDescription: String {
        return context.sessionObject.userBareJid?.stringValue ?? context.sessionObject.getProperty(SessionObject.DOMAIN_NAME) ?? "nil";
    }
    
    var quickstart: Bool = true;
    
    fileprivate let context:Context;
    fileprivate let modulesManager:XmppModulesManager;
    fileprivate let connector:SocketConnector;
    fileprivate let responseManager:ResponseManager;

    /// Keeps state of XMPP stream - this is not the same as state of `SocketConnection`
    open var state:SocketConnector.State {
        let s = connector.state;
        if s == .connected && ResourceBinderModule.getBindedJid(context.sessionObject) == nil {
            return .connecting;
        }
        return s;
    }
    
    private let dispatcher: QueueDispatcher;
    
    public init(connector:SocketConnector, modulesManager:XmppModulesManager, responseManager:ResponseManager, context:Context, queueDispatcher: QueueDispatcher) {
        self.dispatcher = queueDispatcher;
        self.connector = connector;
        self.context = context;
        self.modulesManager = modulesManager;
        self.responseManager = responseManager;
    }
    
    open func bind() {
        connector.sessionLogic = self;
        context.eventBus.register(handler: self, for: StreamFeaturesReceivedEvent.TYPE);
        context.eventBus.register(handler: self, for: AuthModule.AuthSuccessEvent.TYPE, AuthModule.AuthFailedEvent.TYPE, AuthModule.AuthFinishExpectedEvent.TYPE);
        context.eventBus.register(handler: self, for: SessionEstablishmentModule.SessionEstablishmentSuccessEvent.TYPE, SessionEstablishmentModule.SessionEstablishmentErrorEvent.TYPE);
        context.eventBus.register(handler: self, for: ResourceBinderModule.ResourceBindSuccessEvent.TYPE, ResourceBinderModule.ResourceBindErrorEvent.TYPE);
        context.eventBus.register(handler: self, for: StreamManagementModule.FailedEvent.TYPE, StreamManagementModule.ResumedEvent.TYPE);
        responseManager.start();
    }
    
    open func unbind() {
        context.eventBus.unregister(handler: self, for: StreamFeaturesReceivedEvent.TYPE);
        context.eventBus.unregister(handler: self, for: AuthModule.AuthSuccessEvent.TYPE, AuthModule.AuthFailedEvent.TYPE, AuthModule.AuthFinishExpectedEvent.TYPE);
        context.eventBus.unregister(handler: self, for: SessionEstablishmentModule.SessionEstablishmentSuccessEvent.TYPE, SessionEstablishmentModule.SessionEstablishmentErrorEvent.TYPE);
        context.eventBus.unregister(handler: self, for: ResourceBinderModule.ResourceBindSuccessEvent.TYPE, ResourceBinderModule.ResourceBindErrorEvent.TYPE);
        context.eventBus.unregister(handler: self, for: StreamManagementModule.FailedEvent.TYPE, StreamManagementModule.ResumedEvent.TYPE);
        responseManager.stop();
        connector.sessionLogic = nil;
    }
    
    open func serverToConnectDetails() -> XMPPSrvRecord? {
        if let redirect: XMPPSrvRecord = self.context.sessionObject.removeProperty(SocketConnector.SEE_OTHER_HOST_KEY) {
            return redirect;
        }
        return modulesManager.moduleOrNil(.streamManagement)?.resumptionLocation;
    }
    
    open func serverToConnect() -> String {
        return context.sessionObject.getProperty(SocketConnector.SERVER_HOST) ?? context.sessionObject.domainName!;
    }
    
    open func onStreamClose(completionHandler: @escaping () -> Void) {
        if let streamManagementModule = modulesManager.moduleOrNil(.streamManagement) {
            streamManagementModule.request();
            streamManagementModule.sendAck();
        }
        dispatcher.async {
            completionHandler();
        }
    }
    
    open func onStreamError(_ streamErrorEl: Element) {
        if let seeOtherHostEl = streamErrorEl.findChild(name: "see-other-host", xmlns: "urn:ietf:params:xml:ns:xmpp-streams"), let seeOtherHost = SocketConnector.preprocessConnectionDetails(string: seeOtherHostEl.value), let lastConnectionDetails: XMPPSrvRecord = self.context.sessionObject.getProperty(SocketConnector.CURRENT_CONNECTION_DETAILS) {
            if let streamFeaturesWithPipelining = modulesManager.moduleOrNil(.streamFeatures) as? StreamFeaturesModuleWithPipelining {
                streamFeaturesWithPipelining.connectionRestarted();
            }
            
            self.context.sessionObject.setUserProperty(SocketConnector.SEE_OTHER_HOST_KEY, value: XMPPSrvRecord(port: seeOtherHost.1 ?? lastConnectionDetails.port, weight: 1, priority: 1, target: seeOtherHost.0, directTls: lastConnectionDetails.directTls));
            connector.reconnect();
            return;
        }
        let errorName = streamErrorEl.findChild(xmlns: "urn:ietf:params:xml:ns:xmpp-streams")?.name;
        let streamError = errorName == nil ? nil : StreamError(rawValue: errorName!);
        context.eventBus.fire(ErrorEvent.init(sessionObject: context.sessionObject, streamError: streamError));
    }
    
    open func onStreamTerminate() {
        // we may need to adjust those condition....
        if self.connector.state == .connecting {
            modulesManager.moduleOrNil(.streamManagement)?.reset();
        }
    }
    
    open func receivedIncomingStanza(_ stanza:Stanza) {
        dispatcher.async {
            do {
                for filter in self.modulesManager.filters {
                    if filter.processIncoming(stanza: stanza) {
                        return;
                    }
                }
            
                if let handler = self.responseManager.getResponseHandler(for: stanza) {
                    handler(stanza);
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
                    self.logger.debug("\(self.context) - feature-not-implemented \(stanza, privacy: .public)");
                    throw ErrorCondition.feature_not_implemented;
                }
            } catch let error as ErrorCondition {
                let errorStanza = error.createResponse(stanza);
                self.context.writer?.write(errorStanza);
            } catch {
                let errorStanza = ErrorCondition.undefined_condition.createResponse(stanza);
                self.context.writer?.write(errorStanza);
                self.logger.debug("\(self.context) - unknown unhandled exception \(error)")
            }
        }
    }
    
    open func sendingOutgoingStanza(_ stanza: Stanza) {
        dispatcher.sync {
            for filter in self.modulesManager.filters {
                filter.processOutgoing(stanza: stanza);
            }
        }
    }
    
    open func keepalive() {
        if let pingModule = modulesManager.moduleOrNil(.ping) {
            pingModule.ping(JID(context.sessionObject.userBareJid!), callback: { (stanza) in
                if stanza == nil {
                    self.logger.debug("\(self.context) - no response on ping packet - possible that connection is broken, reconnecting...");
                }
            });
        } else {
            connector.keepAlive();
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
        case is SessionEstablishmentModule.SessionEstablishmentSuccessEvent:
            processSessionBindedAndEstablished((event as! SessionEstablishmentModule.SessionEstablishmentSuccessEvent).sessionObject);
        case let re as StreamManagementModule.ResumedEvent:
            processSessionBindedAndEstablished(re.sessionObject);
        case is StreamManagementModule.FailedEvent:
            if let bindModule = modulesManager.moduleOrNil(.resourceBind) {
                bindModule.bind();
            }
        case is AuthModule.AuthFinishExpectedEvent:
            processAuthFinishExpected();
        default:
            self.logger.debug("\(self.context) - received unhandled event: \(event)");
        }
    }
    
    func processAuthFailed(_ event:AuthModule.AuthFailedEvent) {
        self.logger.debug("\(self.context) - Authentication failed");
    }
    
    func processAuthSuccess(_ event:AuthModule.AuthSuccessEvent) {
        let streamFeaturesWithPipelining = modulesManager.moduleOrNil(.streamFeatures) as? StreamFeaturesModuleWithPipelining;

        if !(streamFeaturesWithPipelining?.active ?? false) {
            connector.restartStream();
        }
    }
    
    func processAuthFinishExpected() {
        guard let streamFeaturesWithPipelining = modulesManager.moduleOrNil(.streamFeatures) as? StreamFeaturesModuleWithPipelining else {
            return;
        }
        
        // current version of Tigase is not capable of pipelining auth with <stream> as get features is called before authentication is done!!
        if streamFeaturesWithPipelining.active {
            self.startStream();
        }
    }
    
    func processResourceBindSuccess(_ event:ResourceBinderModule.ResourceBindSuccessEvent) {
        if (SessionEstablishmentModule.isSessionEstablishmentRequired(context.sessionObject)) {
            if let sessionModule = modulesManager.moduleOrNil(.sessionEstablishment) {
                sessionModule.establish();
            } else {
                // here we should report an error
            }
        } else {
            //processSessionBindedAndEstablished(context.sessionObject);
            context.eventBus.fire(SessionEstablishmentModule.SessionEstablishmentSuccessEvent(sessionObject:context.sessionObject));
        }
    }
    
    func processSessionBindedAndEstablished(_ sessionObject:SessionObject) {
        self.logger.debug("\(self.context) - session binded and established");
        if let discoveryModule = context.modulesManager.moduleOrNil(.disco) {
            discoveryModule.discoverServerFeatures(onInfoReceived: nil, onError: nil);
            discoveryModule.discoverAccountFeatures(onInfoReceived: nil, onError: nil);
        }
        
        if let streamManagementModule = context.modulesManager.moduleOrNil(.streamManagement) {
            if streamManagementModule.isAvailable() {
                streamManagementModule.enable();
            }
        }
    }
    
    func processStreamFeatures(_ featuresElement: Element) {
        self.logger.debug("\(self.context) - processing stream features");
        let startTlsActive = context.sessionObject.getProperty(SessionObject.STARTTLS_ACTIVE, defValue: false);
        let compressionActive = context.sessionObject.getProperty(SessionObject.COMPRESSION_ACTIVE, defValue: false);
        let authorized = (context.moduleOrNil(.auth)?.state ?? .notAuthorized) == .authorized;
        let streamManagementModule = context.modulesManager.moduleOrNil(.streamManagement);
        let resumption = (streamManagementModule?.resumptionEnabled ?? false) && (streamManagementModule?.isAvailable() ?? false);
        
        if (!startTlsActive)
            && (context.sessionObject.getProperty(SessionObject.STARTTLS_DISLABLED) != true) && self.isStartTLSAvailable() {
            connector.startTLS();
        } else if ((!compressionActive) && (context.sessionObject.getProperty(SessionObject.COMPRESSION_DISABLED) != true) && self.isZlibAvailable()) {
            connector.startZlib();
        } else if !authorized {
            self.logger.debug("\(self.context) - starting authentication");
            if let authModule:AuthModule = modulesManager.moduleOrNil(.auth) {
                if authModule.state != .inProgress {
                    authModule.login();
                } else {
                    self.logger.debug("\(self.context) - skipping authentication as it is already in progress!");
                    if resumption && context.sessionObject.userBareJid != nil {
                        streamManagementModule!.resume();
                    } else {
                        if let bindModule:ResourceBinderModule = modulesManager.moduleOrNil(.resourceBind) {
                            bindModule.bind();
                        }
                    }
                }
            }
        } else if authorized {
            if resumption && context.sessionObject.userBareJid != nil {
                streamManagementModule!.resume();
            } else {
                if let bindModule:ResourceBinderModule = modulesManager.moduleOrNil(.resourceBind) {
                    bindModule.bind();
                }
            }
        }
        self.logger.debug("\(self.context) - finished processing stream features");
    }
    
    func isStartTLSAvailable() -> Bool {
        self.logger.debug("\(self.context) - checking TLS");
        let featuresElement = StreamFeaturesModule.getStreamFeatures(context.sessionObject);
        return (featuresElement?.findChild(name: "starttls", xmlns: "urn:ietf:params:xml:ns:xmpp-tls")) != nil;
    }
    
    func isZlibAvailable() -> Bool {
        let featuresElement = StreamFeaturesModule.getStreamFeatures(context.sessionObject);
        return (featuresElement?.getChildren(name: "compression", xmlns: "http://jabber.org/features/compress").firstIndex(where: {(e) in e.findChild(name: "method")?.value == "zlib" })) != nil;
    }
    
    open func startStream() {
        let userJid:BareJID? = self.context.sessionObject.getProperty(SessionObject.USER_BARE_JID);
        // replace with this first one to enable see-other-host feature
        //self.send("<stream:stream from='\(userJid)' to='\(userJid.domain)' version='1.0' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>")
        let domain = self.context.sessionObject.domainName!;
        let seeOtherHost = (self.context.sessionObject.getProperty(SocketConnector.SEE_OTHER_HOST_KEY, defValue: true) && userJid != nil) ? " from='\(userJid!)'" : ""
        self.connector.send(data: "<stream:stream to='\(domain)'\(seeOtherHost) version='1.0' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>")
        
        if let streamFeaturesWithPipelining = self.context.modulesManager.moduleOrNil(.streamFeatures) as? StreamFeaturesModuleWithPipelining {
            streamFeaturesWithPipelining.streamStarted();
        }
    }
    
    /// Event fired when XMPP stream error happens
    open class ErrorEvent: Event {
        
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ErrorEvent();
        
        public let type = "errorEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Type of stream error which was received - may be nil if it is not known
        public let streamError:StreamError?;
        
        init() {
            sessionObject = nil;
            streamError = nil;
        }
        
        public init(sessionObject: SessionObject, streamError:StreamError?) {
            self.sessionObject = sessionObject;
            self.streamError = streamError;
        }
    }
}

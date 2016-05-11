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

public protocol XmppSessionLogic:class {
    
    var state:SocketConnector.State { get }
    
    func bind();
    func unbind();
    
    func receivedIncomingStanza(stanza:Stanza);
    func sendingOutgoingStanza(stanza:Stanza);
    
    func onStreamError(streamError:Element);
    
    func serverToConnect() -> String;
}

public class SocketSessionLogic: Logger, XmppSessionLogic, EventHandler {
    
    private let context:Context;
    private let modulesManager:XmppModulesManager;
    private let connector:SocketConnector;
    private let responseManager:ResponseManager;

    public var state:SocketConnector.State {
        let s = connector.state;
        if s == .connected && ResourceBinderModule.getBindedJid(context.sessionObject) == nil {
            return .connecting;
        }
        return s;
    }
    
    public init(connector:SocketConnector, modulesManager:XmppModulesManager, responseManager:ResponseManager, context:Context) {
        self.connector = connector;
        self.context = context;
        self.modulesManager = modulesManager;
        self.responseManager = responseManager;
    }
    
    public func bind() {
        connector.sessionLogic = self;
        context.eventBus.register(self, events: StreamFeaturesReceivedEvent.TYPE);
        context.eventBus.register(self, events: AuthModule.AuthSuccessEvent.TYPE, AuthModule.AuthFailedEvent.TYPE);
        context.eventBus.register(self, events: SessionEstablishmentModule.SessionEstablishmentSuccessEvent.TYPE, SessionEstablishmentModule.SessionEstablishmentErrorEvent.TYPE);
        context.eventBus.register(self, events: ResourceBinderModule.ResourceBindSuccessEvent.TYPE, ResourceBinderModule.ResourceBindErrorEvent.TYPE);
        responseManager.start();
    }
    
    public func unbind() {
        context.eventBus.unregister(self, events: StreamFeaturesReceivedEvent.TYPE);
        context.eventBus.unregister(self, events: AuthModule.AuthSuccessEvent.TYPE, AuthModule.AuthFailedEvent.TYPE);
        context.eventBus.unregister(self, events: SessionEstablishmentModule.SessionEstablishmentSuccessEvent.TYPE, SessionEstablishmentModule.SessionEstablishmentErrorEvent.TYPE);
        context.eventBus.unregister(self, events: ResourceBinderModule.ResourceBindSuccessEvent.TYPE, ResourceBinderModule.ResourceBindErrorEvent.TYPE);
        responseManager.stop();
        connector.sessionLogic = nil;
    }
    
    public func serverToConnect() -> String {
        let userJid:BareJID = context.sessionObject.getProperty(SessionObject.USER_BARE_JID)!;
        let domain = userJid.domain;
        let streamManagementModule:StreamManagementModule? = modulesManager.getModule(StreamManagementModule.ID);
        return streamManagementModule?.resumptionLocation ?? context.sessionObject.getProperty(SocketConnector.SERVER_HOST) ?? domain;
    }
    
    public func onStreamError(streamErrorEl: Element) {
        if let seeOtherHost = streamErrorEl.findChild("see-other-host", xmlns: "urn:ietf:params:xml:ns:xmpp-streams") {
            connector.reconnect(seeOtherHost.value!)
            return;
        }
        let errorName = streamErrorEl.findChild(xmlns: "urn:ietf:params:xml:ns:xmpp-streams")?.name;
        let streamError = errorName == nil ? nil : StreamError(rawValue: errorName!);
        context.eventBus.fire(ErrorEvent.init(sessionObject: context.sessionObject, streamError: streamError));
    }
    
    public func receivedIncomingStanza(stanza:Stanza) {
        do {
            for filter in modulesManager.filters {
                if filter.processIncomingStanza(stanza) {
                    return;
                }
            }
            
            if let handler = responseManager.getResponseHandler(stanza) {
                handler(stanza);
                return;
            }
            
            guard stanza.name != "iq" || (stanza.type != StanzaType.result && stanza.type != StanzaType.error) else {
                return;
            }
            
            let modules = modulesManager.findModules(stanza);
            log("stanza:", stanza, "will be processed by", modules);
            if !modules.isEmpty {
                for module in modules {
                    try module.process(stanza);
                }
            } else {
                log("feature-not-implemented", stanza);
                throw ErrorCondition.feature_not_implemented;
            }
        } catch let error as ErrorCondition {
            let errorStanza = error.createResponse(stanza);
            context.writer?.write(errorStanza);
        } catch {
            let errorStanza = ErrorCondition.undefined_condition.createResponse(stanza);
            context.writer?.write(errorStanza);
            log("unknown unhandled exception", error)
        }
    }
    
    public func sendingOutgoingStanza(stanza: Stanza) {
        for filter in modulesManager.filters {
            filter.processOutgoingStanza(stanza);
        }
    }
    
    public func handleEvent(event: Event) {
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
        case let rfe as StreamManagementModule.FailedEvent:
            if let bindModule:ResourceBinderModule = modulesManager.getModule(ResourceBinderModule.ID) {
                bindModule.bind();
            }
        default:
            log("received unhandled event:", event);
        }
    }
    
    func processAuthFailed(event:AuthModule.AuthFailedEvent) {
        log("Authentication failed");
    }
    
    func processAuthSuccess(event:AuthModule.AuthSuccessEvent) {
        connector.restartStream();
    }
    
    func processResourceBindSuccess(event:ResourceBinderModule.ResourceBindSuccessEvent) {
        if (SessionEstablishmentModule.isSessionEstablishmentRequired(context.sessionObject)) {
            if let sessionModule:SessionEstablishmentModule = modulesManager.getModule(SessionEstablishmentModule.ID) {
                sessionModule.establish();
            } else {
                // here we should report an error
            }
        } else {
            //processSessionBindedAndEstablished(context.sessionObject);
            context.eventBus.fire(SessionEstablishmentModule.SessionEstablishmentSuccessEvent(sessionObject:context.sessionObject));
        }
    }
    
    func processSessionBindedAndEstablished(sessionObject:SessionObject) {
        log("session binded and established");
        if let discoveryModule:DiscoveryModule = context.modulesManager.getModule(DiscoveryModule.ID) {
            discoveryModule.discoverServerFeatures(nil, onError: nil);
        }
        
        if let streamManagementModule:StreamManagementModule = context.modulesManager.getModule(StreamManagementModule.ID) {
            if streamManagementModule.isAvailable() {
                streamManagementModule.enable();
            }
        }
    }
    
    func processStreamFeatures(featuresElement: Element) {
        log("processing stream features");
        let startTlsActive = context.sessionObject.getProperty(SessionObject.STARTTLS_ACTIVE, defValue: false);
        let authorized = context.sessionObject.getProperty(AuthModule.AUTHORIZED, defValue: false);
        let streamManagementModule:StreamManagementModule? = context.modulesManager.getModule(StreamManagementModule.ID);
        let resumption = (streamManagementModule?.resumptionEnabled ?? false) && (streamManagementModule?.isAvailable() ?? false);
        
        if (startTlsActive != true)
            && (context.sessionObject.getProperty(SessionObject.STARTTLS_DISLABLED) == nil) && self.isStartTLSAvailable() {
            connector.startTLS();
        } else if !authorized {
            log("starting authentication");
            if let authModule:AuthModule = modulesManager.getModule(AuthModule.ID) {
                authModule.login();
            }
        } else if authorized {
            if resumption {
                streamManagementModule!.resume();
            } else {
                if let bindModule:ResourceBinderModule = modulesManager.getModule(ResourceBinderModule.ID) {
                    bindModule.bind();
                }
            }
        }
        log("finished processing stream features");
    }
    
    func isStartTLSAvailable() -> Bool {
        log("checking TLS");
        let featuresElement = StreamFeaturesModule.getStringFeatures(context.sessionObject);
        return (featuresElement?.findChild("starttls", xmlns: "urn:ietf:params:xml:ns:xmpp-tls")) != nil;
    }
    
    public class ErrorEvent: Event {
        
        public static let TYPE = ErrorEvent();
        
        public let type = "errorEvent";
        public let sessionObject:SessionObject!;
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
//
// InBandRegistrationModule.swift
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

public class InBandRegistrationModule: AbstractIQModule, ContextAware {
    
    public static let ID = "InBandRegistrationModule";
    
    public let id = ID;
    
    public var context: Context!;
    public let features = [String]();
    public let criteria = Criteria.empty();
    
    public init() {
        
    }
    
    public func processGet(stanza: Stanza) throws {
        throw ErrorCondition.not_allowed;
    }
    
    public func processSet(stanza: Stanza) throws {
        throw ErrorCondition.not_allowed;
    }
    
    public func register(jid: JID? = nil, username: String?, password: String?, email: String?, callback: (Stanza?)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = jid ?? JID(ResourceBinderModule.getBindedJid(context.sessionObject)?.domain ?? context.sessionObject.domainName!);
        
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        if username != nil && !username!.isEmpty {
            query.addChild(Element(name: "username", cdata: username!));
        }
        if password != nil && !password!.isEmpty {
            query.addChild(Element(name: "password", cdata: password!));
        }
        if email != nil && !email!.isEmpty {
            query.addChild(Element(name: "email", cdata: email!));
        }
        iq.addChild(query);
        
        context.writer?.write(iq, callback: callback);
    }
    
    public func unregister(callback: (Stanza?)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = ResourceBinderModule.getBindedJid(context.sessionObject);
        
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        query.addChild(Element(name: "remove"));
        iq.addChild(query);
        
        context.writer?.write(iq, callback: callback);
    }
    
    public func isRegistrationAvailable() -> Bool {
        let featuresElement = StreamFeaturesModule.getStreamFeatures(context.sessionObject);
        return InBandRegistrationModule.isRegistrationAvailable(featuresElement);
    }
    
    public static func isRegistrationAvailable(featuresElement: Element?) -> Bool {
        return featuresElement?.findChild("register", xmlns: "http://jabber.org/features/iq-register") != nil;
    }
    
    public static func connectAndRegister(var client: XMPPClient! = nil, userJid: BareJID, password: String?, email: String?, onSuccess: ()->Void, onError: (ErrorCondition?)->Void) -> XMPPClient {
        if client == nil {
            client = XMPPClient();
        }
        
        client.modulesManager.register(StreamFeaturesModule());
        let registrationModule: InBandRegistrationModule = client.modulesManager.register(InBandRegistrationModule());
        
        client.connectionConfiguration.setDomain(client.sessionObject.domainName ?? userJid.domain);
        
        let handler = RegistrationEventHandler(client: client);
        handler.userJid = userJid;
        handler.password = password;
        handler.email = email;
        handler.onSuccess = onSuccess;
        handler.onError = onError;
        
        client.login();
        
        return client;
    }
    
    class RegistrationEventHandler: EventHandler {
        
        var client: XMPPClient! {
            willSet {
                if newValue == nil {
                    let curr = self.client;
                    self.unregisterEvents(curr);
                    dispatch_async(dispatch_get_main_queue()) {
                        curr.disconnect();
                    }
                }
            }
        }
        var context: Context! {
            return client.context;
        }
        var userJid: BareJID!;
        var password: String?;
        var email: String?;
        var onSuccess: (() -> Void)?;
        var onError: ((ErrorCondition?) -> Void)?;
        
        init(client: XMPPClient) {
            self.client = client;
            registerEvents(client);
        }
        
        func registerEvents(client: XMPPClient) {
            client.eventBus.register(self, events: StreamFeaturesReceivedEvent.TYPE, SocketConnector.DisconnectedEvent.TYPE);
        }
        
        func unregisterEvents(client: XMPPClient) {
            client.eventBus.unregister(self, events: StreamFeaturesReceivedEvent.TYPE, SocketConnector.DisconnectedEvent.TYPE);
        }
        
        func handleEvent(event: Event) {
            switch event {
            case let sfe as StreamFeaturesReceivedEvent:
                // check registration possibility
                let startTlsActive = context.sessionObject.getProperty(SessionObject.STARTTLS_ACTIVE, defValue: false);
                let compressionActive = context.sessionObject.getProperty(SessionObject.COMPRESSION_ACTIVE, defValue: false);
                let featuresElement = StreamFeaturesModule.getStreamFeatures(context.sessionObject);
                
                guard startTlsActive || context.sessionObject.getProperty(SessionObject.STARTTLS_DISLABLED, defValue: false) || ((featuresElement?.findChild("starttls", xmlns: "urn:ietf:params:xml:ns:xmpp-tls")) == nil) else {
                    return;
                }
                
                guard compressionActive || context.sessionObject.getProperty(SessionObject.COMPRESSION_DISABLED, defValue: false) || ((featuresElement?.getChildren("compression", xmlns: "http://jabber.org/features/compress").indexOf({(e) in e.findChild("method")?.value == "zlib" })) == nil) else {
                    return;
                }
                
                guard InBandRegistrationModule.isRegistrationAvailable(featuresElement) else {
                    self.onSuccess = nil;
                    self.client = nil;
                    self.onError?(ErrorCondition.feature_not_implemented);
                    return;
                }
                
                let regModule: InBandRegistrationModule = context.modulesManager.getModule(InBandRegistrationModule.ID)!;
                regModule.register(username: userJid.localPart, password: password, email: email, callback: { (stanza) in
                    var errorCondition:ErrorCondition?;
                    if let type = stanza?.type {
                        switch type {
                        case .result:
                            self.onError = nil;
                            self.client = nil;
                            self.onSuccess?();
                            return;
                        default:
                            if let name = stanza!.element.findChild("error")?.firstChild()?.name {
                                errorCondition = ErrorCondition(rawValue: name);
                            }
                        }
                    }
                    self.onSuccess = nil;
                    self.client = nil;
                    self.onError?(errorCondition);
                });
            case is SocketConnector.DisconnectedEvent:
                onSuccess = nil;
                self.client = nil;
                onError?(ErrorCondition.service_unavailable);
            default:
                break;
            }
        }
        
    }
}
//
// PushNotificationModule.swift
//
// TigaseSwift
// Copyright (C) 2017 "Tigase, Inc." <office@tigase.com>
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
import Combine

extension XmppModuleIdentifier {
    public static var push: XmppModuleIdentifier<PushNotificationsModule> {
        return PushNotificationsModule.IDENTIFIER;
    }
}

open class PushNotificationsModule: XmppModuleBase, XmppModule {
    
    public static let PUSH_NOTIFICATIONS_XMLNS = "urn:xmpp:push:0";
    
    public static let ID = PUSH_NOTIFICATIONS_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<PushNotificationsModule>();
    
    public let criteria = Criteria.name("message").add(Criteria.name("pubsub", xmlns: PubSubModule.PUBSUB_XMLNS).add(Criteria.name("affiliation")));
    
    public let features = [String]();
    
    open var isAvailable: Bool {
        if let features: [String] = context?.module(.disco).accountDiscoResult.features {
            if features.contains(PushNotificationsModule.PUSH_NOTIFICATIONS_XMLNS) {
                return true;
            }
        }
        
        // TODO: fallback to handle previous behavior - remove it later on...
        if let features: [String] = context?.module(.disco).serverDiscoResult.features {
            if features.contains(PushNotificationsModule.PUSH_NOTIFICATIONS_XMLNS) {
                return true;
            }
        }
        
        return false;
    }
    
    open func isSupported(extension type: PushNotificationsModuleExtension.Type) -> Bool {
        if let features: [String] = context?.module(.disco).accountDiscoResult.features {
            return features.contains(type.XMLNS);
        }
        return false;
    }
    
    open func isSupported(feature: String) -> Bool {
        if let features: [String] = context?.module(.disco).accountDiscoResult.features {
            return features.contains(feature);
        }
        return false;
    }
//    open var pushServiceJid: JID?;
    
    public struct NotificationsDisabled {
        public let serviceJid: JID;
        public let node: String;
    }
    
    public let notificationsPublisher = PassthroughSubject<NotificationsDisabled,Never>();
    
    public override init() {
        
    }
    
    open func process(stanza: Stanza) throws {
        guard let context = context else {
            return;
        }
        guard let from = stanza.from, let pubsubEl = stanza.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS) else {
            return;
        }
        guard let affiliationEl = pubsubEl.firstChild(name: "affiliation"), let node = pubsubEl.attribute("node") else {
            return;
        }
        guard let jid = BareJID(affiliationEl.attribute("jid")), let affiliation = affiliationEl.attribute("affiliation") else {
            return;
        }
        guard jid == context.userBareJid && affiliation == "none" else {
            return;
        }
    
        notificationsPublisher.send(NotificationsDisabled(serviceJid: from, node: node));
    }

    open func enable(serviceJid: JID, node: String, extensions: [PushNotificationsModuleExtension] = [], publishOptions: DataForm? = nil) async throws -> Iq {
        let iq = Iq(type: .set, {
            Element(name: "enable", xmlns: PushNotificationsModule.PUSH_NOTIFICATIONS_XMLNS, {
                Attribute("jid", value: serviceJid.description)
                Attribute("node", value: node)
                for ext in extensions {
                    ext.element()
                }
                publishOptions?.element(type: .submit, onlyModified: false)
            })
        });
        return try await write(iq: iq);
    }
    
    open func disable(serviceJid: JID, node: String) async throws -> Iq {
        let iq = Iq(type: .set, {
            Element(name: "disable", xmlns: PushNotificationsModule.PUSH_NOTIFICATIONS_XMLNS, {
                Attribute("jid", value: serviceJid.description)
                Attribute("node", value: node)
            })
        })
        return try await write(iq: iq);
    }
    
}

public protocol PushNotificationsModuleExtension {
    
    static var XMLNS: String { get }
 
    func apply(to enableEl: Element);

    func hash(into hasher: inout Hasher);
    
    func element() -> ElementItemProtocol
}

extension PushNotificationsModuleExtension {

    static func isSupported(features: [String]) -> Bool {
        return features.contains(XMLNS);
    }
    
}

// async-await support
extension PushNotificationsModule {
    
    open func enable(serviceJid: JID, node: String, extensions: [PushNotificationsModuleExtension] = [], publishOptions: DataForm? = nil, completionHandler: @escaping (Result<Iq,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await enable(serviceJid: serviceJid, node: node, extensions: extensions, publishOptions: publishOptions)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    open func disable(serviceJid: JID, node: String, completionHandler: @escaping (Result<Iq,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await disable(serviceJid: serviceJid, node: node)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
}

//
// TigasePushNotificationsModule.swift
//
// TigaseSwift
// Copyright (C) 2019 "Tigase, Inc." <office@tigase.com>
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

open class TigasePushNotificationsModule: PushNotificationsModule {
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "TigasePushNotificationsModule");
    
    open func registerDevice(serviceJid: JID, provider: String, deviceId: String, pushkitDeviceId: String? = nil, completionHandler: @escaping (Result<RegistrationResult,XMPPError>)->Void) {
        let adhocModule = context.modulesManager.module(.adhoc);
        
        let data = JabberDataElement(type: .submit);
        data.addField(TextSingleField(name: "provider", value: provider));
        data.addField(TextSingleField(name: "device-token", value: deviceId));
        if pushkitDeviceId != nil {
            data.addField(TextSingleField(name: "device-second-token", value: pushkitDeviceId));
        }
        
        adhocModule.execute(on: serviceJid, command: "register-device", action: .execute, data: data, completionHandler: { result in
            completionHandler(result.flatMap({ response in
                guard let result = RegistrationResult(form: response.form) else {
                    return .failure(.undefined_condition);
                }
                return .success(result);
            }))
        });
    }
    
    open func unregisterDevice(serviceJid: JID, provider: String, deviceId: String, completionHandler: @escaping (Result<Void, XMPPError>)->Void) {
        let adhocModule: AdHocCommandsModule = context.modulesManager.module(.adhoc);
        
        let data = JabberDataElement(type: .submit);
        data.addField(TextSingleField(name: "provider", value: provider));
        data.addField(TextSingleField(name: "device-token", value: deviceId));
        
        adhocModule.execute(on: serviceJid, command: "unregister-device", action: .execute, data: data, completionHandler: { result in
            switch result {
            case .success(_):
                completionHandler(.success(Void()));
            case .failure(let error):
                completionHandler(.failure(error));
            }
        });
    }
    
    open func findPushComponent(requiredFeatures: [String], completionHandler: @escaping (Result<JID,XMPPError>)->Void) {
        let discoModule = context.modulesManager.module(.disco);
        discoModule.getItems(for: JID(context.userBareJid.domain), node: nil, completionHandler: { result in
            switch result {
            case .success(let items):
                var found: [JID] = [];
                let group = DispatchGroup();
                group.notify(queue: DispatchQueue.main, execute: {
                    if let jid = found.first {
                        completionHandler(.success(jid));
                    } else {
                        completionHandler(.failure(.item_not_found));
                    }
                })
                group.enter();
                for item in items.items {
                    group.enter();
                    discoModule.getInfo(for: item.jid, node: item.node, completionHandler: { result in
                        switch result {
                        case .success(let info):
                            if (!info.identities.filter({ (identity) -> Bool in
                                identity.category == "pubsub" && identity.type == "push"
                            }).isEmpty) && Set(requiredFeatures).isSubset(of: info.features) {
                                DispatchQueue.main.async {
                                    found.append(item.jid);
                                }
                            }
                        case .failure(_):
                            break;
                        }
                        group.leave();
                    });
                }
                group.leave();
            case .failure(let error):
                completionHandler(.failure(error));
            }
        });
    }
    
    private class DiscoResults {
        
        let items: [DiscoveryModule.Item];
        let completionHandler: (([JID])->Void);
        
        var responses = 0;
        var found: [JID] = [];
        
        init(items: [DiscoveryModule.Item], completionHandler: @escaping (([JID])->Void)) {
            self.items = items;
            self.completionHandler = completionHandler;
        }
        
        func found(_ jid: JID) {
            DispatchQueue.main.async {
                self.found.append(jid);
                self.responses += 1;
                self.checkFinished();
                
            }
        }
        
        func failure() {
            DispatchQueue.main.async {
                self.responses += 1;
                self.checkFinished();
            }
        }
        
        func checkFinished() {
            if (self.responses == items.count) {
                self.completionHandler(found);
            }
        }
        
    }
    
    open class RegistrationResult {
        
        public let node: String;
        public let features: [String]?;
        public let maxPayloadSize: Int?;
        
        init?(form resultData: JabberDataElement?) {
            guard let node = (resultData?.getField(named: "node") as? TextSingleField)?.value else {
                return nil;
            }
            self.node = node;
            features = (resultData?.getField(named: "features") as? TextMultiField)?.value;
            maxPayloadSize = Int((resultData?.getField(named: "max-payload-size") as? TextSingleField)?.value ?? "");
        }
        
    }
    
    public struct Encryption: PushNotificationsModuleExtension, Hashable {
        
        public static let AES_128_GCM = "tigase:push:encrypt:aes-128-gcm";
        
        public static let XMLNS = "tigase:push:encrypt:0";
        
        public let algorithm: String;
        public let key: Data;
        public let maxPayloadSize: Int?;
        
        public init(algorithm: String, key: Data, maxPayloadSize: Int? = nil) {
            self.key = key;
            self.algorithm = algorithm;
            self.maxPayloadSize = maxPayloadSize;
        }
        
        public func apply(to enableEl: Element) {
            let encryptEl = Element(name: "encrypt", cdata: key.base64EncodedString(), attributes: ["xmlns": Encryption.XMLNS, "alg": algorithm]);
            if let maxSize = maxPayloadSize {
                encryptEl.setAttribute("max-size", value: String(maxSize));
            }
            enableEl.addChild(encryptEl);
        }
        
    }
    
    public struct Priority: PushNotificationsModuleExtension, Hashable {
        
        public static let XMLNS = "tigase:push:priority:0";
        
        public init() {}
        
        public func apply(to enableEl: Element) {
            enableEl.addChild(Element(name: "priority", xmlns: Priority.XMLNS));
        }
        
    }
    
    public struct GroupchatFilter: PushNotificationsModuleExtension, Hashable {

        public static let XMLNS = "tigase:push:filter:groupchat:0";
        
        public let rules: [Rule];
        
        public init(rules: [Rule]) {
            self.rules = rules;
        }
        
        public func apply(to enableEl: Element) {
            let muc = Element(name: "groupchat", xmlns: GroupchatFilter.XMLNS);
            
            for rule in rules {
                switch rule {
                case .always(let room):
                    muc.addChild(Element(name: "room", attributes: ["jid": room.stringValue, "allow": "always"]));
                case .never(_):
                    break;
                case .mentioned(let room, let nickname):
                    muc.addChild(Element(name: "room", attributes: ["jid": room.stringValue, "allow": "mentioned", "nick": nickname]));
                }
            }
            
            enableEl.addChild(muc);
        }
     
        public enum Rule: Hashable {
            case always(room: BareJID)
            case mentioned(room: BareJID, nickname: String)
            case never(room: BareJID)
        }
    }
    
    public struct IgnoreUnknown: PushNotificationsModuleExtension, Hashable {
        
        public static let XMLNS = "tigase:push:filter:ignore-unknown:0";
        
        public init() {}
        
        public func apply(to enableEl: Element) {
            enableEl.addChild(Element(name: "ignore-unknown", xmlns: IgnoreUnknown.XMLNS));
        }
        
    }
    
    public struct Muted: PushNotificationsModuleExtension, Hashable {
        
        public static let XMLNS = "tigase:push:filter:muted:0";
               
        let jids: [BareJID];
        
        public init(jids: [BareJID]) {
            self.jids = jids;
        }
        
        public func apply(to enableEl: Element) {
            guard !jids.isEmpty else {
                return;
            }
            let muted = Element(name: "muted", xmlns: Muted.XMLNS, children: jids.map({ (jid) -> Element in
                return Element(name: "item", attributes: ["jid": jid.stringValue]);
            }));
            enableEl.addChild(muted);
        }
    }
    
    public struct PushForAway: PushNotificationsModuleExtension, Hashable {
        
        public static let XMLNS = "tigase:push:away:0";
        
        public init() {}
        
        public func apply(to enableEl: Element) {
            enableEl.setAttribute("away", value: "true");
        }
        
    }

    public struct Jingle: PushNotificationsModuleExtension, Hashable {
        
        public static let XMLNS = "tigase:push:jingle:0";
        
        public init() {
        }
        
        public func apply(to enableEl: Element) {
            enableEl.addChild(Element(name: "jingle", xmlns: Jingle.XMLNS));
        }
    }
}

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
    
    open override var context: Context? {
        didSet {
            adhocModule = context?.module(.adhoc);
            discoModule = context?.module(.disco);
        }
    }
    
    private var adhocModule: AdHocCommandsModule!;
    private var discoModule: DiscoveryModule!;
    
    open func registerDevice(serviceJid: JID, provider: String, deviceId: String, pushkitDeviceId: String? = nil, completionHandler: @escaping (Result<RegistrationResult,XMPPError>)->Void) {
        let data = DataForm(type: .submit);
        data.add(field: .TextSingle(var: "provider", value: provider));
        data.add(field: .TextSingle(var: "device-token", value: deviceId));
        if pushkitDeviceId != nil {
            data.add(field: .TextSingle(var: "device-second-token", value: pushkitDeviceId));
        }
        
        adhocModule.execute(on: serviceJid, command: "register-device", action: .execute, data: data, completionHandler: { result in
            completionHandler(result.flatMap({ response in
                guard let form = response.form, let result = RegistrationResult(form: form) else {
                    return .failure(.undefined_condition);
                }
                return .success(result);
            }))
        });
    }
    
    open func unregisterDevice(serviceJid: JID, provider: String, deviceId: String, completionHandler: @escaping (Result<Void, XMPPError>)->Void) {
        let data = DataForm(type: .submit);
        data.add(field: .TextSingle(var: "provider", value: provider));
        data.add(field: .TextSingle(var: "device-token", value: deviceId));
        
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
        guard let context = context else {
            completionHandler(.failure(.remote_server_timeout));
            return;
        }
        discoModule.items(for: JID(context.userBareJid.domain), node: nil, completionHandler: { result in
            switch result {
            case .success(let items):
                var found: [JID] = [];
                let group = DispatchGroup();
                group.enter();
                for item in items.items {
                    group.enter();
                    self.discoModule.info(for: item.jid, node: item.node, completionHandler: { result in
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
                group.notify(queue: DispatchQueue.main, execute: {
                    if let jid = found.first {
                        completionHandler(.success(jid));
                    } else {
                        completionHandler(.failure(XMPPError(condition: .item_not_found)));
                    }
                })
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
    
        init?(form: DataForm) {
            guard let node = form.value(for: "node", type: String.self) else {
                return nil;
            }
            self.node = node;
            features = form.value(for: "features", type: [String].self);
            maxPayloadSize = form.value(for: "max-payload-size", type: Int.self);
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
                encryptEl.attribute("max-size", newValue: String(maxSize));
            }
            enableEl.addChild(encryptEl);
        }
        
        public func element() -> ElementItemProtocol {
            Element(name: "encrypt", xmlns: Encryption.XMLNS, cdata: key.base64EncodedString(), {
                Attribute("alg", value:  algorithm)
                if let maxSize = maxPayloadSize {
                    Attribute("max-size", value: String(maxSize));
                }
            })
        }
        
    }
    
    public struct Priority: PushNotificationsModuleExtension, Hashable {
        
        public static let XMLNS = "tigase:push:priority:0";
        
        public init() {}
        
        public func apply(to enableEl: Element) {
            enableEl.addChild(Element(name: "priority", xmlns: Priority.XMLNS));
        }
        
        public func element() -> ElementItemProtocol {
            Element(name: "priority", xmlns: Priority.XMLNS)
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
                    muc.addChild(Element(name: "room", attributes: ["jid": room.description, "allow": "always"]));
                case .never(_):
                    break;
                case .mentioned(let room, let nickname):
                    muc.addChild(Element(name: "room", attributes: ["jid": room.description, "allow": "mentioned", "nick": nickname]));
                }
            }
            
            enableEl.addChild(muc);
        }
        
        public func element() -> ElementItemProtocol {
            let muc = Element(name: "groupchat", xmlns: GroupchatFilter.XMLNS);
            
            for rule in rules {
                switch rule {
                case .always(let room):
                    muc.addChild(Element(name: "room", attributes: ["jid": room.description, "allow": "always"]));
                case .never(_):
                    break;
                case .mentioned(let room, let nickname):
                    muc.addChild(Element(name: "room", attributes: ["jid": room.description, "allow": "mentioned", "nick": nickname]));
                }
            }
            
            return muc;
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
        
        public func element() -> ElementItemProtocol {
            Element(name: "ignore-unknown", xmlns: IgnoreUnknown.XMLNS)
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
                return Element(name: "item", attributes: ["jid": jid.description]);
            }));
            enableEl.addChild(muted);
        }
        
        public func element() -> ElementItemProtocol {
            if jids.isEmpty {
                return []
            }
            return Element(name: "muted", xmlns: Muted.XMLNS, children: jids.map({ (jid) -> Element in
                return Element(name: "item", attributes: ["jid": jid.description]);
            }))
        }
    }
    
    public struct PushForAway: PushNotificationsModuleExtension, Hashable {
        
        public static let XMLNS = "tigase:push:away:0";
        
        public init() {}
        
        public func apply(to enableEl: Element) {
            enableEl.attribute("away", newValue: "true");
        }
        
        public func element() -> ElementItemProtocol {
            Attribute("away", value: "true")
        }
        
    }

    public struct Jingle: PushNotificationsModuleExtension, Hashable {
        
        public static let XMLNS = "tigase:push:jingle:0";
        
        public init() {
        }
        
        public func apply(to enableEl: Element) {
            enableEl.addChild(Element(name: "jingle", xmlns: Jingle.XMLNS));
        }
        
        public func element() -> ElementItemProtocol {
            Element(name: "jingle", xmlns: Jingle.XMLNS)
        }
    }
}

// async-await support
extension TigasePushNotificationsModule {
    
    open func registerDevice(serviceJid: JID, provider: String, deviceId: String, pushkitDeviceId: String? = nil) async throws -> RegistrationResult {
        return try await withUnsafeThrowingContinuation { continuation in
            registerDevice(serviceJid: serviceJid, provider: provider, deviceId: deviceId, pushkitDeviceId: pushkitDeviceId, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func unregisterDevice(serviceJid: JID, provider: String, deviceId: String) async throws {
        return try await withUnsafeThrowingContinuation { continuation in
            unregisterDevice(serviceJid: serviceJid, provider: provider, deviceId: deviceId, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func findPushComponents(requiredFeatures: [String]) async throws -> [JID] {
        guard let disco = self.context?.module(.disco) else {
            throw XMPPError(condition: .unexpected_request, message: "No context!")
        }
        
        let components = try await disco.serverComponents().items.map({ $0.jid });
        return await withTaskGroup(of: JID?.self, body: { group in
            for componentJid in components {
                group.addTask {
                    guard let info = try? await disco.info(for: componentJid), info.identities.contains(where: { $0.category == "pubsub" && $0.type == "push" }), Set(requiredFeatures).isSubset(of: info.features) else {
                        return nil;
                    }

                    return componentJid;
                }
            }
            
            var result: [JID] = [];
            for await component in group {
                if let comp = component {
                    result.append(comp);
                }
            }
            
            return result;
        });
    }
    
}

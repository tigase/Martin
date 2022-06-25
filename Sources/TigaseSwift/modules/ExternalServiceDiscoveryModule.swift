//
// ExternalServiceDiscoveryModule.swift
//
// TigaseSwift
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
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

extension XmppModuleIdentifier {
    public static var externalServiceDiscovery: XmppModuleIdentifier<ExternalServiceDiscoveryModule> {
        return ExternalServiceDiscoveryModule.IDENTIFIER;
    }
}

open class ExternalServiceDiscoveryModule: XmppModuleBase, XmppModule {

    public static let XMLNS = "urn:xmpp:extdisco:2";
    public static let ID = XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<ExternalServiceDiscoveryModule>();
    
    public let criteria: Criteria = Criteria.empty();
    public let features: [String] = [];
    
    open var isAvailable: Bool {
        guard let serverFeatures: [String] = context?.module(.disco).serverDiscoResult.features else {
            return false;
        }
        return serverFeatures.contains(ExternalServiceDiscoveryModule.XMLNS);
    }
    
    public override init() {
        
    }
    
    public func process(stanza: Stanza) throws {
        throw ErrorCondition.feature_not_implemented;
    }
    
    public func discover(from jid: JID?, type: String?, completionHandler: @escaping (Result<[Service],XMPPError>)->Void) {
        guard let context = context else {
            completionHandler(.failure(.remote_server_timeout));
            return;
        }
        let iq = Iq();
        iq.to = jid ?? JID(context.userBareJid.domain);
        iq.type = .get;
        let servicesEl = Element(name: "services", xmlns: ExternalServiceDiscoveryModule.XMLNS);
        if type != nil {
            servicesEl.setAttribute("type", value: type);
        }
        iq.addChild(servicesEl);
        
        write(iq, completionHandler: { result in
            completionHandler(result.map { response in
                return response.findChild(name: "services", xmlns: ExternalServiceDiscoveryModule.XMLNS)?.mapChildren(transform: Service.parse(_:)) ?? [];
            })
        })
    }
    
    open class Service {

        public let expires: Date?;
        public let host: String;
        public let name: String?;
        public let password: String?;
        public let port: UInt16?;
        public let restricted: Bool;
        public let transport: Transport?;
        public let type: String;
        public let username: String?;
                
        init(type: String, host: String, port: UInt16? = nil, transport: Transport? = nil, name: String? = nil, restricted: Bool = false, username: String? = nil, password: String? = nil, expires: Date? = nil) {
            self.type = type;
            self.host = host;
            self.port = port;
            self.transport = transport;
            self.name = name;
            self.restricted = restricted;
            self.username = username;
            self.password = password;
            self.expires = expires;
        }
        
        public enum Transport: String {
            case tcp
            case udp
        }
        
        public static func parse(_ el: Element) -> Service? {
            guard el.name == "service", let type = el.getAttribute("type"), let host = el.getAttribute("host") else {
                return nil;
            }
            
            let portStr = el.getAttribute("port");
            let transportStr = el.getAttribute("transport")?.lowercased();
            let restrictedStr = el.getAttribute("restricted");
            return Service(type: type, host: host, port: portStr == nil ? nil : UInt16(portStr!), transport: transportStr == nil ? nil : Transport(rawValue: transportStr!), name: el.getAttribute("name"), restricted: "1" == restrictedStr || "true" == restrictedStr, username: el.getAttribute("username"), password: el.getAttribute("password"), expires: TimestampHelper.parse(timestamp: el.getAttribute("expires")));
        }
    }
    
}

// async-await support
extension ExternalServiceDiscoveryModule {
    
    public func discover(from jid: JID?, type: String?) async throws -> [Service] {
        return try await withUnsafeThrowingContinuation { continuation in
            discover(from: jid, type: type, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
}

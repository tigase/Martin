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

open class ExternalServiceDiscoveryModule: XmppModule, ContextAware {

    public static let XMLNS = "urn:xmpp:extdisco:2";
    public static let ID = XMLNS;
    
    public let id: String = ID;
    public let criteria: Criteria = Criteria.empty();
    public let features: [String] = [];
    
    open var context:Context!;
    
    open var isAvailable: Bool {
        guard let serverFeatures: [String] = context?.sessionObject.getProperty(DiscoveryModule.SERVER_FEATURES_KEY) else {
            return false;
        }
        return serverFeatures.contains(ExternalServiceDiscoveryModule.XMLNS);
    }
    
    public init() {
        
    }
    
    public func process(stanza: Stanza) throws {
        throw ErrorCondition.feature_not_implemented;
    }
    
    public func discover(from jid: JID?, type: String?, completionHandler: @escaping (Result<[Service],ErrorCondition>)->Void) {
        let iq = Iq();
        iq.to = jid ?? JID(context.sessionObject.userBareJid?.domain);
        iq.type = .get;
        let servicesEl = Element(name: "services", xmlns: ExternalServiceDiscoveryModule.XMLNS);
        if type != nil {
            servicesEl.setAttribute("type", value: type);
        }
        iq.addChild(servicesEl);
        
        context.writer?.write(iq, completionHandler: { result in
            switch result {
            case .success(let response):
                let services = response.findChild(name: "services", xmlns: ExternalServiceDiscoveryModule.XMLNS)?.mapChildren(transform: Service.parse(_:)) ?? [];
                completionHandler(.success(services));
            case .failure(let errorCondition, _):
                completionHandler(.failure(errorCondition));
            }
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

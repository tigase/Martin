//
// XMPPError.swift
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

public struct XMPPError: Error, CustomStringConvertible, Sendable {
    
    public static let remote_server_timeout = XMPPError(condition: .remote_server_timeout);
    public static let undefined_condition = XMPPError(condition: .undefined_condition);
    
    public static var applicationErrorDecocers: [(Element)->ApplicationErrorCondition?] = [PubSubErrorCondition.init(errorEl:)];
    
    public var description: String  {
        return "XMPPError(condition: \(condition.rawValue), applicationCondition: \(applicationCondition?.description ?? "nil"), message: \(message ?? "nil")";
    }
    
    public let condition: ErrorCondition;
    public let message: String?;
    public let applicationCondition: ApplicationErrorCondition?;
    public let stanza: Stanza?;

    public init?(_ stanza: Stanza) {
        guard stanza.type == .error, let errorEl = stanza.firstChild(where: { $0.name ==  "error" && ($0.xmlns == stanza.xmlns || $0.xmlns == nil) }) else {
            return nil;
        }
        
        guard let errorNameEl = errorEl.firstChild(xmlns:"urn:ietf:params:xml:ns:xmpp-stanzas") else {
            return nil;
        }
        
        let message = errorEl.firstChild(where: { $0.name ==  "text" && ($0.xmlns == stanza.xmlns || $0.xmlns == nil) })?.value;
        
        let applicationCondition = XMPPError.applicationErrorDecocers.compactMap({ $0(errorEl) }).first;
        
        self.init(condition: ErrorCondition(rawValue: errorNameEl.name) ?? .undefined_condition, message: message, applicationCondition: applicationCondition, stanza: stanza);
    }
    
    public init(condition: ErrorCondition, message: String? = nil, applicationCondition: ApplicationErrorCondition? = nil, stanza: Stanza? = nil) {
        self.condition = condition;
        self.message = message;
        self.applicationCondition = applicationCondition;
        self.stanza = stanza;
    }
    
    public func element() -> Element {
        let errorEl = Element(name: "error");
        errorEl.attribute("type", newValue: self.condition.type.rawValue);
        errorEl.addChild(Element(name: self.condition.rawValue, xmlns: "urn:ietf:params:xml:ns:xmpp-stanzas"));

        if let errorText = message {
            errorEl.addChild(Element(name: "text", cdata: errorText));
        }
        
        if let applicationCondition = applicationCondition {
            errorEl.addChild(applicationCondition.element());
        }

        return errorEl;
    }
}

public protocol ApplicationErrorCondition: Error, CustomStringConvertible {
    
    func element() -> Element;
    
}

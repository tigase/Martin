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

public enum XMPPError: Error, Equatable, CustomStringConvertible {
    
    public static func == (lhs: XMPPError, rhs: XMPPError) -> Bool {
        return lhs.errorCondition == rhs.errorCondition;
    }
    
    case bad_request(_ message: String? = nil)
    case conflict(_ message: String? = nil)
    case feature_not_implemented
    case forbidden(_ message: String? = nil)
    case gone(_ message: String? = nil)
    case internal_server_error(_ message: String? = nil)
    case item_not_found
    case jid_malformed(_ message: String? = nil)
    case not_acceptable(_ message: String? = nil)
    case not_allowed(_ message: String? = nil)
    case not_authorized(_ message: String? = nil)
    case payment_required(_ message: String? = nil)
    case policy_violation(_ message: String? = nil)
    case recipient_unavailable(_ message: String? = nil)
    case redirect(uri: String?, _ message: String? = nil)
    case registration_required(_ message: String? = nil)
    case remote_server_not_found(_ message: String? = nil)
    case remote_server_timeout
    case resource_constraint(_ message: String? = nil)
    case service_unavailable(_ message: String? = nil)
    case subscription_required(_ message: String? = nil)
    case undefined_condition
    case unexpected_request(_ message: String? = nil)

    public var description: String {
        if let message = self.message {
            return "\(errorCondition.rawValue): \(message)";
        } else {
            return errorCondition.rawValue;
        }
    }
    
    public var message: String? {
        switch self {
        case .bad_request(let message):
            return message;
        case .conflict(let message):
            return message;
        case .feature_not_implemented:
            return nil;
        case .forbidden(let message):
            return message;
        case .gone(let message):
            return message;
        case .internal_server_error(let message):
            return message;
        case .item_not_found:
            return nil;
        case .jid_malformed(let message):
            return message;
        case .not_acceptable(let message):
            return message;
        case .not_allowed(let message):
            return message;
        case .not_authorized(let message):
            return message;
        case .payment_required(let message):
            return message;
        case .policy_violation(let message):
            return message;
        case .recipient_unavailable(let message):
            return message;
        case .redirect(_, let message):
            return message;
        case .registration_required(let message):
            return message;
        case .remote_server_not_found(let message):
            return message;
        case .remote_server_timeout:
            return nil;
        case .resource_constraint(let message):
            return message;
        case .service_unavailable(let message):
            return message;
        case .subscription_required(let message):
            return message;
        case .undefined_condition:
            return nil;
        case .unexpected_request(let message):
            return message;
        }
    }
    
    public var errorCondition: ErrorCondition {
        switch self {
        case .bad_request(_):
            return .bad_request;
        case .conflict(_):
            return .conflict;
        case .feature_not_implemented:
            return .feature_not_implemented;
        case .forbidden(_):
            return .forbidden;
        case .gone(_):
            return .gone;
        case .internal_server_error(_):
            return .internal_server_error;
        case .item_not_found:
            return .item_not_found;
        case .jid_malformed(_):
            return .jid_malformed;
        case .not_acceptable(_):
            return .not_acceptable;
        case .not_allowed(_):
            return .not_allowed;
        case .not_authorized( _):
            return .not_authorized
        case .payment_required( _):
            return .payment_required;
        case .policy_violation( _):
            return .policy_violation;
        case .recipient_unavailable( _):
            return .recipient_unavailable;
        case .redirect(_, _):
            return .redirect;
        case .registration_required( _):
            return .registration_required;
        case .remote_server_not_found( _):
            return .remote_server_not_found;
        case .remote_server_timeout:
            return .remote_server_timeout;
        case .resource_constraint( _):
            return .resource_constraint;
        case .service_unavailable( _):
            return .service_unavailable;
        case .subscription_required( _):
            return .subscription_required;
        case .undefined_condition:
            return .undefined_condition;
        case .unexpected_request( _):
            return .unexpected_request;
        }
    }
    
    public func createResponse(_ stanza:Stanza) -> Stanza {
        return stanza.errorResult(of: self)
    }
    
    public func element() -> Element {
        let errorCondition = self.errorCondition;

        let errorEl = Element(name: "error");
        errorEl.setAttribute("type", value: errorCondition.type);
        
        let conditon = Element(name: errorCondition.rawValue, xmlns: "urn:ietf:params:xml:ns:xmpp-stanzas");
        if case let .redirect(uri, _) = self {
            conditon.value = uri;
        }
        errorEl.addChild(conditon);
        
        if let errorText = message {
            errorEl.addChild(Element(name: "text", cdata: errorText));
        }
                
        return errorEl;
    }
    
    public static func from(stanza: Stanza?) -> XMPPError {
        guard let stanza = stanza else {
            return .remote_server_timeout;
        }
        guard let error = stanza.error else {
            return .undefined_condition;
        }
        return error;
    }
    
    public static func parse(stanza: Stanza) -> XMPPError? {
        guard stanza.type == .error, let errorEl = stanza.findChild(where: { $0.name ==  "error" && ($0.xmlns == stanza.xmlns || $0.xmlns == nil) }) else {
            return nil;
        }
        
        guard let errorNameEl = errorEl.findChild(xmlns:"urn:ietf:params:xml:ns:xmpp-stanzas"), let errorCondition = ErrorCondition(rawValue: errorNameEl.name) else {
            return .undefined_condition;
        }
        
        let text = errorEl.findChild(name: "text")?.value;
        switch errorCondition {
        case .bad_request:
            return .bad_request(text);
        case .conflict:
            return .conflict(text);
        case .feature_not_implemented:
            return .feature_not_implemented
        case .forbidden:
            return .forbidden(text)
        case .gone:
            return .gone(text)
        case .internal_server_error:
            return .internal_server_error(text);
        case .item_not_found:
            return .item_not_found;
        case .jid_malformed:
            return .jid_malformed(text);
        case .not_acceptable:
            return .not_acceptable(text);
        case .not_allowed:
            return .not_allowed(text);
        case .not_authorized:
            return .not_authorized(text);
        case .payment_required:
            return .payment_required(text);
        case .policy_violation:
            return .policy_violation(text);
        case .recipient_unavailable:
            return .recipient_unavailable(text);
        case .redirect:
            return redirect(uri: errorNameEl.value, text);
        case .registration_required:
            return .registration_required(text);
        case .remote_server_not_found:
            return .remote_server_not_found(text);
        case .remote_server_timeout:
            return .remote_server_timeout
        case .resource_constraint:
            return .resource_constraint(text);
        case .service_unavailable:
            return .service_unavailable(text);
        case .subscription_required:
            return .subscription_required(text);
        case .undefined_condition:
            return .undefined_condition
        case .unexpected_request:
            return .unexpected_request(text);
        }
    }
}

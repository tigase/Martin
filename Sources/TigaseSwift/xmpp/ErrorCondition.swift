//
// ErrorCondition.swift
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

/**
 Enum contains list of [error conditions].
 
 [error conditions]: http://xmpp.org/rfcs/rfc6120.html#stanzas-error-conditions
 */
public enum ErrorCondition: String {
    case bad_request = "bad-request"
    case conflict
    case feature_not_implemented = "feature-not-implemented"
    case forbidden
    case gone
    case internal_server_error = "internal-server-error"
    case item_not_found = "item-not-found"
    case jid_malformed = "jid-malformed"
    case not_acceptable = "not-acceptable"
    case not_allowed = "not-allowed"
    case not_authorized = "not-authorized"
    case payment_required = "payment-required"
    case policy_violation = "policy-violation"
    case recipient_unavailable = "recipiend-unavailable"
    case redirect
    case registration_required = "registration-required"
    case remote_server_not_found = "remote-server-not-found"
    case remote_server_timeout = "remote-server-timeout"
    case resource_constraint = "resource-constraint"
    case service_unavailable = "service-unavailable"
    case subscription_required = "subscription-required"
    case undefined_condition = "undefined-condition"
    case unexpected_request = "unexpected-request"
    
    public var errorDescription: String? {
        return rawValue.replacingOccurrences(of: "-", with: " ");
    }
    
    public var type: String {
        switch self {
        case .bad_request:
            return "modify";
        case .conflict:
            return "cancel";
        case .feature_not_implemented:
            return "cancel";
        case .forbidden:
            return "auth";
        case .gone:
            return "modify";
        case .internal_server_error:
            return "wait";
        case .item_not_found:
            return "cancel";
        case .jid_malformed:
            return "modify";
        case .not_acceptable:
            return "modify";
        case .not_allowed:
            return "cancel";
        case .not_authorized:
            return "auth";
        case .payment_required:
            return "auth";
        case .policy_violation:
            return "cancel";
        case .recipient_unavailable:
            return "wait";
        case .redirect:
            return "modify";
        case .registration_required:
            return "auth";
        case .remote_server_not_found:
            return "cancel";
        case .remote_server_timeout:
            return "wait";
        case .resource_constraint:
            return "wait";
        case .service_unavailable:
            return "cancel";
        case .subscription_required:
            return "auth";
        case .undefined_condition:
            return "cancel";
        case .unexpected_request:
            return "wait";
        }
    }
    
}

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
public enum ErrorCondition: String, Sendable {
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
    
    public var type: ErrorConditionType {
        switch self {
        case .bad_request, .gone, .jid_malformed, .not_acceptable, .redirect:
            return .modify;
        case .conflict, .feature_not_implemented, .item_not_found, .not_allowed, .policy_violation, .remote_server_not_found, .service_unavailable, .undefined_condition:
            return .cancel;
        case .forbidden, .not_authorized, .payment_required, .registration_required, .subscription_required:
            return .auth;
        case .internal_server_error, .recipient_unavailable, .remote_server_timeout, .resource_constraint, .unexpected_request:
            return .wait;
        }
    }
 
}

public enum ErrorConditionType: String {
    case auth
    case cancel
    case `continue`
    case modify
    case wait
}

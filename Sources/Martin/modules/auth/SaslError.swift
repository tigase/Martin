//
// SaslError.swift
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
 Contains possible SASL errors.
 */
public struct SaslError: Error, CustomStringConvertible {
    
    public enum Cause: String {
        case aborted
        case incorrect_encoding = "incorrect-encoding"
        case invalid_authzid = "invalid-authzid"
        case invalid_mechanism = "invalid-mechanism"
        case mechanism_too_weak = "mechanism-too-weak"
        case not_authorized = "not-authorized"
        case server_not_trusted = "server-not-trusted"
        case temporary_auth_failure = "temporary-auth-failure"
    }
    
    public let cause: Cause
    public let message: String?;
    
    public var description: String {
        return "SaslError(cause: \(cause.rawValue), message: \(message ?? "nil"))"
    }
    
    public init(cause: Cause, message: String?) {
        self.cause = cause
        self.message = message
    }
}

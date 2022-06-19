//
// PubSubError.swift
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

public struct PubSubError: LocalizedError, CustomStringConvertible {
    
    public static let remote_server_timeout = PubSubError(error: .remote_server_timeout, pubsubErrorCondition: nil);
    public static let undefined_condition = PubSubError(error: .undefined_condition, pubsubErrorCondition: nil);

    public let error: XMPPError;
    public let pubsubErrorCondition: PubSubErrorCondition?;
    
    public var errorDescription: String? {
        if let pubsubError = pubsubErrorCondition {
            return "\(error.message ?? pubsubError.rawValue.replacingOccurrences(of: "-", with: " ")) (\(pubsubError.rawValue), \(error.errorCondition.rawValue))";
        } else {
            return error.localizedDescription;
        }
    }
    
    public var description: String {
        if let condition = pubsubErrorCondition {
            return "\(condition.rawValue)(\(condition.rawValue))"
        } else {
            return error.description;
        }
    }
        
    public init(error: XMPPError, pubsubErrorCondition: PubSubErrorCondition?) {
        self.error = error;
        self.pubsubErrorCondition = pubsubErrorCondition;
    }
    
    public static func from(stanza: Stanza?) -> PubSubError {
        return parseError(stanza: stanza);
    }
    
    public static func parseError(stanza: Stanza?) -> PubSubError {
        guard let stanza = stanza else {
            return .remote_server_timeout;
        }

        guard let error = XMPPError.parse(stanza: stanza) else {
            return .undefined_condition;
        }
        
        if let conditionName = stanza.firstChild(name: "error")?.firstChild(xmlns: PubSubModule.PUBSUB_ERROR_XMLNS)?.name, let condition = PubSubErrorCondition(rawValue: conditionName) {
            return PubSubError(error: error, pubsubErrorCondition: condition);
        } else {
            return PubSubError(error: error, pubsubErrorCondition: nil);
        }
    }
    
}

//
// AuthModule.swift
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
import os
import Combine

extension XmppModuleIdentifier {
    public static var auth: XmppModuleIdentifier<AuthModule> {
        return AuthModule.IDENTIFIER;
    }
}

/**
 Common authentication module provides generic support for authentication.
 Other authentication module (like ie. `SaslModule`) may require this
 module to work properly.
 */
open class AuthModule: XmppModuleBase, XmppModule, Resetable, @unchecked Sendable {
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "auth";
    public static let IDENTIFIER = XmppModuleIdentifier<AuthModule>();
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "AuthModule");
    
    public let features = [String]();
    
    @Published
    open private(set) var state: AuthorizationStatus = .notAuthorized {
        willSet {
            let value = state;
            logger.debug("changing auth state to \(newValue) from \(value)")
        }
    }
    
    public override init() {
        
    }
            
    /**
     Starts authentication process using other module providing 
     mechanisms for authentication
     */
    open func login() async throws {
        if let sasl2Module = context?.modulesManager.moduleOrNil(.sasl2), sasl2Module.isSupported {
            do {
                try await sasl2Module.login();
                state = .authorized(streamRestartRequired: false);
            } catch {
                state = .error(error);
                throw error;
            }
        } else if let saslModule = context?.modulesManager.moduleOrNil(.sasl) {
            do {
                try await saslModule.login();
                state = .authorized(streamRestartRequired: true);
            } catch {
                state = .error(error);
                throw error;
            }
        } else {
            state = .notAuthorized;
            throw XMPPError(condition: .undefined_condition, message: "Missing SASL authentication module")
        }
    }
    
    open func update(state: AuthorizationStatus) {
        self.state = state;
    }
    
    public func reset(scopes: Set<ResetableScope>) {
        if scopes.contains(.stream) {
            state = .notAuthorized;
        }
    }
        
    public enum AuthorizationStatus: Equatable, CustomStringConvertible {
        
        public static func == (lhs: AuthorizationStatus, rhs: AuthorizationStatus) -> Bool {
            return lhs.value == rhs.value;
        }
        
        public var description: String {
            switch self {
            case .authorized(let streamRestartRequired):
                return ".authorized(streamRestart: \(streamRestartRequired))"
            case .inProgress:
                return ".inProgress"
            case .expectedAuthorization:
                return ".expectedAuthorization"
            case .notAuthorized:
                return ".notAuthorized"
            case .error(let error):
                return ".error(\(error))"
            }
        }
        
        public var isError: Bool {
            switch self {
            case .error(_):
                return true;
            default:
                return false;
            }
        }
        
        public var isAuthorized: Bool {
            switch self {
            case .authorized(streamRestartRequired: _):
                return true;
            default:
                return false;
            }
        }
        
        private var value: Int {
            switch self {
            case .notAuthorized:
                return 0;
            case .inProgress:
                return 1;
            case .expectedAuthorization:
                return 2;
            case .authorized(_):
                return 3;
            case .error(_):
                return -1;
            }
        }
        
        case notAuthorized
        case inProgress
        case expectedAuthorization
        case authorized(streamRestartRequired: Bool)
        case error(Error)
    }
}

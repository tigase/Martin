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
import TigaseLogging

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
open class AuthModule: XmppModuleBase, XmppModule, Resetable {
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "auth";
    public static let IDENTIFIER = XmppModuleIdentifier<AuthModule>();
    public static let CREDENTIALS_CALLBACK = "credentialsCallback";
    public static let LOGIN_USER_NAME_KEY = "LOGIN_USER_NAME";
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "AuthModule");
    
    public let criteria = Criteria.empty();
    
    public let features = [String]();
    
    @Published
    open private(set) var state: AuthorizationStatus = .notAuthorized;
    
    private var stateObserverCancellable: Cancellable?;
    
    public override init() {
        
    }
    
    deinit {
        stateObserverCancellable?.cancel();
    }
    
    open func process(stanza: Stanza) throws {
        
    }
    
    /**
     Starts authentication process using other module providing 
     mechanisms for authentication
     */
    open func login() {
        stateObserverCancellable?.cancel();
        if let saslModule = context?.modulesManager.moduleOrNil(.sasl) {
            stateObserverCancellable = saslModule.$state.sink(receiveValue: { [weak self] state in
                self?.update(state: state);
            })
            saslModule.login();
        } else {
            state = .error(XMPPError.item_not_found);
        }
    }
    
    open func update(state: AuthorizationStatus) {
        self.state = state;
        guard let context = self.context else {
            return;
        }
        
        switch state {
        case .authorized:
            fire(AuthSuccessEvent(context: context));
        case .error(let error):
            fire(AuthFailedEvent(context: context, error: error));
        case .inProgress:
            fire(AuthStartEvent(context: context))
        default:
            break;
        }
    }
    
    public func reset(scopes: Set<ResetableScope>) {
        state = .notAuthorized;
    }
    
    /// Event fired on authentication failure
    @available(* , deprecated, message: "Use $state publisher instead")
    open class AuthFailedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = AuthFailedEvent();

        /// Error returned by server during authentication
        public let error:Error!;

        init() {
            error = nil;
            super.init(type: "AuthFailedEvent");
        }

        public init(context: Context, error: Error) {
            self.error = error;
            super.init(type: "AuthFailedEvent", context: context);
        }
    }

    /// Event fired on start of authentication process
    @available(* , deprecated, message: "Use $state publisher instead")
    open class AuthStartEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = AuthStartEvent();

        init() {
            super.init(type: "AuthStartEvent");
        }

        public init(context: Context) {
            super.init(type: "AuthStartEvent", context: context);
        }
    }

    @available(* , deprecated, message: "Use $state publisher instead")
    open class AuthFinishExpectedEvent: AbstractEvent {

        public static let TYPE = AuthFinishExpectedEvent();

        init() {
            super.init(type: "AuthFinishExpectedEvent");
        }

        public init(context: Context) {
            super.init(type: "AuthFinishExpectedEvent", context: context);
        }

    }

    /// Event fired when after sucessful authentication
    @available(* , deprecated, message: "Use $state publisher instead")
    open class AuthSuccessEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = AuthSuccessEvent();

        init() {
            super.init(type: "AuthSuccessEvent");
        }

        public init(context: Context) {
            super.init(type: "AuthSuccessEvent", context: context);
        }
    }
    
    public enum AuthorizationStatus: Equatable {
        
        public static func == (lhs: AuthorizationStatus, rhs: AuthorizationStatus) -> Bool {
            return lhs.value == rhs.value;
        }
        
        public var isError: Bool {
            switch self {
            case .error(_):
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
            case .authorized:
                return 3;
            case .error(_):
                return -1;
            }
        }
        
        case notAuthorized
        case inProgress
        case expectedAuthorization
        case authorized
        case error(Error)
    }
}

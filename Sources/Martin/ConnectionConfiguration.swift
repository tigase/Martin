//
// ConnectionConfiguration.swift
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
import Combine

public struct ConnectionConfiguration {
    public var userJid: BareJID = BareJID("");
    public var resource: String? = nil;
    public var nickname: String? = nil;
    
    // how about enum with multiple password providers?
    public var credentials: Credentials = .init() {
        didSet {
            if oldValue != credentials {
                self.credentialsPublisher.send(credentials);
            }
        }
    }
    public let credentialsPublisher = PassthroughSubject<Credentials, Never>();
    
    public var disableCompression: Bool = true;
    public var disableTLS: Bool = false;
    public var useSeeOtherHost: Bool = true;
    
    /// List of available to use SASL mechanism in order of preference
    public var saslMechanisms: [SaslMechanism] =
        FastMechanism<HashAlgorithms.SHA256>.mechanisms() + [
            ScramSha256Mechanism(withChannelBinding: true),
            ScramSha256Mechanism(withChannelBinding: false),
            ScramSha1Mechanism(withChannelBinding: true),
            ScramSha1Mechanism(withChannelBinding: false),
            PlainMechanism(),
            AnonymousMechanism()
        ];
    
    public var connectorOptions: ConnectorOptions = SocketConnectorNetwork.Options();
    
    public mutating func modifyConnectorOptions<T: ConnectorOptions>(_ exec: (inout T) -> Void) {
        var options = connectorOptions as? T ?? T()
        exec(&options);
        self.connectorOptions = options;
    }
            
    public mutating func modifyConnectorOptions<T: ConnectorOptions>(type: T.Type, _ exec: (inout T) -> Void) {
        var options = connectorOptions as? T ?? T()
        exec(&options);
        self.connectorOptions = options;
    }

}

public protocol ConnectorOptions {
    
    var connector: Connector.Type { get }
    
    init()
}

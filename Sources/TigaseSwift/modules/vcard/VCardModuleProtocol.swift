//
// VCardModuleProtocol.swift
//
// TigaseSwift
// Copyright (C) 2017 "Tigase, Inc." <office@tigase.com>
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

public protocol VCardModuleProtocol {
    
    func publishVCard<Failure: Error>(_ vcard: VCard, to jid: BareJID?, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: ((Result<Iq,Failure>) -> Void)?);

    func publishVCard(_ vcard: VCard, to jid: BareJID?, completionHandler: ((Result<Void,XMPPError>)->Void)?);
    
    func retrieveVCard<Failure: Error>(from jid: JID?, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>) -> Void);
    
    func retrieveVCard(from jid: JID?, completionHandler: @escaping (Result<VCard,XMPPError>)->Void)
}

public extension VCardModuleProtocol {

    func publishVCard<Failure: Error>(_ vcard: VCard, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: ((Result<Iq,Failure>) -> Void)?) {
        publishVCard(vcard, to: nil, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    func publishVCard(_ vcard: VCard, completionHandler: ((Result<Void,XMPPError>) -> Void)?) {
        publishVCard(vcard, to: nil, completionHandler: completionHandler);
    }
    
    func retrieveVCard(completionHandler: @escaping (Result<VCard,XMPPError>)->Void) {
        retrieveVCard(from: nil, completionHandler: completionHandler);
    }
    
}

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

    func publish(vcard: VCard, to jid: BareJID?) async throws;
    func retrieveVCard(from jid: JID?) async throws -> VCard

}

public extension VCardModuleProtocol {
    
    func publish(vcard: VCard) async throws {
        try await publish(vcard: vcard, to: nil)
    }
    
    func retrieveVCard() async throws -> VCard {
        try await retrieveVCard(from: nil);
    }
    
}

// async-await support
extension VCardModuleProtocol {
    
//    public func publishVCard(_ vcard: VCard, to jid: BareJID? = nil, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
//        Task {
//            do {
//                completionHandler(.success(try await publish(vcard: vcard, to: jid)))
//            } catch {
//                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
//            }
//        }
//    }
//    
//    public func retrieveVCard(from jid: JID? = nil, completionHandler: @escaping (Result<VCard,XMPPError>)->Void) {
//        Task {
//            do {
//                completionHandler(.success(try await retrieveVCard(from: jid)))
//            } catch {
//                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
//            }
//        }
//    }

}

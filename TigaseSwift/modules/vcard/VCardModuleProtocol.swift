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
    
    func publishVCard(_ vcard: VCard, to: BareJID?, callback: ((Stanza?) -> Void)?);
    
    func publishVCard(_ vcard: VCard, to: BareJID?, onSuccess: (()->Void)?, onError: ((_ errorCondition: ErrorCondition?)->Void)?);

    func retrieveVCard(from jid: JID?, callback: @escaping (Stanza?) -> Void);
    
    func retrieveVCard(from jid: JID?, onSuccess: @escaping (_ vcard: VCard)->Void, onError: @escaping (_ errorCondition: ErrorCondition?)->Void);
}

public extension VCardModuleProtocol {

    func publishVCard(_ vcard: VCard, callback: ((Stanza?) -> Void)?) {
        publishVCard(vcard, to: nil, callback: callback);
    }
    
    func publishVCard(_ vcard: VCard, onSuccess: (()->Void)?, onError: ((_ errorCondition: ErrorCondition?)->Void)?) {
        publishVCard(vcard, to: nil, onSuccess: onSuccess, onError: onError);
    }

}

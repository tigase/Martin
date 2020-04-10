//
// ChannelInfo.swift
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

open class ChannelInfo {
    
    public let name: String?;
    public let description: String?;
    public let contact: [JID];
    
    public convenience init?(form: JabberDataElement?) {
        guard let form = form, let formType: HiddenField = form.getField(named: "FORM_TYPE"), formType.value == MixModule.CORE_XMLNS else {
            return nil;
        }
        let nameField: TextSingleField? = form.getField(named: "Name");
        let descriptionField: TextSingleField? = form.getField(named: "Description");
        let contactField: JidMultiField? = form.getField(named: "Contact");
        
        self.init(name: nameField?.value, description: descriptionField?.value, contact: contactField?.value ?? []);
    }
    
    public init(name: String?, description: String?, contact: [JID]) {
        self.name = name;
        self.description = description;
        self.contact = contact;
    }
    
    open func form() -> JabberDataElement {
        let form = JabberDataElement(type: .result);
        form.addField(HiddenField(name: "FORM_TYPE")).value = MixModule.CORE_XMLNS;
        form.addField(TextSingleField(name: "Name")).value = self.name;
        form.addField(TextSingleField(name: "Description")).value = self.description;
        form.addField(JidMultiField(name: "Contact")).value = self.contact;
        return form;
    }
}

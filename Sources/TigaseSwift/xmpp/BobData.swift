//
// BobData.swift
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

open class BobData {
    
    public let cid: String;
    public let type: String?;
    public let maxAge: UInt?;
    public let data: Data?;
    
    public init?(from el: Element) {
        guard el.name == "data" && el.xmlns == "urn:xmpp:bob", let cid = el.getAttribute("cid") else {
            return nil;
        }
        
        self.cid = cid;
        self.type = el.getAttribute("type");
        if let maxAge = el.getAttribute("max-age"), let val = UInt(maxAge) {
            self.maxAge = val;
        } else {
            self.maxAge = nil;
        }
        if let val = el.value {
            self.data = Data(base64Encoded: val, options: [.ignoreUnknownCharacters]);
        } else {
            self.data = nil;
        }
    }
    
    public init(cid: String, type: String? = nil, maxAge: UInt? = nil, data: Data? = nil) {
        self.cid = cid;
        self.type = type;
        self.maxAge = maxAge;
        self.data = data;
    }
    
    open func toElement() -> Element {
        let el = Element(name: "data", xmlns: "urn:xmpp:bob");
        el.setAttribute("cid", value: cid);
        el.setAttribute("type", value: type);
        if let maxAge = self.maxAge {
            el.setAttribute("max-age", value: String(maxAge));
        }
        el.value = data?.base64EncodedString();
        return el;
    }
    
    open func matches(uri: String) -> Bool {
        guard uri.starts(with: "cid:") else {
            return false;
        }
        return String(uri.dropFirst(4)) == cid;
    }
}

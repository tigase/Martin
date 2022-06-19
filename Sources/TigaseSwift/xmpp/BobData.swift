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

public struct BobData {
    
    public let cid: String;
    public let type: String?;
    public let maxAge: UInt?;
    public let data: Data?;
    
    public init?(from el: Element) {
        guard el.name == "data" && el.xmlns == "urn:xmpp:bob", let cid = el.attribute("cid") else {
            return nil;
        }
        
        self.cid = cid;
        self.type = el.attribute("type");
        if let maxAge = el.attribute("max-age"), let val = UInt(maxAge) {
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
    
    public func toElement() -> Element {
        let el = Element(name: "data", xmlns: "urn:xmpp:bob");
        el.attribute("cid", newValue: cid);
        el.attribute("type", newValue: type);
        if let maxAge = self.maxAge {
            el.attribute("max-age", newValue: String(maxAge));
        }
        el.value = data?.base64EncodedString();
        return el;
    }
    
    public func matches(uri: String) -> Bool {
        guard uri.starts(with: "cid:") else {
            return false;
        }
        return String(uri.dropFirst(4)) == cid;
    }
}

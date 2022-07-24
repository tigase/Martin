//
// Message.swift
//
// TigaseSwift
// Copyright (C) 2022 "Tigase, Inc." <office@tigase.com>
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

/// Extenstion of `Stanza` class with specific features existing only in `message' elements.
open class Message: Stanza, @unchecked Sendable {
    
    /// Message plain text
    open var body:String? {
        get {
            return getElementValue(name: "body");
        }
        set {
            setElementValue(name: "body", value: newValue);
        }
    }
    
    /// Message subject
    open var subject:String? {
        get {
            return getElementValue(name: "subject");
        }
        set {
            setElementValue(name: "subject", value: newValue);
        }
    }
    
    /// Message thread id
    open var thread:String? {
        get {
            return getElementValue(name: "thread");
        }
        set {
            setElementValue(name: "thread", value: newValue);
        }
    }
    
    /// Message OOB url
    open var oob: String? {
        get {
            return firstChild(name: "x", xmlns: "jabber:x:oob")?.firstChild(name: "url")?.value;
        }
        set {
            element.removeChildren(name: "x", xmlns: "jabber:x:oob");
            if newValue != nil {
                let x = Element(name: "x", xmlns: "jabber:x:oob");
                x.addChild(Element(name: "url", cdata: newValue))
                element.addChild(x);
            }
        }
    }
    
    open override var debugDescription: String {
        return String("Message : \(element)")
    }
    
    public init(xmlns: String? = nil, type: StanzaType? = nil, id: String? = nil, to toJid: JID? = nil) {
        super.init(name: "message", xmlns: xmlns, type: type, id: id, to: toJid);
    }
    
    public override init(element: Element) {
        super.init(element: element);
    }
    
}

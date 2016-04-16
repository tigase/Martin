//
// Stanza.swift
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

public class Stanza {
    
    public let element:Element;
    
    public var name:String {
        get {
            return element.name;
        }
    }
    
    public var from:JID? {
        get {
            if let jidStr = element.getAttribute("from") {
                return JID(jidStr);
            }
            return nil;
        }
        set {
            element.setAttribute("from", value: newValue?.stringValue);
        }
    }
    
    public var to:JID? {
        get {
            if let jidStr = element.getAttribute("to") {
                return JID(jidStr);
            }
            return nil;
        }
        set {
            element.setAttribute("to", value:newValue?.stringValue);
        }
    }
    
    public var id:String? {
        get {
            return element.getAttribute("id");
        }
        set {
            element.setAttribute("id", value: newValue);
        }
    }
    
    public var type:StanzaType? {
        get {
            if let type = element.getAttribute("type") {
                return StanzaType(rawValue: type);
            }
            return nil;
        }
        set {
            element.setAttribute("type", value: newValue?.rawValue);
        }
    }
    
    init(name:String) {
        self.element = Element(name: name);
    }
    
    init(elem:Element) {
        self.element = elem;
    }
    
    public static func fromElement(elem:Element) -> Stanza {
        switch elem.name {
        case "message":
            return Message(elem:elem);
        case "presence":
            return Presence(elem:elem);
        case "iq":
            return Iq(elem:elem);
        default:
            return Stanza(elem:elem);
        }
    }
}

public class Message: Stanza {
    
    public init() {
        super.init(name: "message");
    }
    
    public override init(elem: Element) {
        super.init(elem: elem);
    }

}

public class Presence: Stanza {
    
    public init() {
        super.init(name: "presence");
    }
    
    public override init(elem: Element) {
        super.init(elem: elem);
    }

}

public class Iq: Stanza {

    public init() {
        super.init(name: "iq");
    }
    
    public override init(elem: Element) {
        super.init(elem: elem);
    }
    
}
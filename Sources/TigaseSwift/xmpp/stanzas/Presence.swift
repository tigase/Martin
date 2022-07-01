//
// Presence.swift
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

/// Extenstion of `Stanza` class with specific features existing only in `presence' elements.
open class Presence: Stanza {

    /**
     Possible values:
     - chat: sender of stanza is ready to chat
     - online: sender of stanza is online
     - away: sender of stanza is away
     - xa: sender of stanza is away for longer time (eXtender Away)
     - dnd: sender of stanza wishes not to be disturbed
     */
    public enum Show: String {
        case chat
        case online
        case away
        case xa
        case dnd
        
        public var weight:Int {
            switch self {
            case .chat:
                return 5;
            case .online:
                return 4;
            case .away:
                return 3;
            case .xa:
                return 2;
            case .dnd:
                return 1;
            }
        }
    }
    
    open override var debugDescription: String {
        return String("Presence : \(element)")
    }

    /// Suggested nickname to use
    open var nickname:String? {
        get {
            return getElementValue(name: "nick", xmlns: "http://jabber.org/protocol/nick");
        }
        set {
            setElementValue(name: "nick", xmlns: "http://jabber.org/protocol/nick", value: newValue);
        }
    }
    
    /// Priority of presence and resource connection
    open var priority:Int! {
        get {
            let x = firstChild(name: "priority")?.value;
            if x != nil {
                return Int(x!) ?? 0;
            }
            return 0;
        }
        set {
            element.removeChildren(name: "priority");
            if newValue != nil {
                element.addChild(Element(name: "priority", cdata: newValue!.description));
            }
        }
    }
    
    /**
     Show value of this presence:
     - if available then is value from `Show` enum
     - if unavailable then is nil
     */
    open var show:Show? {
        get {
            let x = firstChild(name: "show")?.value;
            let type = self.type;
            guard type != StanzaType.error && type != StanzaType.unavailable else {
                return nil;
            }
            
            if (x == nil) {
                if (type == nil || type == StanzaType.available) {
                    return .online;
                }
                return nil;
            }
            return Show(rawValue: x!);
        }
        set {
            element.removeChildren(name: "show");
            if newValue != nil && newValue != Show.online {
                element.addChild(Element(name: "show", cdata: newValue!.rawValue));
            }
        }
    }
    
    /// Text with additional description - mainly for human use
    open var status:String? {
        get {
            return firstChild(name: "status")?.value;
        }
        set {
            element.removeChildren(name: "status");
            if newValue != nil {
                element.addChild(Element(name: "status", cdata: newValue!));
            }
        }
    }
    
    public init(xmlns: String? = nil, type: StanzaType? = nil, id: String? = nil, to toJid: JID? = nil) {
        super.init(name: "presence", xmlns: xmlns, type: type, id: id, to: toJid);
    }
    
    public override init(element: Element) {
        super.init(element: element);
    }

}

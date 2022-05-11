//
// Bookmarks.swift
//
// TigaseSwift
// Copyright (C) 2019 "Tigase, Inc." <office@tigase.com>
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

open class Bookmarks {
    
    open var items: [Item];
    
    public init?(from el: Element?) {
        guard el?.name == "storage" && el?.xmlns == "storage:bookmarks" else {
            return nil;
        }
        
        self.items = el!.mapChildren(transform: { child -> Item? in
            switch child.name {
            case "url":
                return Url(from: child);
            case "conference":
                return Conference(from: child);
            default:
                return nil;
            }
        });
    }
    
    public init(items: [Item] = []) {
        self.items = items;
    }
    
    open func updateOrAdd(bookmark: Item) -> Bookmarks? {
        if let idx = items.firstIndex(where: { (item) -> Bool in
            guard item.type == bookmark.type else {
                return false;
            }
            switch item.type {
            case .url:
                return (item as? Url)?.url == (bookmark as? Url)?.url;
            case .conference:
                return (item as? Conference)?.jid == (bookmark as? Conference)?.jid;
            }
        }) {
            items[idx] = bookmark;
        } else {
            items.append(bookmark);
        }
        return self;
    }
    
    open func remove(bookmark: Item) -> Bookmarks? {
        if let idx = items.firstIndex(where: { (item) -> Bool in
            guard item.type == bookmark.type else {
                return false;
            }
            switch item.type {
            case .url:
                return (item as? Url)?.url == (bookmark as? Url)?.url;
            case .conference:
                return (item as? Conference)?.jid == (bookmark as? Conference)?.jid;
            }
        }) {
            items.remove(at: idx);
            return self;
        } else {
            return nil;
        }
    }
    
    open func conference(for jid: JID) -> Conference? {
        return items.compactMap({ $0 as? Conference }).first(where: { $0.jid == jid});
    }
    
    open func toElement() -> Element {
        let el = Element(name: "storage", xmlns: "storage:bookmarks");
        el.addChildren(items.map({ item in item.toElement()}));
        return el;
    }
    
    open class Item {
        public let name: String?;
        public let type: ItemType;
        
        public init(type: ItemType, name: String?) {
            self.type = type;
            self.name = name;
        }
        
        open func toElement() -> Element {
            let el = Element(name: type.rawValue);
            if name != nil {
                el.setAttribute("name", value: name);
            }
            return el;
        }
    }
    
    open class Conference: Item {
        public let jid: JID;
        public let autojoin: Bool;
        public let nick: String?;
        public let password: String?;
        
        convenience public init?(from el: Element?) {
            guard el?.name == "conference", let jid = JID(el?.getAttribute("jid")) else {
                return nil;
            }
            
            let joinStr = el?.getAttribute("autojoin") ?? "false";

            self.init(name: el?.getAttribute("name"), jid: jid, autojoin: joinStr == "true" || joinStr == "1", nick: el?.getAttribute("nick") ?? el?.findChild(name: "nick")?.value, password: el?.getAttribute("password"));
        }
        
        public init(name: String?, jid: JID, autojoin: Bool, nick: String? = nil, password: String? = nil) {
            self.jid = jid;
            self.autojoin = autojoin;
            self.nick = nick;
            self.password = password;
            super.init(type: .conference, name: name);
        }
        
        open override func toElement() -> Element {
            let el = super.toElement();
            el.setAttribute("jid", value: jid.stringValue);
            if autojoin {
                el.setAttribute("autojoin", value: "true");
            }
            if let nick = self.nick {
                el.addChild(Element(name: "nick", cdata: nick));
            }
            el.setAttribute("password", value: password);
            return el;
        }
        
        open func with(autojoin: Bool) -> Bookmarks.Conference {
            return Bookmarks.Conference(name: name, jid: jid, autojoin: autojoin, nick: nick, password: password);
        }
        
        open func with(password: String?) -> Bookmarks.Conference {
            return Bookmarks.Conference(name: name, jid: jid, autojoin: autojoin, nick: nick, password: password);
        }
    }
    
    public class Url: Item {
        public let url: String;
        
        convenience public init?(from el: Element?) {
            guard el?.name == "url", let url = el?.getAttribute("url") else {
                return nil;
            }
            self.init(name: el?.getAttribute("name"), url: url);
        }
        
        public init(name: String?, url: String) {
            self.url = url;
            super.init(type: .url, name: name);
        }
        
        open override func toElement() -> Element {
            let el = super.toElement();
            el.setAttribute("url", value: url);
            return el;
        }
    }
    
    public enum ItemType: String {
        case url = "url";
        case conference = "conference";
    }
}

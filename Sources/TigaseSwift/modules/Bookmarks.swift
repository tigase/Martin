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

public protocol BookmarksItem: CustomElementConvertible, Sendable {

    var id: String { get }
    var name: String? { get }
    
}

open class Bookmarks {
    
    open var items: [BookmarksItem];
    
    public init?(from elem: Element?) {
        guard let el = elem, el.name == "storage" && el.xmlns == "storage:bookmarks" else {
            return nil;
        }
        
        self.items = el.children.compactMap({ child -> BookmarksItem? in
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
    
    public init(items: [BookmarksItem] = []) {
        self.items = items;
    }
    
    open func updateOrAdd(bookmark: BookmarksItem) -> Bookmarks? {
        if let idx =  items.firstIndex(where: { bookmark.id == $0.id }) {
            items[idx] = bookmark;
        } else {
            items.append(bookmark);
        }
        return self;
    }
    
    open func remove(bookmark: BookmarksItem) -> Bookmarks? {
        if let idx = items.firstIndex(where: { bookmark.id == $0.id }) {
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
        el.addChildren(items.map({ item in item.element()}));
        return el;
    }
    
    public struct Conference: BookmarksItem, Sendable {
        public var id: String {
            return jid.description
        }
        public let name: String?;
        public let jid: JID;
        public let autojoin: Bool;
        public let nick: String?;
        public let password: String?;
        
        public init?(from el: Element?) {
            guard el?.name == "conference", let jid = JID(el?.attribute("jid")) else {
                return nil;
            }
            
            let joinStr = el?.attribute("autojoin") ?? "false";

            self.init(name: el?.attribute("name"), jid: jid, autojoin: joinStr == "true" || joinStr == "1", nick: el?.attribute("nick") ?? el?.firstChild(name: "nick")?.value, password: el?.attribute("password"));
        }
        
        public init(name: String?, jid: JID, autojoin: Bool, nick: String? = nil, password: String? = nil) {
            self.name = name;
            self.jid = jid;
            self.autojoin = autojoin;
            self.nick = nick;
            self.password = password;
        }
        
        public func element() -> Element {
            return Element(name: "conference", {
                Attribute("name", value: name)
                Attribute("jid", value: jid.description)
                Attribute("password", value: password)
                if autojoin {
                    Attribute("autojoin", value: "true")
                }
                if let nick = self.nick {
                    Element(name: "nick", cdata: nick);
                }
            })
        }
        
        public func with(autojoin: Bool) -> Bookmarks.Conference {
            return Bookmarks.Conference(name: name, jid: jid, autojoin: autojoin, nick: nick, password: password);
        }
        
        public func with(password: String?) -> Bookmarks.Conference {
            return Bookmarks.Conference(name: name, jid: jid, autojoin: autojoin, nick: nick, password: password);
        }
    }
    
    public struct Url: BookmarksItem, Sendable {
        public var id: String {
            return url;
        }
        public let name: String?;
        public let url: String;
        
        public init?(from el: Element?) {
            guard el?.name == "url", let url = el?.attribute("url") else {
                return nil;
            }
            self.init(name: el?.attribute("name"), url: url);
        }
        
        public init(name: String?, url: String) {
            self.url = url;
            self.name = name;
        }
        
        public func element() -> Element {
            return Element(name: "url", {
                Attribute("name", value: name)
                Attribute("url", value: url);
            })
        }
    }
    
    public enum ItemType: String {
        case url = "url";
        case conference = "conference";
    }
}

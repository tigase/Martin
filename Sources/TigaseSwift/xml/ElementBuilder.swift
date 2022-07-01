//
// ElementBuilder.swift
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

public protocol ElementItemProtocol {

    func asItems() -> [ElementItemProtocol];
    
}

extension Element: ElementItemProtocol {
    
    public func asItems() -> [ElementItemProtocol] {
        return [self]
    }
    
}

extension Array: ElementItemProtocol where Element == TigaseSwift.ElementItemProtocol {
    
    public func asItems() -> [ElementItemProtocol] {
        return self;
    }
    
}

public struct Attribute: ElementItemProtocol {
    public let name: String;
    public let value: String;
    
    public init(_ name: String, value: String) {
        self.name = name;
        self.value = value;
    }
    
    public init?(_ name: String, value: String?) {
        guard let value = value else {
            return nil;
        }
        self.init(name, value: value);
    }
    
    public func asItems() -> [ElementItemProtocol] {
        return [self];
    }
}

@resultBuilder
public struct ElementBuilder {
    public static func buildBlock() -> [ElementItemProtocol] { [] }
}

extension ElementBuilder {
    public static func buildBlock(_ components: ElementItemProtocol...) -> [ElementItemProtocol] {
        return components.flatMap({ $0.asItems() })
    }
}

extension ElementBuilder {
        
    public static func buildEither(first component: ElementItemProtocol) -> ElementItemProtocol {
        return component;
    }
    
    public static func buildEither(second component: ElementItemProtocol) -> ElementItemProtocol {
        return component;
    }
    
    public static func buildOptional(_ component: [ElementItemProtocol]?) -> [ElementItemProtocol] {
        return component ?? [];
    }
    
    public static func buildArray(_ components: [[ElementItemProtocol]]) -> [ElementItemProtocol] {
        return components.flatMap({ $0 })
    }
    
    public static func buildExpression(_ expression: Attribute?) -> [ElementItemProtocol] {
        if expression != nil {
            return [expression!]
        } else {
            return []
        }
    }

    public static func buildExpression(_ expression: Element?) -> [ElementItemProtocol] {
        if expression != nil {
            return [expression!]
        } else {
            return []
        }
    }

}


extension Element {
    
    public convenience init(name: String, xmlns: String? = nil, @ElementBuilder _ builder: ()->[ElementItemProtocol]) {
        self.init(name: name, xmlns: xmlns);
        let items = builder();
        for attr in items.compactMap({ $0 as? Attribute }) {
            attribute(attr.name, newValue: attr.value);
        }
        addChildren(items.compactMap({ $0 as? Element }))
    }
    
}

extension Stanza {
    
    public convenience init(name: String, xmlns: String? = nil, type: StanzaType? = nil, id: String? = nil, to toJid: JID? = nil, @ElementBuilder _ builder: ()->[ElementItemProtocol]) {
        self.init(name: name, xmlns: xmlns, type: type, id: id, to: toJid);
        let items = builder();
        for attr in items.compactMap({ $0 as? Attribute }) {
            attribute(attr.name, newValue: attr.value);
        }
        addChildren(items.compactMap({ $0 as? Element }))
    }
    
}

extension Message {
    public convenience init(xmlns: String? = nil, type: StanzaType? = nil, id: String? = nil, to toJid: JID? = nil, @ElementBuilder _ builder: ()->[ElementItemProtocol]) {
        self.init(xmlns: xmlns, type: type, id: id, to: toJid);
        let items = builder();
        for attr in items.compactMap({ $0 as? Attribute }) {
            attribute(attr.name, newValue: attr.value);
        }
        addChildren(items.compactMap({ $0 as? Element }))
    }
}

extension Presence {
    public convenience init(xmlns: String? = nil, type: StanzaType? = nil, id: String? = nil, to toJid: JID? = nil, @ElementBuilder _ builder: ()->[ElementItemProtocol]) {
        self.init(xmlns: xmlns, type: type, id: id, to: toJid);
        let items = builder();
        for attr in items.compactMap({ $0 as? Attribute }) {
            attribute(attr.name, newValue: attr.value);
        }
        addChildren(items.compactMap({ $0 as? Element }))
    }
}


extension Iq {
    public convenience init(xmlns: String? = nil, type: StanzaType? = nil, id: String? = nil, to toJid: JID? = nil, @ElementBuilder _ builder: ()->[ElementItemProtocol]) {
        self.init(xmlns: xmlns, type: type, id: id, to: toJid);
        let items = builder();
        for attr in items.compactMap({ $0 as? Attribute }) {
            attribute(attr.name, newValue: attr.value);
        }
        addChildren(items.compactMap({ $0 as? Element }))
    }
}

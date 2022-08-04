//
// ElementsBuilder.swift
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

public protocol ElementGroup {
    func asElements() -> [Element]
}

extension Element: ElementGroup {
    
    public func asElements() -> [Element] {
        return [self];
    }
    
}

extension Array: ElementGroup where Element == Martin.Element {
    public func asElements() -> [Element] {
        return self;
    }
    
}

@resultBuilder
public struct ElementsBuilder {
    public static func buildBlock() -> [Element] { [] }
}

public func makeElements(@ElementsBuilder _ content: () -> [Element]) -> [Element] {
    content();
}

extension ElementsBuilder {
    public static func buildBlock(_ components: ElementGroup...) -> [Element] {
        return components.flatMap({ $0.asElements() })
    }
}

extension ElementsBuilder {
        
    public static func buildEither(first component: Element) -> Element {
        return component;
    }
    
    public static func buildEither(second component: Element) -> Element {
        return component;
    }
    
    public static func buildOptional(_ component: [Element]?) -> [Element] {
        return component ?? [];
    }
    
    public static func buildArray(_ components: [[Element]]) -> [Element] {
        return components.flatMap({ $0 })
    }
}

extension ElementProtocol {
    
    public func addChildren(@ElementsBuilder _ content: ()->[Element]) {
        addChildren(content());
    }
    
    public func addChild(name: String, xmlns: String?, _ body: (Element)->Void) {
        let elem = Element(name: name, xmlns: xmlns);
        body(elem);
        addChild(elem);
    }

}

extension Element {
    
    public convenience init(name: String, xmlns: String? = nil, body: (Element) -> Void) {
        self.init(name: name, xmlns: xmlns);
        body(self);
    }

    public func append(to elem: ElementProtocol) {
        elem.addChild(self);
    }
    
}

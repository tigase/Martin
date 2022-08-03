//
// Element.swift
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
import TigaseSwift
import XCTest

class ElementTests: XCTestCase {
    
    func testEquality() {
        let el1 = Element(name: "item", children: [Element(name: "name", cdata: "Swift")]);
        let el2 = Element(name: "item", children: [Element(name: "name", cdata: "Java")]);
        let el3 = Element(name: "item", children: [Element(name: "name", cdata: "Swift")]);
        XCTAssertFalse(el1 == el2, "Elements should not match!")
        XCTAssertTrue(el1 === el1, "Elements should match!");
        XCTAssertTrue(el1 == el3, "Elements should match!");
    }

    func testIndexOfChild() {
        let nameEl = Element(name: "name", cdata: "Swift");
        let el1 = Element(name: "item", children: [nameEl]);
        XCTAssertNil(el1.firstIndex(ofChild: Element(name: "name", cdata: "Swift")));
        XCTAssertNil(el1.firstIndex(ofChild: Element(name: "name", cdata: "Java")));
        XCTAssertEqual(0, el1.firstIndex(ofChild: nameEl));
    }
    
    func testRemoveChild() {
        let el1 = Element(name: "item", children: [Element(name: "name", cdata: "Swift")]);
        el1.removeChild(Element(name: "name", cdata: "Swift"));
        XCTAssertNotNil(el1.findChild(name: "name", xmlns: nil));
        let nameEl = el1.findChild(name: "name", xmlns: nil)!;
        el1.removeChild(nameEl);
        XCTAssertNil(el1.firstIndex(ofChild: nameEl));
        XCTAssertNil(el1.findChild(name: "name", xmlns: nil));
    }
}

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
import Martin
import XCTest

class ElementTests: XCTestCase {

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
        XCTAssertNotNil(el1.firstChild(name: "name", xmlns: nil));
        let nameEl = el1.firstChild(name: "name", xmlns: nil)!;
        el1.removeChild(nameEl);
        XCTAssertNil(el1.firstChild(name: "name", xmlns: nil));
    }
    
    func testElementBuilders() {
        let settings = MessageArchiveManagementModule.Settings(defaultValue: .always, always: [JID("test-1@localhost"), JID("test-2@localhost")], never: [JID("test-3@localhost"),JID("test-4@localhost")]);
        
        let iq = Iq(type: .set, {
            Element(name: "prefs", xmlns: MessageArchiveManagementModule.MAM2_XMLNS, {
                Attribute("default", value: settings.defaultValue.rawValue)
                if !settings.always.isEmpty {
                    Element(name: "always", {
                        for jid in settings.always {
                            Element(name: "jid", cdata: jid.description)
                        }
                    })
                }
                if !settings.never.isEmpty {
                    Element(name: "never", {
                        for jid in settings.never {
                            Element(name: "jid", cdata: jid.description)
                        }
                    })
                }
            })
        });
        iq.addChildren({
            Element(name: "test")
        })
        
        let prefsEl = iq.firstChild(name: "prefs");
        XCTAssertNotNil(prefsEl);
        XCTAssertEqual("always", prefsEl?.attribute("default"))
        let always = prefsEl?.firstChild(name: "always");
        XCTAssertNotNil(always);
        XCTAssertEqual(["test-1@localhost", "test-2@localhost"], always?.filterChildren(name: "jid").map({ $0.value }))
        let never = prefsEl?.firstChild(name: "never");
        XCTAssertNotNil(never);
        XCTAssertEqual(["test-3@localhost", "test-4@localhost"], never?.filterChildren(name: "jid").map({ $0.value }))
        XCTAssertNotNil(iq.firstChild(name: "test"))
    }
}

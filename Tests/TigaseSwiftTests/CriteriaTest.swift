//
// CriteriaTest.swift
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
import TigaseSwift
import XCTest

class CriteriaTest: XCTestCase {

    func test1() {
        let good = Element(name: "message", attributes: ["type": "chat"]);
        let bad = Element(name: "message", attributes: ["type": "groupchat"]);

        let criteria = Criteria.name("message", types:[StanzaType.chat, StanzaType.normal, nil, StanzaType.headline, StanzaType.error]);
        print(criteria);
        XCTAssertTrue(criteria.match(good));
        XCTAssertFalse(criteria.match(bad));
    }

}

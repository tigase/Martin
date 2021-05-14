//
// BareJIDTests.swift
//
// TigaseSwift
// Copyright (C) 2021 "Tigase, Inc." <office@tigase.com>
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

class BareJIDTests: XCTestCase {
    
    func testEmptyStringToBareJID() {
        let jid = BareJID("test@");
        XCTAssert(jid != nil);
    }
    
    func testMultilineStringToBareJID() {
        let v = "\n/@tigase.org\n".split(separator: "\n");
        let result = v.map({ s in String(s) }).map({ s in JID(s) });
        print(result);
        XCTAssert(!result.isEmpty)
    }
    
    func testWeirdInputToBareJID() {
        let v = """
[2021-02-18 17:20:25] <Optional("Test #")>: error: nil response: Optional(<NSHTTPURLResponse: 0x105a36900> { URL: https://test.example:443/upload/5b2a1f5e-90f4-4135-8f96-e295e7360538/44.png } { Status Code: 500, Headers {
    } })
""".split(separator: "\n");
        let result = v.map({ s in String(s) }).map({ s in JID(s) });
        print(result);
        XCTAssert(!result.isEmpty)
    }
}

//
// PubSubErrorTests.swift
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

class PubSubErrorTests: XCTestCase {
    
    func testConflict() {
        let el = Element(name: "iq", attributes: ["type": "error", "xmlns": "jabber:client"]);
        let itemsEl = Element(name: "items", attributes: ["node": "test-node"]);
        itemsEl.addChild(Element(name: "item", attributes: ["id": "current"]));
        let pubsubEl = Element(name: "pubsub", xmlns: "http://jabber.org/protocol/pubsub", children: [itemsEl]);
        let errorEl = Element(name: "error", children: [Element(name: "item-not-found", xmlns: "urn:ietf:params:xml:ns:xmpp-stanzas")]);
        errorEl.setAttribute("code", value: "409")
        errorEl.setAttribute("type", value: "cancel")
        el.addChildren([pubsubEl, errorEl]);
        let stanza = Stanza.from(element: el);
        let error = stanza.error;
        XCTAssertNotNil(error);
        XCTAssertEqual(XMPPError.item_not_found, error);
        let pubsubError = PubSubError.from(stanza: stanza);
        XCTAssertNotNil(pubsubError);
        XCTAssertEqual(XMPPError.item_not_found, pubsubError.error);
    }

}

//
// DataFormTests.swift
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
import AVFoundation

class DataFormTests: XCTestCase {
    
    func testDataForm() {
        let config = PubSubNodeConfig();
        config.title = "Some title";
        config.accessModel = .presence;
        config.rosterGroupsAllowed = ["test", "dupa"]
        config.sendLastPublishedItem = .on_sub_and_presence
        config.deliverPayloads = true
        XCTAssertEqual("Some title", config.title);
        XCTAssertEqual(PubSubNodeConfig.AccessModel.presence, config.accessModel);
        print(config.element(type: .submit, onlyModified: false));
        
        let mixConfig = MixChannelConfig();
        mixConfig.lastChangeMadeBy = JID("test@zeus")
        mixConfig.messagesNodeSubscription = .participants;
        mixConfig.allowedNodeSubscription = .participants;
        mixConfig.nodeUpdateRights = .admins;
        mixConfig.openPresence = false;
        print(mixConfig.element(type: .submit, onlyModified: false));
        
        let mixInfo = MixChannelInfo();
        print(mixInfo.element(type: .submit, onlyModified: false));
    }
    
    static var allTests = [
        ("testDataForm", testDataForm),
    ]
}

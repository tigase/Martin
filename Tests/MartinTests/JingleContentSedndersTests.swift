//
// JingleContentSendersTest.swift
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
import Martin
import XCTest
import AVFoundation

class JingleContentSendersTests: XCTestCase {
    
    func testStreamTypeToSendersAndBack1() {
        let inStreamType: SDP.StreamType = .sendonly;
        
        let senders = inStreamType.senders(localRole: .initiator);
        XCTAssertTrue(senders == .initiator);
        
        let outStreamType1 = senders.streamType(localRole: .initiator, direction: .outgoing);
        XCTAssertTrue(outStreamType1 == .sendonly);

        let outStreamType2 = senders.streamType(localRole: .responder, direction: .incoming);
        XCTAssertTrue(outStreamType2 == .sendonly);
    }
 
    func testStreamTypeToSendersAndBack2() {
        let inStreamType: SDP.StreamType = .recvonly;
        
        let senders = inStreamType.senders(localRole: .initiator);
        XCTAssertTrue(senders == .responder);
        
        let outStreamType1 = senders.streamType(localRole: .initiator, direction: .outgoing);
        XCTAssertTrue(outStreamType1 == .recvonly);

        let outStreamType2 = senders.streamType(localRole: .responder, direction: .incoming);
        XCTAssertTrue(outStreamType2 == .recvonly);
    }

    func testStreamTypeToSendersAndBack3() {
        let inStreamType: SDP.StreamType = .sendonly;
        
        let senders = inStreamType.senders(localRole: .responder);
        XCTAssertTrue(senders == .responder);
        
        let outStreamType1 = senders.streamType(localRole: .responder, direction: .outgoing);
        XCTAssertTrue(outStreamType1 == .sendonly);

        let outStreamType2 = senders.streamType(localRole: .initiator, direction: .incoming);
        XCTAssertTrue(outStreamType2 == .sendonly);
    }
 
    func testStreamTypeToSendersAndBack4() {
        let inStreamType: SDP.StreamType = .recvonly;
        
        let senders = inStreamType.senders(localRole: .responder);
        XCTAssertTrue(senders == .initiator);
        
        let outStreamType1 = senders.streamType(localRole: .responder, direction: .outgoing);
        XCTAssertTrue(outStreamType1 == .recvonly);

        let outStreamType2 = senders.streamType(localRole: .initiator, direction: .incoming);
        XCTAssertTrue(outStreamType2 == .recvonly);
    }
    
}

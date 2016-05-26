//
// XMPPDelegate.swift
//
// TigaseSwift
// Copyright (C) 2016 "Tigase, Inc." <office@tigase.com>
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

public class XMPPDelegate : NSObject, XMPPStreamDelegate {
    
    public func onError(msg: String?) {
        log("error parsing XML", msg);
    }
    
    public func onStreamTerminate() {
        log("stream closed")
    }
    
    public func onStreamStart(attributes: [String : String]) {
        log("stream started: \(attributes)")
    }
    
    public func processElement(packet: Element) {
        log("got packet:  " + packet.stringValue)
    }
    
}
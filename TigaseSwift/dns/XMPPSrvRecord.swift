//
// XMPPSrvRecord.swift
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

/**
 Class holds informations for single SRV record of DNS entries
 */
open class XMPPSrvRecord: Codable {
    
    let port:Int;
    let weight:Int;
    let priority:Int;
    let target:String;
    let directTls: Bool;

    open var description: String {
        return "[port: \(String(describing: port)), weight: \(weight), priority: \(String(describing: priority)), target: \(target), directTls: \(directTls)]";
    }
    
    init(port:Int, weight:Int, priority:Int, target:String, directTls: Bool) {
        self.port = port;
        self.weight = weight;
        self.priority = priority;
        self.target = target;
        self.directTls = directTls;
    }
    
}

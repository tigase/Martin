//
// Occupant.swift
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

public class Occupant {
    
    private static var counter = 0;
    
    private var id = ++counter;
    
    private var affiliation_: Affiliation = .none;
    private var role_: Role = .none;
    private var jid_: JID? = nil;
    
    public var affiliation: Affiliation {
        return affiliation_;
    }
    
    public var nickname: String? {
        return presence?.from?.resource;
    }
    
    public var role: Role {
        return role_;
    }
    
    public var jid: JID? {
        return jid_;
    }
    
    public var presence: Presence? {
        didSet {
            if let xUser = XMucUserElement.extract(presence) {
                affiliation_ = xUser.affiliation;
                role_ = xUser.role;
                jid_ = xUser.jid;
            } else {
                affiliation_ = .none;
                role_ = .none;
                jid_ = nil;
            }
        }
    }
    
    public init() {
        
    }
    
    
    
}
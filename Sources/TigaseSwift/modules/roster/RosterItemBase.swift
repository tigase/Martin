//
// RosterItemBase.swift
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

/**
 Class holds informations about single roster entry
 */
open class RosterItemBase: RosterItemProtocol, CustomStringConvertible {

    public let jid: JID;
    public let name: String?;
    public let subscription: RosterItemSubscription;
    public let ask: Bool;
    public let groups: [String];
    public let annotations: [RosterItemAnnotation];
    
    open var description: String {
        get {
            return "RosterItem{ jid=\(jid), name=\(String(describing: name)), subscription=\(subscription), groups=\(groups)}"
        }
    }
    
    public init(jid:JID, name: String?, subscription: RosterItemSubscription, groups: [String] = [String](), ask: Bool = false, annotations: [RosterItemAnnotation]) {
        self.jid = jid;
        if name?.trimmingCharacters(in: .whitespaces).isEmpty ?? true {
            self.name = nil;
        } else {
            self.name = name;
        }
        self.subscription = subscription;
        self.groups = groups;
        self.ask = ask;
        self.annotations = annotations;
    }
    
}

public protocol RosterItemProtocol: class {
    var jid: JID { get };
    var name: String? { get }
    var subscription: RosterItemSubscription { get }
    var ask: Bool { get };
    var groups: [String] { get }
    var annotations: [RosterItemAnnotation] { get }

}

public struct RosterItemAnnotation: Codable {
    var type: String;
    var values: [String:String];
}

//
// PubSubSubscription.swift
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

/// Represents subscription item
open class PubSubSubscriptionElement {
    /// instance of received element
    let element: Element;
    
    /// Subscriber JID
    var jid: JID? {
        return JID(element.getAttribute("jid"));
    }
    
    /// Subscription state
    var subscription: PubSubSubscription {
        get {
            guard let state = element.getAttribute("subscription") else {
                return .none;
            }
            return PubSubSubscription(rawValue: state)!;
        }
        set {
            element.setAttribute("subscription", value: newValue.rawValue);
        }
    }
    
    /// Subscription id
    var subId: String? {
        return element.getAttribute("subid");
    }
    
    /**
     Creates subscription item from element
     - parameter from: element to create subscription from
     */
    public init?(from: Element) {
        guard from.name == "subscription" else {
            return nil;
        }
        
        self.element = from;
    }
    
    /**
     Creates instance of subscription item for manipulation
     - parameter jid: subscriber jid
     */
    public convenience init(jid: JID) {
        let elem = Element(name: "subscription");
        elem.setAttribute("jid", value: jid.stringValue);
        self.init(from: elem)!;
    }
    
}

/// Enum contains possible subscription states
public enum PubSubSubscription: String {
    case none
    case pending
    case subscribed
    case unconfigured
}

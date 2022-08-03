//
// Event.swift
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
 Event protocol needs to be implemented by every event fired using `EventBus`
 */
@available(*, deprecated)
public protocol Event: class {
    
    /// Unique identifier of event class
    var type:String { get }
    
}

@available(*, deprecated)
open class AbstractEvent: Event {
    
    /// Identifier of event while looking for`EventHandler`
    public let type: String;
    /// Context of the sender
    public let context: Context!;
    /// Access to SessionObject of the context (for compatibility)
    public var sessionObject: SessionObject {
        return context.sessionObject;
    }
    
    /// Use only for creation of TYPE parameters!
    public init(type: String) {
        self.type = type;
        self.context = nil;
    }
    
    public init(type: String, context: Context) {
        self.type = type;
        self.context = context;
    }

}

/**
 Protocol to mark events for which handlers must be called only one at the time
 */
@available(*, deprecated)
public protocol SerialEvent {
    
}

public func ==(lhs:Event, rhs:Event) -> Bool {
    return lhs === rhs || lhs.type == rhs.type;
}

public func ==(lhs:[Event], rhs:[Event]) -> Bool {
    guard lhs.count == rhs.count else {
        return false;
    }
    
    for le in lhs {
        if rhs.contains(where: {(re) -> Bool in
            return le == re;
        }) {
            // this is ok
        } else {
            return false;
        }
    }
    return true;
}

//
// Atomic.swift
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

@propertyWrapper
public class Atomic<Value> {
    
    private let queue = DispatchQueue(label: "tigase.swift.atomic");
    private var value: Value;
    
    public init(wrappedValue: Value) {
        self.value = wrappedValue;
    }
    
    public var wrappedValue: Value {
        get {
            return queue.sync(execute: { value });
        }
        set {
            queue.sync(execute: { value = newValue })
        }
    }
    
    public var projectedValue: Atomic<Value> {
        return self;
    }
    
    public func mutate(_ mutation: (inout Value) -> Void) {
        queue.sync {
            mutation(&self.value);
        }
    }
}

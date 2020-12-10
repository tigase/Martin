//
// Published.swift
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
public struct Published<Value> {
    
    public class Publisher: AbstractPublisher<Value,Never> {
        
        public typealias Output = Value
        public typealias Failure = Never
    
        fileprivate var value: Output;
        
        fileprivate init(_ value: Value) {
            self.value = value;
        }
        
    }

    public var projectedValue: Publisher {
        mutating get {
            return storage;
        }
        set {
            storage = newValue;
        }
    }
    
    
    public var wrappedValue: Value {
        get {
            return storage.queue.sync {
                return storage.value
            };
        }
        nonmutating set {
            storage.offer(newValue);
            storage.queue.sync {
                storage.value = newValue;
            }
        }
    }
    
    private var storage: Publisher;
    
    public init(wrappedValue: Value) {
        storage = Publisher(wrappedValue);
    }
    
}

typealias TigaseCustomPublisher = Publisher


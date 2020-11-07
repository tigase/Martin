//
// Subscriber.swift
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

public protocol Subscription: Cancellable {
    
}

public protocol Subscriber {
    
    associatedtype Input
    associatedtype Failure: Error
    
    func receive(subscription: Subscription) -> Void;
    
    func receive(_ input: Self.Input) -> Subscribers.Demand;
    
    func receive(completion: Subscribers.Completion<Self.Failure>);
    
}

public struct Subscribers {
    
    public enum Completion<Failure> where Failure : Error {
        case finished
        case failure(Failure)
    }
    
    public struct Demand {
        
        public static let none = Subscribers.Demand();
        public static let unlimited = Subscribers.Demand();
        
    }
    
}

public protocol Cancellable {
    func cancel();
}

enum SubscriptionStatus {
    case unsubscribed
    case subscribed(Subscription)
}

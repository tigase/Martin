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
    
    public class Publisher: TigaseCustomPublisher {
        
        public typealias Output = Value
        public typealias Failure = Never
    
        private let queue = DispatchQueue(label: "Published.Publisher.Queue");
        
        fileprivate var value: Output {
            didSet {
                offer(value);
            }
        }
        
        private var subscribers = SubscribersList<Output,Failure>.empty;
        
        deinit {
            let subscribers = queue.sync { self.subscribers };
            subscribers.forEach {
                $0.cancel();
            }
        }
        
        func offer(_ output: Output) {
            let subscribers = queue.sync { self.subscribers };
            subscribers.forEach  { $0.offer(output) };
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            let item = SubscriberRegistration(parent: self, subscriber: subscriber);
            queue.sync {
                subscribers.insert(item);
            }
            subscriber.receive(subscription: item);
        }
        
        fileprivate func release(_ subscription: SubscribersListItem<Output, Failure>) {
            queue.sync {
                subscribers.remove(subscription)
            }
            subscription.cancel();
        }
        
        fileprivate init(_ output: Output) {
            value = output;
        }
        
        private class SubscriberRegistration<S: Subscriber>: SubscribersListItem<Output, Failure>, Subscription where S.Input == Output, S.Failure == Never {
            
            private var subscriber: S?;
            private weak var parent: Publisher?;

            init(parent: Publisher, subscriber: S) {
                self.parent = parent;
                self.subscriber = subscriber;
            }

            public override func offer(_ output: Output) {
                subscriber?.receive(output);
            }

            public override func cancel() {
                let oldSubscriber = subscriber;
                subscriber = nil;
                guard let parent = self.parent else {
                    return;
                }
                self.parent = nil;
                parent.release(self);
            }
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
            return storage.value;
        }
        set {
            storage.value = newValue;
        }
    }
    
    private var storage: Publisher;
    
    public init(wrappedValue: Value) {
        storage = Publisher(wrappedValue);
    }
    
}

typealias TigaseCustomPublisher = Publisher

private class SubscribersListItem<Output, Failure: Error> {
    
    func offer(_ output: Output) {
        
    }
 
    func cancel() {
        
    }
    
}

private enum SubscribersList<Output,Failure: Error> {
    case empty
    case many([SubscribersListItem<Output,Failure>])
    
    mutating func insert(_ item: SubscribersListItem<Output,Failure>) {
        switch self {
        case .empty:
            self = .many([item]);
        case .many(let items):
            self = .many(items + [item]);
        }
    }
    
    mutating func remove(_ item: SubscribersListItem<Output,Failure>) {
        switch self {
        case .empty:
            break;
        case .many(let items):
            let newItems = items.filter({ $0 !== item });
            if newItems.isEmpty {
                self = .empty;
            } else {
                self = .many(newItems);
            }
        }
    }
    
    func forEach(_ body: (SubscribersListItem<Output,Failure>)->Void) {
        switch self {
        case .empty:
            break;
        case .many(let subscribers):
            for subscriber in subscribers {
                body(subscriber);
            }
        }
    }
    
}

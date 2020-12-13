//
// AbstractPublisher.swift
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

public class AbstractPublisher<Output,Failure: Error>: Publisher {
    
    private let lock = UnfairLock();
    private var subscribers = SubscribersList<Output,Failure>.empty;

    init() {}
    
    deinit {
        lock.lock();
        let subscribers = self.subscribers;
        lock.unlock();
        subscribers.forEach {
            $0.cancel();
        }
    }
    
    func offer(_ output: Output) {
        lock.lock();
        let subscribers = self.subscribers;
        lock.unlock();
        subscribers.forEach  { $0.offer(output) };
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        let item = SubscriberRegistration(parent: self, subscriber: subscriber);
        lock.lock();
        subscribers.insert(item);
        lock.unlock();
        subscriber.receive(subscription: item);
    }
    
    fileprivate func release(_ subscription: SubscribersListItem<Output, Failure>) {
        lock.lock();
        subscribers.remove(subscription)
        lock.unlock();
        subscription.cancel();
    }
        
    private class SubscriberRegistration<S: Subscriber>: SubscribersListItem<Output, Failure>, Subscription where S.Input == Output, S.Failure == Failure {
        
        private let lock = UnfairLock();
        private var subscriber: S?;
        private weak var parent: AbstractPublisher?;
        private var currentDelivered: Bool = false;

        init(parent: AbstractPublisher, subscriber: S) {
            self.parent = parent;
            self.subscriber = subscriber;
        }

        public func request(_: Subscribers.Demand) {
            lock.lock();
            guard !currentDelivered else {
                lock.unlock();
                return;
            }
            
            currentDelivered = true;
            if let value = (parent as? CurrentValueSubject)?.value {
                lock.unlock();
                subscriber?.receive(value);
            } else {
                lock.unlock();
            }
        }
        
        public override func offer(_ output: Output) {
            lock.lock();
            currentDelivered = true;
            lock.unlock();
            subscriber?.receive(output);
        }

        public override func cancel() {
            lock.lock();
            let oldSubscriber = subscriber;
            subscriber = nil;
            guard let parent = self.parent else {
                lock.unlock();
                return;
            }
            self.parent = nil;
            lock.unlock();
            parent.release(self);
        }
    }

}

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

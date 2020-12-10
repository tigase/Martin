//
// Subscribers+Sink.swift
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

extension Subscribers {
    
    public class Sink<Input, Failure: Error>: Subscriber {
    
        private let queue = DispatchQueue(label: "Subscribers.Sink.Queue");
        private let receiveCompletion: (Subscribers.Completion<Failure>)->Void;
        private let receiveValue: (Input)->Void;
        private var status: SubscriptionStatus = .unsubscribed;
        
        public init(receiveCompletion: @escaping ((Subscribers.Completion<Failure>)->Void), receiveValue: @escaping ((Input)->Void)) {
            self.receiveValue = receiveValue;
            self.receiveCompletion = receiveCompletion;
        }
    
        public func receive(subscription: Subscription) {
            queue.sync {
                guard case .unsubscribed = status else {
                    subscription.cancel();
                    return;
                }
                status = .subscribed(subscription);
            }
        }
        
        public func receive(completion: Subscribers.Completion<Failure>) {
            receiveCompletion(completion);
        }
        
        public func receive(_ input: Input) -> Subscribers.Demand {
            self.receiveValue(input);
            return .none;
        }
        
        public func cancel() {
            let subscription = queue.sync(execute: { () -> Subscription? in
                guard case let .subscribed(subscription) = status else {
                    return nil;
                }
                status = .unsubscribed;
                return subscription;
            });
            subscription?.cancel();
        }

    }
    
}

extension Publisher where Failure == Never {
    
    public func sink(receiveCompletion: @escaping ((Subscribers.Completion<Failure>)->Void), receiveValue: @escaping (Output)->Void) -> Cancellable {
        let subscriber = Subscribers.Sink<Output,Never>(receiveCompletion: receiveCompletion, receiveValue: receiveValue);
        self.subscribe(subscriber);
        return AnyCancellable(subscriber.cancel);
    }

    public func sink(receiveValue: @escaping (Output)->Void) -> Cancellable {
        self.sink(receiveCompletion: { _ in }, receiveValue: receiveValue);
    }

}

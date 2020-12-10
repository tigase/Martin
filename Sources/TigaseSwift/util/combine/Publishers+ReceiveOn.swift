//
// Publishers+ReceiveOn.swift
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

extension Publisher {
    
    public func receive(on dispatcher: QueueDispatcher, flags: DispatchWorkItemFlags = .init()) -> Publishers.ReceiveOn<Self> {
        return .init(upstream: self, scheduler: dispatcher.queue, flags: flags);
    }
    
    public func receive(on queue: DispatchQueue, flags: DispatchWorkItemFlags = .init(rawValue: 0)) -> Publishers.ReceiveOn<Self> {
        return .init(upstream: self, scheduler: queue, flags: flags);
    }
    
}

extension Publishers {
    public struct ReceiveOn<Upstream: Publisher>: Publisher {
        
        public typealias Output = Upstream.Output;
        public typealias Failure = Upstream.Failure;
        
        public let upstream: Upstream;
        public let scheduler: DispatchQueue;
        public let flags: DispatchWorkItemFlags;
        
        public init(upstream: Upstream, scheduler: DispatchQueue, flags: DispatchWorkItemFlags) {
            self.upstream = upstream;
            self.scheduler = scheduler;
            self.flags = flags;
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
            upstream.subscribe(Inner(scheduler: scheduler, flags: flags, downstream: subscriber));
        }
        
        private final class Inner<Downstream: Subscriber>: Subscriber where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure {
            
            typealias Input = Upstream.Output;
            typealias Failure = Upstream.Failure;
            
            private let downstream: Downstream;
            private let scheduler: DispatchQueue;
            private let flags: DispatchWorkItemFlags
            
            init(scheduler: DispatchQueue, flags: DispatchWorkItemFlags, downstream: Downstream) {
                self.scheduler = scheduler;
                self.flags = flags;
                self.downstream = downstream;
            }
            
            func receive(subscription: Subscription) {
                downstream.receive(subscription: subscription);
            }
            
            func receive(_ input: Upstream.Output) -> Subscribers.Demand {
                scheduler.async(flags: flags) {
                    self.downstream.receive(input)
                }
                return .unlimited;
            }
            
            func receive(completion: Subscribers.Completion<Upstream.Failure>) {
                scheduler.async(flags: flags) {
                    self.downstream.receive(completion: completion);
                }
            }
            
        }
    }
}

//
// Publishers+DropFirst.swift
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
    
    func dropFirst(_ count: Int) -> Publishers.Drop<Self> {
        return .init(upstream: self, count: count);
    }
    
}

extension Publishers {
    
    public struct Drop<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        
        public let upstream: Upstream;
        public let count: Int;
        
        init(upstream: Upstream, count: Int)  {
            self.upstream = upstream;
            self.count = count;
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
            upstream.subscribe(Inner(downstream: subscriber, count: count));
        }
        
        private class Inner<Downstream: Subscriber>: Subscriber where Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure {
            
            typealias Input = Upstream.Output;
            typealias Failure = Upstream.Failure;
            
            public let downstream: Downstream;
            public var count: Int;
            
            init(downstream: Downstream, count: Int) {
                self.downstream = downstream;
                self.count = count;
            }
            
            func receive(subscription: Subscription) {
                downstream.receive(subscription: subscription);
            }
            
            func receive(completion: Subscribers.Completion<Upstream.Failure>) {
                downstream.receive(completion: completion);
            }
            
            func receive(_ input: Upstream.Output) -> Subscribers.Demand {
                guard count == 0 else {
                    count = count - 1;
                    return .unlimited;
                }
                return downstream.receive(input);
            }
        }
        
    }
    
}

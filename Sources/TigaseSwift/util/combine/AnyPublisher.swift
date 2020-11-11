//
// AnyPublisher.swift
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
    
    @inlinable
    public func eraseToAnyPublisher() -> AnyPublisher<Output, Failure> {
        return AnyPublisher(self);
    }
}

public struct AnyPublisher<Output, Failure: Error>: Publisher {
    
    @usableFromInline
    internal let publisher: BaseInternalPublisher<Output, Failure>;
    
    @inlinable
    public init<PublisherType: Publisher>(_ publisher: PublisherType) where Output == PublisherType.Output, Failure == PublisherType.Failure {
        self.publisher = InternalPublisher(publisher);
    }
 
    @inlinable
    public func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
        publisher.receive(subscriber: subscriber);
    }
    
    @usableFromInline
    internal class BaseInternalPublisher<Output, Failure: Error>: Publisher {
        
        @inlinable
        internal init() {}
        
        @usableFromInline
        func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
           
        }
        
    }
    
    @usableFromInline
    internal final class InternalPublisher<PublisherType: Publisher>: BaseInternalPublisher<PublisherType.Output, PublisherType.Failure> {
        
        @usableFromInline
        internal let publisherType: PublisherType;
        
        @inlinable
        internal init(_ publisherType: PublisherType) {
            self.publisherType = publisherType;
            super.init()
        }
        
        @inlinable
        override func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
            publisherType.receive(subscriber: subscriber);
        }
    }
}

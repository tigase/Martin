//
// LocalQueueDispatcher.swift
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
 Helper protocol for classes using internal dispatch queues
 */
public protocol LocalQueueDispatcher {
    
    var queueTag: DispatchSpecificKey<DispatchQueue?> { get}
    var queue: DispatchQueue { get }

}

extension LocalQueueDispatcher {

    public func dispatch_sync_local_queue(_ block: ()->()) {
        if (DispatchQueue.getSpecific(key: queueTag) != nil) {
            block();
        } else {
            queue.sync(execute: block);
        }
    }

    public func dispatch_sync_with_result_local_queue<T>(_ block: ()-> T) -> T {
        if (DispatchQueue.getSpecific(key: queueTag) != nil) {
            return block();
        } else {
            var result: T!;
            queue.sync {
                result = block();
            }
            return result;
        }
    }

}

public class QueueDispatcher {
    
    fileprivate var queueTag: DispatchSpecificKey<DispatchQueue?>;
    fileprivate var queue: DispatchQueue;
    
    public convenience init(label: String, attributes: DispatchQueue.Attributes? = nil) {
        let queue = attributes == nil ? DispatchQueue(label: label) : DispatchQueue(label: label, attributes: attributes!);
        self.init(queue: queue, queueTag: DispatchSpecificKey<DispatchQueue?>());
    }
    
    public init(queue: DispatchQueue, queueTag: DispatchSpecificKey<DispatchQueue?>) {
        self.queue = queue;
        self.queueTag = queueTag;
        self.queue.setSpecific(key: queueTag, value: self.queue)
    }
    
    deinit {
        queue.setSpecific(key: queueTag, value: nil);
    }
    
    open func sync<T>(flags: DispatchWorkItemFlags, execute: () throws -> T) rethrows -> T {
        if (DispatchQueue.getSpecific(key: queueTag) != nil) {
            return try execute();
        } else {
            return try queue.sync(flags: flags, execute: execute)
        }
    }

    open func sync(flags: DispatchWorkItemFlags, execute: () throws -> Void) rethrows {
        if (DispatchQueue.getSpecific(key: queueTag) != nil) {
            try execute();
        } else {
            try queue.sync(flags: flags, execute: execute);
        }
    }

    open func sync<T>(execute: () throws -> T) rethrows -> T {
        if (DispatchQueue.getSpecific(key: queueTag) != nil) {
            return try execute();
        } else {
            return try queue.sync(execute: execute);
        }
    }

    open func sync(execute: () throws -> Void) rethrows {
        if (DispatchQueue.getSpecific(key: queueTag) != nil) {
            try execute();
        } else {
            try queue.sync(execute: execute);
        }
    }

    open func async(flags: DispatchWorkItemFlags, execute: @escaping ()->Void) {
        queue.async(flags: flags, execute: execute);
    }
    
    open func async(execute: @escaping () -> Void) {
        queue.async(execute: execute);
    }
}

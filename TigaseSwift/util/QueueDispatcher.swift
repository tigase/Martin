//
// QueueDispatcher.swift
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
public class QueueDispatcher {
    
    struct QueueIdentity {
        let label: String;
    }
    
    private static var usedQueueNames: [String] = [];
    
    private let queueKey: DispatchSpecificKey<QueueIdentity>;
    let queue: DispatchQueue;
    
    private var currentQueueIdentity: QueueIdentity? {
        return DispatchQueue.getSpecific(key: self.queueKey);
    }
    
    private var execOnCurrentQueue: Bool {
        return self.currentQueueIdentity?.label == queue.label;
    }
    
    public init(label prefix: String, attributes: DispatchQueue.Attributes? = nil) {
        let label = "\(prefix) \(UUID().uuidString)";
        self.queue = attributes == nil ? DispatchQueue(label: label) : DispatchQueue(label: label, attributes: attributes!);
        self.queueKey = DispatchSpecificKey<QueueIdentity>();
        self.queue.setSpecific(key: queueKey, value: QueueIdentity(label: queue.label));
    }
    
    open func sync<T>(flags: DispatchWorkItemFlags, execute: () throws -> T) rethrows -> T {
        if (execOnCurrentQueue) {
            return try execute();
        } else {
            return try queue.sync(flags: flags, execute: execute)
        }
    }

    open func sync(flags: DispatchWorkItemFlags, execute: () throws -> Void) rethrows {
        if (execOnCurrentQueue) {
            try execute();
        } else {
            try queue.sync(flags: flags, execute: execute);
        }
    }

    open func sync<T>(execute: () throws -> T) rethrows -> T {
        if (execOnCurrentQueue) {
            return try execute();
        } else {
            return try queue.sync(execute: execute);
        }
    }

    open func sync(execute: () throws -> Void) rethrows {
        if (execOnCurrentQueue) {
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
    
    open func asyncAfter(deadline: DispatchTime, execute: @escaping ()->Void) {
        queue.asyncAfter(deadline: deadline, execute: execute);
    }
}

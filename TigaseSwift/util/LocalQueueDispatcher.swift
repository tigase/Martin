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

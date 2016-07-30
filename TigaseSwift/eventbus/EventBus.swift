//
// EventBus.swift
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
 Class implements mechanism of events bus which is used by TigaseSwift
 to notify about events.
 */
public class EventBus: Logger, LocalQueueDispatcher {
    
    private var handlersByEvent:[String:[EventHandler]];
    
    public let queueTag: UnsafeMutablePointer<Void>
    public let queue: dispatch_queue_t;
    
    public convenience override init() {
        self.init(dispatchQueue: nil);
    }
    
    public init(dispatchQueue: dispatch_queue_t?) {
        handlersByEvent = [:];
        self.queue = dispatchQueue ?? dispatch_queue_create("eventbus_queue", DISPATCH_QUEUE_SERIAL);
        self.queueTag = UnsafeMutablePointer<Void>(Unmanaged.passUnretained(self.queue).toOpaque());
        dispatch_queue_set_specific(queue, queueTag, queueTag, nil);
        super.init();
    }
    
    /**
     Registeres handler to be notified when events of particular types are fired
     - parameter handler: handler to register
     - parameter events: events on which handler should be notified
     */
    public func register(handler:EventHandler, events:Event...) {
        register(handler, events: events);
    }
    
    /**
     Registeres handler to be notified when events of particular types are fired
     - parameter handler: handler to register
     - parameter events: events on which handler should be notified
     */
    public func register(handler:EventHandler, events:[Event]) {
        dispatch_async(queue) {
            for event in events {
                let type = event.type;
                var handlers = self.handlersByEvent[type];
                if handlers == nil {
                    handlers = [EventHandler]();
                }
                if (handlers!.indexOf({ $0 === handler }) == nil) {
                    handlers!.append(handler);
                }
                self.handlersByEvent[type] = handlers;
            }
        }
    }
    
    /**
     Unregisteres handler, so it will not be notified when events of particular types are fired
     - parameter handler: handler to unregister
     - parameter events: events on which handler should not be notified
     */
    public func unregister(handler:EventHandler, events:Event...) {
        self.unregister(handler, events: events);
    }
    
    /**
     Unregisteres handler, so it will not be notified when events of particular types are fired
     - parameter handler: handler to unregister
     - parameter events: events on which handler should not be notified
     */
    public func unregister(handler:EventHandler, events:[Event]) {
        dispatch_async(queue) {
            for event in events {
                let type = event.type;
                if var handlers = self.handlersByEvent[type] {
                    if let idx = handlers.indexOf({ $0 === handler }) {
                        handlers.removeAtIndex(idx);
                    }
                    self.handlersByEvent[type] = handlers;
                }
            }
        }
    }
    
    /**
     Fire event on this event bus
     - parameter event: event to fire
     */
    public func fire(event:Event) {
        if event is SerialEvent {
            dispatch_sync_local_queue() {
                let type = event.type;
                if let handlers = self.handlersByEvent[type] {
                    for handler in handlers {
                        handler.handleEvent(event);
                    }
                }
            }
        } else {
            dispatch_async(queue) {
                let type = event.type;
                if let handlers = self.handlersByEvent[type] {
                    for handler in handlers {
                        handler.handleEvent(event);
                    }
                }
            }
        }
    }
}

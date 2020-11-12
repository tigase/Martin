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
open class EventBus {
    
    private var handlersByEvent:[String:[Wrapper]];
    
    private let dispatcher: QueueDispatcher;
    
    public convenience init() {
        self.init(queueDispatcher: nil);
    }
    
    public init(queueDispatcher: QueueDispatcher?) {
        handlersByEvent = [:];
        self.dispatcher = queueDispatcher ?? QueueDispatcher(label: "eventbus_queue");
    }
    
    /**
     Registeres handler to be notified when events of particular types are fired
     - parameter handler: handler to register
     - parameter for: events on which handler should be notified
     */
    open func register(handler:EventHandler, for events:Event...) {
        register(handler: handler, for: events);
    }
    
    /**
     Registeres handler to be notified when events of particular types are fired
     - parameter handler: handler to register
     - parameter for: events on which handler should be notified
     */
    open func register(handler:EventHandler, for events:[Event]) {
        dispatcher.async {
            for event in events {
                let type = event.type;
                var handlers = self.handlersByEvent[type];
                if handlers == nil {
                    handlers = [Wrapper]();
                }
                if (handlers!.firstIndex(where: { $0 === handler }) == nil) {
                    handlers!.append(Wrapper(handler));
                }
                self.handlersByEvent[type] = handlers;
            }
        }
    }
    
    /**
     Unregisteres handler, so it will not be notified when events of particular types are fired
     - parameter handler: handler to unregister
     - parameter for: events on which handler should not be notified
     */
    open func unregister(handler:EventHandler, for events:Event...) {
        self.unregister(handler: handler, for: events);
    }
    
    /**
     Unregisteres handler, so it will not be notified when events of particular types are fired
     - parameter handler: handler to unregister
     - parameter for: events on which handler should not be notified
     */
    open func unregister(handler:EventHandler, for events:[Event]) {
        dispatcher.async {
            for event in events {
                let type = event.type;
                if var handlers = self.handlersByEvent[type] {
                    if let idx = handlers.firstIndex(where: { $0.eventHandler === handler }) {
                        handlers.remove(at: idx);
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
    open func fire(_ event:Event) {
        if event is SerialEvent {
            dispatcher.sync {
                let type = event.type;
                if let handlers = self.handlersByEvent[type] {
                    for handler in handlers {
                        handler.handle(event: event);
                    }
                }
            }
        } else {
            dispatcher.async {
                let type = event.type;
                if let handlers = self.handlersByEvent[type] {
                    for handler in handlers {
                        handler.handle(event: event);
                    }
                }
            }
        }
    }
    
    private class Wrapper: EventHandler {
        
        internal weak var eventHandler: EventHandler?;
        
        public init(_ eventHandler: EventHandler) {
            self.eventHandler = eventHandler;
        }
        
        func handle(event: Event) {
            eventHandler?.handle(event: event);
        }
        
    }
}

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


public class EventBus {
    
    //    private var handlersByEvent:[String:[(event:Event)->Void]];
    private var handlersByEvent:[String:[EventHandler]];
    
    public init() {
        handlersByEvent = [:];
    }
    
    public func register(handler:EventHandler, events:Event...) {
        for event in events {
            let type = event.type;
            var handlers = handlersByEvent[type];
            if handlers == nil {
                handlers = [EventHandler]();
            }
            handlers?.append(handler);
            handlersByEvent[type] = handlers;
        }
    }
    
    public func unregister(handler:EventHandler, events:Event...) {
        for event in events {
            let type = event.type;
            if var handlers = handlersByEvent[type] {
                if let idx = handlers.indexOf({ $0 === handler }) {
                    handlers.removeAtIndex(idx);
                }
            }
        }
    }
    
    public func fire(event:Event) {
        let type = event.type;
        if let handlers = handlersByEvent[type] {
            for handler in handlers {
                handler.handleEvent(event);
            }
        }
    }
}

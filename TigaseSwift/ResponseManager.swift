//
// ResponseManager.swift
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
 Class implements manager for registering requests sent to stream
 and their callbacks, and to retieve them when response appears
 in the stream.
 */
public class ResponseManager: Logger {
    
    /// Internal class holding information about request and callbacks
    private class Entry {
        let jid: JID?;
        let timestamp: NSDate;
        let callback: (Stanza?)->Void;
        
        init(jid:JID?, callback:(Stanza?)->Void, timeout:NSTimeInterval) {
            self.jid = jid;
            self.callback = callback;
            self.timestamp = NSDate(timeIntervalSinceNow: timeout);
        }
        
        func checkTimeout() -> Bool {
            return timestamp.timeIntervalSinceNow < 0;
        }
    }
    
    private let queue = dispatch_queue_create("response_manager_queue", DISPATCH_QUEUE_SERIAL);
    
    private var timer:Timer?;
    
    private var handlers = [String:Entry]();
    
    private let context:Context;
    
    public init(context:Context) {
        self.context = context;
    }

    /**
     Method processes passed stanza and looks for callback
     - paramater stanza: stanza to process
     - returns: callback handler if any
     */
    public func getResponseHandler(stanza:Stanza)-> ((Stanza?)->Void)? {
        let type = stanza.type;
        if (stanza.id == nil || (type != StanzaType.error && type !=  StanzaType.result)) {
            return nil;
        }
        let id = stanza.id!;
        var callback: ((Stanza?)->Void)? = nil;
        dispatch_sync(queue) {
            if let entry = self.handlers[id] {
                let userJid = ResourceBinderModule.getBindedJid(self.context.sessionObject);
                let from = stanza.from;
                if (entry.jid == from) || (entry.jid == nil && from?.bareJid == userJid?.bareJid) {
                    self.handlers.removeValueForKey(id)
                    callback = entry.callback;
                }
            }
        }
        return callback;
    }
    
    /**
     Method registers callback for stanza for time
     - parameter stanza: stanza for which to wait for response
     - parameter timeout: maximal time for which should wait for response
     - parameter callback: callback to execute on response or timeout
     */
    public func registerResponseHandler(stanza:Stanza, timeout:NSTimeInterval, callback:((Stanza?)->Void)?) {
        guard callback != nil else {
            return;
        }
        
        var id = stanza.id;
        if id == nil {
            id = nextUid();
            stanza.id = id;
        }
        
        dispatch_async(queue) {
            self.handlers[id!] = Entry(jid: stanza.to, callback: callback!, timeout: timeout);
        }
    }
    
    /**
     Method registers callback for stanza for time
     - parameter stanza: stanza for which to wait for response
     - parameter timeout: maximal time for which should wait for response
     - parameter onSuccess: callback to execute on successful response
     - parameter onError: callback to execute on failure or timeout
     */
    public func registerResponseHandler(stanza:Stanza, timeout:NSTimeInterval, onSuccess:((Stanza)->Void)?, onError:((Stanza,ErrorCondition?)->Void)?, onTimeout:(()->Void)?) {
        guard (onSuccess != nil) || (onError != nil) || (onTimeout != nil) else {
            return;
        }
        
        self.registerResponseHandler(stanza, timeout: timeout) { (response:Stanza?)->Void in
            if response == nil {
                onTimeout?();
            } else {
                if response!.type == StanzaType.error {
                    onError?(response!, response!.errorCondition);
                } else {
                    onSuccess?(response!);
                }
            }
        }
    }
    
    /**
     Method registers callback for stanza for time
     - parameter stanza: stanza for which to wait for response
     - parameter timeout: maximal time for which should wait for response
     - parameter callback: callback with methods to execute on response or timeout
     */
    public func registerResponseHandler(stanza:Stanza, timeout:NSTimeInterval, callback:AsyncCallback) {
        self.registerResponseHandler(stanza, timeout: timeout) { (response:Stanza?)->Void in
            if response == nil {
                callback.onTimeout();
            } else {
                if response!.type == StanzaType.error {
                    callback.onError(response!, error: response!.errorCondition);
                } else {
                    callback.onSuccess(response!);
                }
            }
        }
    }
    
    /// Activate response manager
    public func start() {
        timer = Timer(delayInSeconds: 30, repeats: true) {
            self.checkTimeouts();
        }
    }
    
    /// Deactivates response manager
    public func stop() {
        timer?.cancel();
        timer = nil;
        for (id,handler) in handlers {
            handlers.removeValueForKey(id);
            handler.callback(nil);
        }
    }
    
    /// Returns next unique id
    func nextUid() -> String {
        return UIDGenerator.nextUid;
    }
    
    /// Check if any callback should be called due to timeout
    func checkTimeouts() {
        dispatch_sync(queue) {
            for (id,handler) in self.handlers {
                if handler.checkTimeout() {
                    self.handlers.removeValueForKey(id);
                    handler.callback(nil);
                }
            }
        }
    }
}

/**
 Protocol for classes which may be used as callbacks for `ResponseManager`
 */
public protocol AsyncCallback {
    
    func onError(response:Stanza, error:ErrorCondition?);
    func onSuccess(responseStanza:Stanza);
    func onTimeout();
    
}

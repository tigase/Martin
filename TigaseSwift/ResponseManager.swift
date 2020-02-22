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
open class ResponseManager: Logger {
    
    /// Internal class holding information about request and callbacks
    fileprivate class Entry {
        let jid: JID?;
        let timestamp: Date;
        let callback: (Stanza?)->Void;
        
        init(jid:JID?, callback:@escaping (Stanza?)->Void, timeout:TimeInterval) {
            self.jid = jid;
            self.callback = callback;
            self.timestamp = Date(timeIntervalSinceNow: timeout);
        }
        
        func checkTimeout() -> Bool {
            return timestamp.timeIntervalSinceNow < 0;
        }
    }
    
    fileprivate let queue = DispatchQueue(label: "response_manager_queue", attributes: []);
    
    fileprivate var timer:Timer?;
    
    fileprivate var handlers = [String:Entry]();
    
    fileprivate let context:Context;
    
    public init(context:Context) {
        self.context = context;
    }

    /**
     Method processes passed stanza and looks for callback
     - paramater stanza: stanza to process
     - returns: callback handler if any
     */
    open func getResponseHandler(for stanza:Stanza)-> ((Stanza?)->Void)? {
        let type = stanza.type;
        if (stanza.id == nil || (type != StanzaType.error && type !=  StanzaType.result)) {
            return nil;
        }
        let id = stanza.id!;
        var callback: ((Stanza?)->Void)? = nil;
        queue.sync {
            if let entry = self.handlers[id] {
                let userJid = ResourceBinderModule.getBindedJid(self.context.sessionObject);
                let from = stanza.from;
                if (entry.jid == from) || (entry.jid == nil && from?.bareJid == userJid?.bareJid) {
                    self.handlers.removeValue(forKey: id)
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
    open func registerResponseHandler(for stanza:Stanza, timeout:TimeInterval, callback:((Stanza?)->Void)?) {
        guard callback != nil else {
            return;
        }
        
        var id = stanza.id;
        if id == nil {
            id = nextUid();
            stanza.id = id;
        }
        
        queue.async {
            self.handlers[id!] = Entry(jid: stanza.to, callback: callback!, timeout: timeout);
        }
    }
    
    /**
     Method registers callback for stanza for time
     - parameter stanza: stanza for which to wait for response
     - parameter timeout: maximal time for which should wait for response
     - parameter callback: callback to execute on response or timeout
     */
    open func registerResponseHandler(for stanza:Stanza, timeout:TimeInterval, callback:((AsyncResult<Stanza>)->Void)?) {
        guard let callback = callback else {
            return;
        }
        
        var id = stanza.id;
        if id == nil {
            id = nextUid();
            stanza.id = id;
        }
        
        queue.async {
            self.handlers[id!] = Entry(jid: stanza.to, callback: { response in
                if response == nil {
                    callback(.failure(errorCondition: .remote_server_timeout, response: response));
                } else {
                    if response!.type == .error {
                        callback(.failure(errorCondition: response!.errorCondition ?? ErrorCondition.undefined_condition, response: response));
                    } else {
                        callback(.success(response: response!));
                    }
                }
            }, timeout: timeout);
        }
    }
    
    /**
     Method registers callback for stanza for time
     - parameter stanza: stanza for which to wait for response
     - parameter timeout: maximal time for which should wait for response
     - parameter onSuccess: callback to execute on successful response
     - parameter onError: callback to execute on failure or timeout
     */
    open func registerResponseHandler(for stanza:Stanza, timeout:TimeInterval, onSuccess:((Stanza)->Void)?, onError:((Stanza,ErrorCondition?)->Void)?, onTimeout:(()->Void)?) {
        guard (onSuccess != nil) || (onError != nil) || (onTimeout != nil) else {
            return;
        }
        
        self.registerResponseHandler(for: stanza, timeout: timeout) { (response:Stanza?)->Void in
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
    open func registerResponseHandler(for stanza:Stanza, timeout:TimeInterval, callback:AsyncCallback) {
        self.registerResponseHandler(for: stanza, timeout: timeout) { (response:Stanza?)->Void in
            if response == nil {
                callback.onTimeout();
            } else {
                if response!.type == StanzaType.error {
                    callback.onError(response: response!, error: response!.errorCondition);
                } else {
                    callback.onSuccess(response: response!);
                }
            }
        }
    }
    
    /// Activate response manager
    open func start() {
        timer = Timer(delayInSeconds: 30, repeats: true) {
            self.checkTimeouts();
        }
    }
    
    /// Deactivates response manager
    open func stop() {
        timer?.cancel();
        timer = nil;
        queue.sync {
            for (id,handler) in self.handlers {
                self.handlers.removeValue(forKey: id);
                handler.callback(nil);
            }
        }
    }
    
    /// Returns next unique id
    func nextUid() -> String {
        return UIDGenerator.nextUid;
    }
    
    /// Check if any callback should be called due to timeout
    func checkTimeouts() {
        queue.sync {
            for (id,handler) in self.handlers {
                if handler.checkTimeout() {
                    self.handlers.removeValue(forKey: id);
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
    func onSuccess(response:Stanza);
    func onTimeout();
    
}

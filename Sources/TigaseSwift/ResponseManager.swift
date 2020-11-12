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
import TigaseLogging

/**
 Class implements manager for registering requests sent to stream
 and their callbacks, and to retieve them when response appears
 in the stream.
 */
open class ResponseManager {
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "ResponseManager")
    /// Internal class holding information about request and callbacks
    fileprivate class Entry {
        let id: String;
        let jid: JID?;
        let timestamp: Date;
        let callback: (Iq?)->Void;
        
        init(id: String, jid:JID?, callback:@escaping (Iq?)->Void, timeout:TimeInterval) {
            self.id = id;
            self.jid = jid;
            self.callback = callback;
            self.timestamp = Date(timeIntervalSinceNow: timeout);
        }
        
        func checkTimeout() -> Bool {
            return timestamp.timeIntervalSinceNow < 0;
        }
    }
    
    private let queue = DispatchQueue(label: "response_manager_queue", attributes: []);
    
    private var timer:Timer?;
    
    private var handlers = [String:Entry]();
    
    open weak var context: Context?;
    
    public init() {
    }
    
    deinit {
        timer?.invalidate();
    }

    /**
     Method processes passed stanza and looks for callback
     - paramater stanza: stanza to process
     - returns: callback handler if any
     */
    open func getResponseHandler(for stanza: Iq)-> ((Iq?)->Void)? {
        guard let type = stanza.type, let id = stanza.id, (type == StanzaType.error || type == StanzaType.result) else {
            return nil;
        }

        return queue.sync {
            if let entry = self.handlers[id] {
                let userJid = context?.moduleOrNil(.resourceBind)?.bindedJid;
                if let from = stanza.from {
                    if entry.jid == from || (entry.jid == nil && from.bareJid == userJid?.bareJid && from.resource == nil) {
                        self.handlers.removeValue(forKey: id)
                        return entry.callback;
                    }
                } else {
                    if entry.jid == nil || (entry.jid?.bareJid == userJid?.bareJid && entry.jid?.resource == nil) {
                        self.handlers.removeValue(forKey: id)
                        return entry.callback;
                    }
                }
            }
            return nil;
        }
    }
    
    /**
     Method registers callback for stanza for time
     - parameter stanza: stanza for which to wait for response
     - parameter timeout: maximal time for which should wait for response
     - parameter callback: callback to execute on response or timeout
     */
    open func registerResponseHandler<Failure: Error>(for stanza:Stanza, timeout:TimeInterval, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) -> Cancellable {
        
        var id = stanza.id;
        if id == nil {
            id = nextUid();
            stanza.id = id;
        }
        
        let entry = Entry(id: id!, jid: stanza.to, callback: { response in
            if let stanza = response, stanza.type == .result {
                completionHandler(.success(stanza))
            } else {
                completionHandler(.failure(errorDecoder(stanza) as! Failure));
            }
        }, timeout: timeout);
        queue.async {
            self.handlers[id!] = entry;
        }
        
        return CancellableEntry(responseManager: self, entry: entry);
    }
    
    /// Activate response manager
    open func start() {
        let timer = Timer(timeInterval: 30.0, repeats: true, block: { [weak self] timer in
            self?.checkTimeouts();
        })
        DispatchQueue.main.async {
            RunLoop.current.add(timer, forMode: .common);
        }
        self.timer = timer;
    }
    
    /// Deactivates response manager
    open func stop() {
        if let timer = timer {
            DispatchQueue.main.async {
                timer.invalidate();
            }
        }
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
    
    fileprivate func cancel(entry: Entry) {
        queue.async {
            self.handlers.removeValue(forKey: entry.id);
        }
    }
    
    private class CancellableEntry: Cancellable {
        
        private let responseManager: ResponseManager;
        private let entry: Entry;
        
        fileprivate init(responseManager: ResponseManager, entry: Entry) {
            self.responseManager = responseManager;
            self.entry = entry;
        }
        
        public func cancel() {
            responseManager.cancel(entry: entry);
        }
    }
}

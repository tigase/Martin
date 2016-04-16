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

public class ResponseManager: Logger {
    
    private class Entry {
        let jid:JID?;
        let timestamp:NSDate;
        let callback:(Stanza)->Void;
        
        init(jid:JID?, callback:(Stanza)->Void, timeout:NSTimeInterval) {
            self.jid = jid;
            self.callback = callback;
            self.timestamp = NSDate(timeIntervalSinceNow: timeout);
        }
        
        func checkTimeout() -> Bool {
            return timestamp.timeIntervalSinceNow < 0;
        }
    }
    
    private var timer:NSTimer?;
    
    private var handlers = [String:Entry]();
    
    private let context:Context;
    
    public init(context:Context) {
        self.context = context;
    }

    public func getResponseHandler(stanza:Stanza)-> ((Stanza)->Void)? {
        if (stanza.id == nil) {
            return nil;
        }
        let id = stanza.id!;
        if let entry = handlers[id] {
            let userJid = ResourceBinderModule.getBindedJid(context.sessionObject);
            let from = stanza.from;
            if (entry.jid == from) || (entry.jid == nil && from?.bareJid == userJid?.bareJid) {
                handlers.removeValueForKey(id)
                return entry.callback;
            }
        }
        return nil;
    }
    
    public func registerResponseHandler(stanza:Stanza, timeout:NSTimeInterval, callback:(Stanza)->Void) {
        var id = stanza.id;
        if id == nil {
            id = nextUid();
            stanza.id = id;
        }
        handlers[id!] = Entry(jid: stanza.to, callback: callback, timeout: timeout);
    }
    
    public func start() {
        timer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(30), target: self, selector: #selector(ResponseManager.checkTimeouts), userInfo: nil, repeats: true);
    }
    
    public func stop() {
        if timer != nil {
            timer?.invalidate();
        }
    }
    
    func nextUid() -> String {
        return NSUUID().UUIDString;
    }
    
    @objc func checkTimeouts() {
        
    }
}
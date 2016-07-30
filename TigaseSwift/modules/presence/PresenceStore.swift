//
// PresenceStore.swift
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
 Default implementation of in-memory presence store
 */
public class PresenceStore {
    
    private let queue = dispatch_queue_create("presence_store_queue", DISPATCH_QUEUE_CONCURRENT);
    private let queueTag: UnsafeMutablePointer<Void>;
    
    private var handler:PresenceStoreHandler?;
    
    private var bestPresence = [BareJID:Presence]();
    private var presenceByJid = [JID:Presence]();
    private var presencesMapByBareJid = [BareJID:[String:Presence]]();
    
    public init() {
        queueTag = UnsafeMutablePointer<Void>(Unmanaged.passUnretained(self.queue).toOpaque());
        dispatch_queue_set_specific(queue, queueTag, queueTag, nil);
    }
    
    /// Clear presence store
    public func clear() {
        dispatch_barrier_async(queue) {
            self.presenceByJid.removeAll();
            let toNotify = Array(self.bestPresence.values);
            self.bestPresence.removeAll();
            toNotify.forEach { (p) in
                self.handler?.onOffline(p);
            }
            self.presencesMapByBareJid.removeAll();
        }
    }
    
    /**
     Retrieve best presence for jid
     - parameter jid: jid for which to retrieve presence
     - returns: `Presence` if available
     */
    public func getBestPresence(jid:BareJID) -> Presence? {
        var result: Presence?;
        dispatch_sync_local_queue() {
            result = self.bestPresence[jid];
        }
        return result;
    }
    
    /**
     Retrieve presence for exact full jid
     - parameter jid: jid for which to retrieve presence
     - returns: `Presence` if available
     */
    public func getPresence(jid:JID) -> Presence? {
        var result: Presence?;
        dispatch_sync_local_queue() {
            result = self.presenceByJid[jid];
        }
        return result;
    }
    
    /**
     Retrieve all presences for bare jid
     - parameter jid: jid for which to retrieve presences
     - returns: array of `Presence`s if avaiable
     */
    public func getPresences(jid:BareJID) -> [String:Presence]? {
        var result: [String:Presence]?;
        dispatch_sync_local_queue() {
            result = self.presencesMapByBareJid[jid];
        }
        return result;
    }
    
    private func findBestPresence(jid:BareJID) -> Presence? {
        var result:Presence? = nil;
        self.presencesMapByBareJid[jid]?.values.forEach({ (p) in
            if (result == nil || (p.priority >= result!.priority && p.type == nil)) {
                result = p;
            }
        });
        return result;
    }
    
    /**
     Check if any resource for jid is available
     - parameter jid: jid to check
     - returns: true if any resource if available
     */
    public func isAvailable(jid:BareJID) -> Bool {
        var result = false;
        dispatch_sync_local_queue() {
            result = self.presencesMapByBareJid[jid]?.values.indexOf({ (p) -> Bool in
                return p.type == nil || p.type == StanzaType.available;
            }) != nil;
        }
        return result;
    }
    
    public func setHandler(handler:PresenceStoreHandler) {
        self.handler = handler;
    }
    
    /**
     Set presence with values
     - parameter show: presence show
     - parameter status: additional text description
     - parameter priority: priority of presence
     */
    public func setPresence(show:Presence.Show, status:String?, priority:Int?) {
        self.handler?.setPresence(show, status: status, priority: priority);
    }
    
    func update(presence:Presence) -> Bool {
        var result = false;
        if let from = presence.from {
            dispatch_barrier_sync(queue) {
                var wasAwailable = self.isAvailable(from.bareJid);
                self.presenceByJid[from] = presence;
                var byResource = self.presencesMapByBareJid[from.bareJid] ?? [String:Presence]();
                byResource[from.resource ?? ""] = presence;
                self.presencesMapByBareJid[from.bareJid] = byResource;
                self.updateBestPresence(from.bareJid);
                var isAvailable = self.isAvailable(from.bareJid);
                result = true;
            }
        }
        return result;
    }
    
    private func updateBestPresence(from:BareJID) {
        if let best = findBestPresence(from) {
            bestPresence[from] = best;
        }
    }
    
    private func dispatch_sync_local_queue(block: dispatch_block_t) {
        if (dispatch_get_specific(queueTag) != nil) {
            block();
        } else {
            dispatch_sync(queue, block);
        }
    }
}

public protocol PresenceStoreHandler {
    
    func onOffline(presence:Presence);
    
    func setPresence(show:Presence.Show, status:String?, priority:Int?);
}
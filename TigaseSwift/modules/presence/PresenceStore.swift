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
open class PresenceStore {
    
    fileprivate let queue = DispatchQueue(label: "presence_store_queue", attributes: DispatchQueue.Attributes.concurrent);
    fileprivate let queueTag = DispatchSpecificKey<DispatchQueue?>();
    
    fileprivate var handler:PresenceStoreHandler?;
    
    fileprivate var bestPresence = [BareJID:Presence]();
    fileprivate var presenceByJid = [JID:Presence]();
    fileprivate var presencesMapByBareJid = [BareJID:[String:Presence]]();
    
    public init() {
        queue.setSpecific(key: queueTag, value: queue);
    }
    
    deinit {
        queue.setSpecific(key: queueTag, value: nil);
    }
    
    /// Clear presence store
    open func clear() {
        queue.async(flags: .barrier, execute: {
            self.presenceByJid.removeAll();
            let toNotify = Array(self.bestPresence.values);
            self.bestPresence.removeAll();
            toNotify.forEach { (p) in
                self.handler?.onOffline(presence: p);
            }
            self.presencesMapByBareJid.removeAll();
        }) 
    }
    
    /**
     Retrieve best presence for jid
     - parameter for: jid for which to retrieve presence
     - returns: `Presence` if available
     */
    open func getBestPresence(for jid:BareJID) -> Presence? {
        var result: Presence?;
        dispatch_sync_local_queue() {
            result = self.bestPresence[jid];
        }
        return result;
    }
    
    /**
     Retrieve presence for exact full jid
     - parameter for: jid for which to retrieve presence
     - returns: `Presence` if available
     */
    open func getPresence(for jid:JID) -> Presence? {
        var result: Presence?;
        dispatch_sync_local_queue() {
            result = self.presenceByJid[jid];
        }
        return result;
    }
    
    /**
     Retrieve all presences for bare jid
     - parameter for: jid for which to retrieve presences
     - returns: array of `Presence`s if avaiable
     */
    open func getPresences(for jid:BareJID) -> [String:Presence]? {
        var result: [String:Presence]?;
        dispatch_sync_local_queue() {
            result = self.presencesMapByBareJid[jid];
        }
        return result;
    }
    
    fileprivate func findBestPresence(for jid:BareJID) -> Presence? {
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
    open func isAvailable(jid:BareJID) -> Bool {
        var result = false;
        dispatch_sync_local_queue() {
            result = self.presencesMapByBareJid[jid]?.values.index(where: { (p) -> Bool in
                return p.type == nil || p.type == StanzaType.available;
            }) != nil;
        }
        return result;
    }
    
    open func setHandler(_ handler:PresenceStoreHandler) {
        self.handler = handler;
    }
    
    /**
     Set presence with values
     - parameter show: presence show
     - parameter status: additional text description
     - parameter priority: priority of presence
     */
    open func setPresence(show:Presence.Show, status:String?, priority:Int?) {
        self.handler?.setPresence(show: show, status: status, priority: priority);
    }
    
    func update(presence:Presence) -> Bool {
        var result = false;
        if let from = presence.from {
            queue.sync(flags: .barrier, execute: {
                self.presenceByJid.updateValue(presence, forKey: from);
                var byResource = self.presencesMapByBareJid[from.bareJid] ?? [String:Presence]();
                byResource[from.resource ?? ""] = presence;
                self.presencesMapByBareJid[from.bareJid] = byResource;
                self.updateBestPresence(for: from.bareJid);
                result = true;
            }) 
        }
        return result;
    }
    
    fileprivate func updateBestPresence(for from:BareJID) {
        if let best = findBestPresence(for: from) {
            bestPresence[from] = best;
        }
    }
    
    fileprivate func dispatch_sync_local_queue(_ block: ()->()) {
        if (DispatchQueue.getSpecific(key: queueTag) != nil) {
            block();
        } else {
            queue.sync(execute: block);
        }
    }
}

public protocol PresenceStoreHandler {
    
    func onOffline(presence:Presence);
    
    func setPresence(show:Presence.Show, status:String?, priority:Int?);
}

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
    
    fileprivate let queue = QueueDispatcher(label: "presence_store_queue", attributes: DispatchQueue.Attributes.concurrent);
    
    fileprivate var bestPresence = [BareJID:Presence]();
    fileprivate var presenceByJid = [JID:Presence]();
    fileprivate var presencesMapByBareJid = [BareJID:[String:Presence]]();
    
    public init() {
    }
        
    /// Clear presence store
    open func clear() {
        queue.async(flags: .barrier, execute: {
            self.presenceByJid.removeAll();
            self.bestPresence.removeAll();
            self.presencesMapByBareJid.removeAll();
        }) 
    }

    public var allBestPresences: [Presence] {
        return queue.sync {
            return Array(self.bestPresence.values);
        }
    }
    
    /**
     Retrieve array of all stored presences
     - returns: array of `Presence`
     */
    open func getAllPresences() -> [Presence] {
        return queue.sync {
            Array(presenceByJid.values);
        };
    }
    
    /**
     Retrieve best presence for jid
     - parameter for: jid for which to retrieve presence
     - returns: `Presence` if available
     */
    open func getBestPresence(for jid:BareJID) -> Presence? {
        return queue.sync {
            return self.bestPresence[jid];
        }
    }
    
    /**
     Retrieve presence for exact full jid
     - parameter for: jid for which to retrieve presence
     - returns: `Presence` if available
     */
    open func getPresence(for jid:JID) -> Presence? {
        return queue.sync {
            return self.presenceByJid[jid];
        }
    }
    
    /**
     Retrieve all presences for bare jid
     - parameter for: jid for which to retrieve presences
     - returns: array of `Presence`s if avaiable
     */
    open func getPresences(for jid:BareJID) -> [String:Presence]? {
        return queue.sync {
            return self.presencesMapByBareJid[jid];
        }
    }
    
    fileprivate func findBestPresence(for jid:BareJID) -> Presence? {
        var result:Presence? = nil;
        self.presencesMapByBareJid[jid]?.values.forEach({ (p) in
            if (result == nil || (result!.type ?? .available != .available && p.type ?? .available == .available) || (p.priority >= result!.priority && p.type ?? .available == .available)) {
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
        return queue.sync {
            return self.presencesMapByBareJid[jid]?.values.firstIndex(where: { (p) -> Bool in
                return p.type == nil || p.type == StanzaType.available;
            }) != nil;
        }
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
    
}

public protocol PresenceStoreHandler {
    
    func onOffline(presence:Presence);
    
    func setPresence(show:Presence.Show, status:String?, priority:Int?);
}

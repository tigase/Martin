//
// DefaultPresenceStore.swift
//
// TigaseSwift
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
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
import Combine

open class DefaultPresenceStore: PresenceStore {
    
    private let dispatcher = QueueDispatcher(label: "presence_store_queue", attributes: DispatchQueue.Attributes.concurrent);
    
    @Published
    public private(set) var bestPresences: [BareJID: Presence] = [:];
    public var bestPresencesPublisher: Published<[BareJID: Presence]>.Publisher {
        return $bestPresences;
    }
    
    public let bestPresenceEvents = PassthroughSubject<BestPresenceEvent, Never>();

    private var presencesByBareJID: [BareJID: PresenceHolder] = [:];

    public init() {
        
    }
    
    public func reset(scopes: Set<ResetableScope>, for context: Context) {
        if scopes.contains(.session) {
            dispatcher.sync(flags: .barrier) {
                presencesByBareJID.removeAll();
                let events = bestPresences.values.compactMap({ presence -> BestPresenceEvent? in
                    guard let account = presence.to?.bareJid, let jid = presence.from?.bareJid else {
                        return nil;
                    }
                    return BestPresenceEvent(account: account, jid: jid, presence: nil);
                });
                bestPresences.removeAll();
                for event in events {
                    bestPresenceEvents.send(event);
                }
            }
        }
    }
    
    open func presence(for jid: JID, context: Context) -> Presence? {
        return dispatcher.sync {
            return self.presencesByBareJID[jid.bareJid]?.presence(for: jid);
        }
    }
    
    open func presences(for jid: BareJID, context: Context) -> [Presence] {
        return dispatcher.sync {
            return self.presencesByBareJID[jid]?.presences;
        } ?? [];
    }

    public func bestPresence(for jid: BareJID, context: Context) -> Presence? {
        return bestPresences[jid];
    }

    
    open func update(presence: Presence, for context: Context) -> Presence? {
        guard let jid = presence.from else {
            return nil;
        }
        
        return dispatcher.sync(flags: .barrier) {
            let holder = self.holder(for: jid.bareJid);
            holder.update(presence: presence);
            if let best = holder.bestPresence, self.bestPresences[jid.bareJid] !== best {
                self.bestPresences[jid.bareJid] = best;
                self.bestPresenceEvents.send(.init(account: context.userBareJid, jid: jid.bareJid, presence: best));
            }
            return nil;
        }
    }
    
    open func removePresence(for jid: JID, context: Context) -> Bool {
        dispatcher.sync(flags: .barrier) {
            guard let holder = self.presencesByBareJID[jid.bareJid] else {
                return false;
            }
            holder.remove(for: jid);
            if let best = holder.bestPresence {
                self.bestPresences[jid.bareJid] = best;
                self.bestPresenceEvents.send(.init(account: context.userBareJid, jid: jid.bareJid, presence: best));
                return false;
            } else {
                self.presencesByBareJID.removeValue(forKey: jid.bareJid);
                self.bestPresenceEvents.send(.init(account: context.userBareJid, jid: jid.bareJid, presence: nil));
                return true;
            }
        }
    }
    
    private func holder(for jid: BareJID) -> PresenceHolder {
        guard let holder = self.presencesByBareJID[jid] else {
            let holder = PresenceHolder();
            self.presencesByBareJID[jid] = holder;
            return holder;
        }
        return holder;
    }
    
    public class PresenceHolder {
    
        public private(set) var presences: [Presence] = [];
    
        public var isEmpty: Bool {
            return presences.isEmpty;
        }
    
        public init() {}
        
        private func presenceIdx(for jid: JID) -> Int? {
            let resource = jid.resource;
            return presences.firstIndex(where: { $0.from?.resource == resource });
        }
        
        public func presence(for jid: JID) -> Presence? {
            guard let idx = presenceIdx(for: jid) else {
                return nil;
            }
            return presences[idx];
        }
        
        public func update(presence: Presence) {
            let jid = presence.from!;
            self.remove(for: jid);
            
            let value = presence.priority * 100 + (presence.show?.weight ?? 0);
            let values = presences.map({ $0.priority * 100 + ($0.show?.weight ?? 0) });
            let idx = values.firstIndex(where: { $0 < value });
            presences.insert(presence, at: idx ?? 0);
        }
        
        public func remove(for jid: JID) {
            if let idx = presenceIdx(for: jid) {
                self.presences.remove(at: idx);
            }
        }
        
        public var bestPresence: Presence? {
            return presences.first;
        }

    }
}

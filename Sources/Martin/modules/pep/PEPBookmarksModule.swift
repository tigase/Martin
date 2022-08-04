//
// PEPBookmarksModule.swift
//
// TigaseSwift
// Copyright (C) 2019 "Tigase, Inc." <office@tigase.com>
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

extension XmppModuleIdentifier {
    public static var pepBookmarks: XmppModuleIdentifier<PEPBookmarksModule> {
        return PEPBookmarksModule.IDENTIFIER;
    }
}

open class PEPBookmarksModule: AbstractPEPModule, XmppModule, @unchecked Sendable {
    
    public static let ID = "storage:bookmarks";
    public static let IDENTIFIER = XmppModuleIdentifier<PEPBookmarksModule>();
    
    public let features: [String] = [ ID + "+notify" ];
    
    @Published
    public fileprivate(set) var currentBookmarks: Bookmarks = Bookmarks();
    
    open override weak var context: Context? {
        didSet {
            discoModule = context?.module(.disco);
        }
    }
    
    private var discoModule: DiscoveryModule! {
        didSet {
            discoModule?.$serverDiscoResult.sink(receiveValue: { [weak self] info in self?.serverInfoChanged(info) }).store(in: self);
        }
    }
    
    public override init() {
        
    }
    
    open func addOrUpdate(bookmark item: BookmarksItem) async throws {
        if let updated = currentBookmarks.updateOrAdd(bookmark: item) {
            _ = try await self.publish(bookmarks: updated);
        }
    }
    
    open func remove(bookmark item: BookmarksItem) async throws {
        if let updated = currentBookmarks.remove(bookmark: item) {
            _ = try await self.publish(bookmarks: updated);
        }
    }
    
    open func setConferenceAutojoin(_ value: Bool, for jid: JID) async throws {
        guard let conference = self.currentBookmarks.conference(for: jid), conference.autojoin != value else {
            throw XMPPError(condition: .item_not_found);
        }
        try await addOrUpdate(bookmark: conference.with(autojoin: value));
    }
    
    public func publish(bookmarks: Bookmarks) async throws -> String {
        guard let context = context else {
            throw XMPPError(condition: .undefined_condition);
        }

        let pepJID = context.userBareJid;
        let config = PubSubNodeConfig();
        config.FORM_TYPE = "http://jabber.org/protocol/pubsub#node_config";
        config.persistItems = true;
        config.accessModel = .whitelist;

        do {
            return try await pubsubModule.publishItem(at: nil, to: PEPBookmarksModule.ID, payload: bookmarks.toElement(), publishOptions: config)
        } catch let error as XMPPError {
            guard error.condition == .conflict else {
                guard error.condition == .item_not_found else {
                    throw error;
                }
                _ = try await pubsubModule.createNode(at: pepJID, node: PEPBookmarksModule.ID, with: config);
                return try await pubsubModule.publishItem(at: nil, to: PEPBookmarksModule.ID, payload: bookmarks.toElement(), publishOptions: config)
            }
            try await pubsubModule.configureNode(at: pepJID, node: PEPBookmarksModule.ID, with: config);
            return try await pubsubModule.publishItem(at: nil, to: PEPBookmarksModule.ID, payload: bookmarks.toElement(), publishOptions: config)
        }
    }
    
    private func serverInfoChanged(_ info: DiscoveryModule.DiscoveryInfoResult) {
        if let context = context, info.identities.contains(where: { (identity) -> Bool in
            if let name = identity.name, "ejabberd" == name {
                // ejabberd has buggy PEP support, we need to request Bookmarks on our own!!
                return true;
            }
            return false;
        }) {
            // requesting Bookmarks!!
            let pepJID = context.userBareJid;
            Task {
                let items = try await self.pubsubModule.retrieveItems(from: pepJID, for: PEPBookmarksModule.ID, limit: .lastItems(1));
                if let item = items.items.first {
                    if let bookmarks = Bookmarks(from: item.payload) {
                        self.currentBookmarks = bookmarks;
                    }
                }
            }
        }
    }
    
    open override func onItemNotification(notification: PubSubModule.ItemNotification) {
        guard let context = self.context else {
            return;
        }
        
        guard notification.message.from == nil || context.userBareJid == notification.message.from?.bareJid else {
            return;
        }
        
        switch notification.action {
        case .published(let item):
            if let bookmarks = Bookmarks(from: item.payload) {
                self.currentBookmarks = bookmarks;
            }
        case .retracted(_):
            break;
        }
    }

}

// async-await support
extension PEPBookmarksModule {
    
    public func addOrUpdate(bookmark item: BookmarksItem, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await addOrUpdate(bookmark: item)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func remove(bookmark item: BookmarksItem, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await remove(bookmark: item)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func setConferenceAutojoin(_ value: Bool, for jid: JID, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await setConferenceAutojoin(value, for: jid)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

    public func publish(bookmarks: Bookmarks, completionHandler: @escaping (Result<String,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await publish(bookmarks: bookmarks)));
            } catch {
                
            }
        }
    }
}

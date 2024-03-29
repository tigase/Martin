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

open class PEPBookmarksModule: AbstractPEPModule, XmppModule {
    
    public static let ID = "storage:bookmarks";
    public static let IDENTIFIER = XmppModuleIdentifier<PEPBookmarksModule>();
    
    public let criteria = Criteria.empty();
    
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
    
    open func addOrUpdate(bookmark item: Bookmarks.Item, completionHandler: ((PubSubPublishItemResult)->Void)? = nil) {
        if let updated = currentBookmarks.updateOrAdd(bookmark: item) {
            self.publish(bookmarks: updated, completionHandler: completionHandler);
        }
    }
    
    open func remove(bookmark item: Bookmarks.Item, completionHandler: ((PubSubPublishItemResult)->Void)? = nil) {
        if let updated = currentBookmarks.remove(bookmark: item) {
            self.publish(bookmarks: updated, completionHandler: completionHandler);
        }
    }
    
    open func setConferenceAutojoin(_ value: Bool, for jid: JID) {
        guard let conference = self.currentBookmarks.conference(for: jid), conference.autojoin != value else {
            return;
        }
        addOrUpdate(bookmark: conference.with(autojoin: value));
    }
    
    public func process(stanza: Stanza) throws {
        throw XMPPError.feature_not_implemented;
    }
    
    public func publish(bookmarks: Bookmarks, completionHandler: ((PubSubPublishItemResult)->Void)? = nil) {
        guard let context = context else {
            completionHandler?(.failure(PubSubError.undefined_condition));
            return;
        }
        let pepJID = JID(context.userBareJid);
        discoModule.getInfo(for: pepJID, node: PEPBookmarksModule.ID, completionHandler: { result in
            switch result {
            case .success(_):
                self.pubsubModule.publishItem(at: nil, to: PEPBookmarksModule.ID, payload: bookmarks.toElement(), completionHandler: completionHandler ?? { _ in });
            case .failure(let error):
                switch error {
                case .item_not_found:
                    let config = PubSubNodeConfig();
                    config.FORM_TYPE = "http://jabber.org/protocol/pubsub#node_config";
                    config.persistItems = true;
                    config.accessModel = .whitelist;
                    self.pubsubModule.createNode(at: pepJID.bareJid, node: PEPBookmarksModule.ID, with: config, completionHandler: { result in
                        switch result {
                        case .success(_):
                            self.pubsubModule.publishItem(at: nil, to: PEPBookmarksModule.ID, payload: bookmarks.toElement(), completionHandler: completionHandler ?? { _ in});
                        case .failure(let err):
                            completionHandler?(.failure(err));
                        }
                    });
                default:
                    completionHandler?(.failure(PubSubError.remote_server_timeout))
                }
            }
        });
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
            self.pubsubModule.retrieveItems(from: pepJID, for: PEPBookmarksModule.ID, limit: .lastItems(1), completionHandler: { result in
                switch result {
                case .success(let items):
                    if let item = items.items.first {
                        if let bookmarks = Bookmarks(from: item.payload) {
                            self.currentBookmarks = bookmarks;
                            self.fire(BookmarksChangedEvent(context: context, bookmarks: bookmarks));
                        }
                    }
                default:
                    break;
                }
            });
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
                self.fire(BookmarksChangedEvent(context: context, bookmarks: bookmarks));
            }
        case .retracted(_):
            break;
        }
    }

    open class BookmarksChangedEvent: AbstractEvent {
        public static let TYPE = BookmarksChangedEvent();
        
        public let bookmarks: Bookmarks!;
        
        init() {
            self.bookmarks = nil;
            super.init(type: "PEPBookmarksChanged");
        }
        
        init(context: Context, bookmarks: Bookmarks) {
            self.bookmarks = bookmarks;
            super.init(type: "PEPBookmarksChanged", context: context);
        }
        
    }
}

// async-await support
extension PEPBookmarksModule {
    
    open func addOrUpdate(bookmark item: Bookmarks.Item) async throws {
        _ = try await withUnsafeThrowingContinuation { continuation in
            addOrUpdate(bookmark: item, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func remove(bookmark item: Bookmarks.Item) async throws {
        _ = try await withUnsafeThrowingContinuation { continuation in
            remove(bookmark: item, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func setConferenceAutojoin(_ value: Bool, for jid: JID) async throws {
        guard let conference = self.currentBookmarks.conference(for: jid), conference.autojoin != value else {
            throw PubSubError(error: .item_not_found, pubsubErrorCondition: nil);
        }
        try await addOrUpdate(bookmark: conference.with(autojoin: value));
    }
    
    public func publish(bookmarks: Bookmarks) async throws -> String {
        return try await withUnsafeThrowingContinuation { continuation in
            publish(bookmarks: bookmarks, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
}

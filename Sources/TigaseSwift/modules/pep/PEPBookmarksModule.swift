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
    
    open func addOrUpdate(bookmark item: Bookmarks.Item) {
        if let updated = currentBookmarks.updateOrAdd(bookmark: item) {
            self.publish(bookmarks: updated);
        }
    }
    
    open func remove(bookmark item: Bookmarks.Item) {
        if let updated = currentBookmarks.remove(bookmark: item) {
            self.publish(bookmarks: updated);
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
    
    public func publish(bookmarks: Bookmarks) {
        guard let context = context else {
            return;
        }
        let pepJID = JID(context.userBareJid);
        discoModule.getInfo(for: pepJID, node: PEPBookmarksModule.ID, completionHandler: { result in
            switch result {
            case .success(_):
                self.pubsubModule.publishItem(at: nil, to: PEPBookmarksModule.ID, payload: bookmarks.toElement(), completionHandler: { _ in });
            case .failure(let error):
                switch error {
                case .item_not_found:
                    let config = PubSubNodeConfig();
                    config.FORM_TYPE = "http://jabber.org/protocol/pubsub#node_config";
                    config.persistItems = true;
                    config.accessModel = .whitelist;
                    self.pubsubModule.createNode(at: pepJID.bareJid, node: PEPBookmarksModule.ID, with: config, completionHandler: { result in
                        switch result {
                        case .success(let node):
                            guard node == PEPBookmarksModule.ID else {
                                return;
                            }
                            self.pubsubModule.publishItem(at: nil, to: PEPBookmarksModule.ID, payload: bookmarks.toElement(), completionHandler: { _ in});
                        default:
                            break;
                        }
                    });
                default:
                    break;
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
            }
        case .retracted(_):
            break;
        }
    }

}

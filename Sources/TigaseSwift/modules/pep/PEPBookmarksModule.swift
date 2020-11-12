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

extension XmppModuleIdentifier {
    public static var pepBookmarks: XmppModuleIdentifier<PEPBookmarksModule> {
        return PEPBookmarksModule.IDENTIFIER;
    }
}

open class PEPBookmarksModule: XmppModuleBase, AbstractPEPModule {
    
    public static let ID = "storage:bookmarks";
    public static let IDENTIFIER = XmppModuleIdentifier<PEPBookmarksModule>();
    
    public let criteria = Criteria.empty();
    
    public let features: [String] = [ ID + "+notify" ];
    
    public fileprivate(set) var currentBookmarks: Bookmarks = Bookmarks();
    
    open override weak var context: Context? {
        didSet {
            if let oldValue = oldValue {
                oldValue.eventBus.unregister(handler: self, for: PubSubModule.NotificationReceivedEvent.TYPE, DiscoveryModule.ServerFeaturesReceivedEvent.TYPE);
            }
            if let context = context {
                context.eventBus.register(handler: self, for: PubSubModule.NotificationReceivedEvent.TYPE, DiscoveryModule.ServerFeaturesReceivedEvent.TYPE);
                discoModule = context.modulesManager.module(.disco);
                pubsubModule = context.modulesManager.module(.pubsub);
            } else {
                discoModule = nil;
                pubsubModule = nil;
            }
        }
    }
    
    private var discoModule: DiscoveryModule!;
    private var pubsubModule: PubSubModule!;
    
    public override init() {
        
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
                    let config = JabberDataElement(type: .submit);
                    let formType = HiddenField(name: "FORM_TYPE");
                    formType.value = "http://jabber.org/protocol/pubsub#node_config";
                    config.addField(formType);
                    config.addField(BooleanField(name: "pubsub#persist_items", label: nil, desc: nil, required: false, value: true));
                    config.addField(TextSingleField(name: "pubsub#access_model", label: nil, desc: nil, required: false, value: "whitelist"));
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
    
    public func handle(event: Event) {
        switch event {
        case let e as DiscoveryModule.ServerFeaturesReceivedEvent:
            if let context = context, e.identities.contains(where: { (identity) -> Bool in
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
                                self.fire(BookmarksChangedEvent(context: e.context, bookmarks: bookmarks));
                            }
                        }
                    default:
                        break;
                    }
                });
            }
            
        case let e as PubSubModule.NotificationReceivedEvent:
            guard let from = e.message.from?.bareJid, context?.userBareJid == from else {
                return;
            }
            if let bookmarks = Bookmarks(from: e.payload) {
                self.currentBookmarks = bookmarks;
                self.fire(BookmarksChangedEvent(context: e.context, bookmarks: bookmarks));
            }
        default:
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

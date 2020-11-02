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

open class PEPBookmarksModule: AbstractPEPModule {
    
    public static let ID = "storage:bookmarks";
    public static let IDENTIFIER = XmppModuleIdentifier<PEPBookmarksModule>();
    
    public let criteria = Criteria.empty();
    
    public let features: [String] = [ ID + "+notify" ];
    
    public fileprivate(set) var currentBookmarks: Bookmarks = Bookmarks();
    
    open var context: Context! {
        didSet {
            if oldValue != nil {
                oldValue.eventBus.unregister(handler: self, for: PubSubModule.NotificationReceivedEvent.TYPE, DiscoveryModule.ServerFeaturesReceivedEvent.TYPE);
            }
            if context != nil {
                context.eventBus.register(handler: self, for: PubSubModule.NotificationReceivedEvent.TYPE, DiscoveryModule.ServerFeaturesReceivedEvent.TYPE);
                discoModule = context.modulesManager.module(.disco);
                pubsubModule = context.modulesManager.module(.pubsub);
            } else {
                discoModule = nil;
                pubsubModule = nil;
            }
        }
    }
    
    var discoModule: DiscoveryModule!;
    var pubsubModule: PubSubModule!;
    
    public init() {
        
    }
 
    public func process(stanza: Stanza) throws {
        throw ErrorCondition.bad_request;
    }
    
    public func publish(bookmarks: Bookmarks) {
        let pepJID = JID(context.sessionObject.userBareJid!);
        discoModule.getInfo(for: pepJID, node: PEPBookmarksModule.ID, onInfoReceived: { (node, identities, features) in
            self.pubsubModule.publishItem(at: nil, to: PEPBookmarksModule.ID, payload: bookmarks.toElement(), callback: nil);
        }) { (error) in
            if (error ?? ErrorCondition.remote_server_timeout) == .item_not_found {
                let config = JabberDataElement(type: .submit);
                let formType = HiddenField(name: "FORM_TYPE");
                formType.value = "http://jabber.org/protocol/pubsub#node_config";
                config.addField(formType);
                config.addField(BooleanField(name: "pubsub#persist_items", label: nil, desc: nil, required: false, value: true));
                config.addField(TextSingleField(name: "pubsub#access_model", label: nil, desc: nil, required: false, value: "whitelist"));
                self.pubsubModule.createNode(at: pepJID.bareJid, node: PEPBookmarksModule.ID, with: config, onSuccess: { (stanza: Stanza, node: String)->Void in
                    guard node == PEPBookmarksModule.ID else {
                        return;
                    }
                    self.pubsubModule.publishItem(at: nil, to: PEPBookmarksModule.ID, payload: bookmarks.toElement(), callback: nil);
                }, onError: nil);
            }
        }
        
        
    }
    
    public func handle(event: Event) {
        switch event {
        case let e as DiscoveryModule.ServerFeaturesReceivedEvent:
            if e.identities.contains(where: { (identity) -> Bool in
                if let name = identity.name, "ejabberd" == name {
                    // ejabberd has buggy PEP support, we need to request Bookmarks on our own!!
                    return true;
                }
                return false;
            }) {
                // requesting Bookmarks!!
                let pepJID = context.sessionObject.userBareJid!;
                pubsubModule.retrieveItems(from: pepJID, for: PEPBookmarksModule.ID, rsm: nil, lastItems: 1, itemIds: nil, onSuccess: { (stanza, node, items, rsm) in
                    if let item = items.first {
                        if let bookmarks = Bookmarks(from: item.payload) {
                            self.currentBookmarks = bookmarks;
                            self.context.eventBus.fire(BookmarksChangedEvent(sessionObject: e.sessionObject, bookmarks: bookmarks));
                        }
                    }
                }, onError: nil);
            }
            
        case let e as PubSubModule.NotificationReceivedEvent:
            guard let from = e.message.from?.bareJid, let account = e.sessionObject.userBareJid, from == account else {
                return;
            }
            if let bookmarks = Bookmarks(from: e.payload) {
                self.currentBookmarks = bookmarks;
                context.eventBus.fire(BookmarksChangedEvent(sessionObject: e.sessionObject, bookmarks: bookmarks));
            }
        default:
            break;
        }
    }

    open class BookmarksChangedEvent: Event {
        public static let TYPE = BookmarksChangedEvent();
        
        public let type = "PEPBookmarksChanged";
        
        public let sessionObject: SessionObject!;
        public let bookmarks: Bookmarks!;
        
        init() {
            self.sessionObject = nil;
            self.bookmarks = nil;
        }
        
        init(sessionObject: SessionObject, bookmarks: Bookmarks) {
            self.sessionObject = sessionObject;
            self.bookmarks = bookmarks;
        }
        
    }
}

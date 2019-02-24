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

open class PEPBookmarksModule: AbstractPEPModule {
    
    public static let ID = "storage:bookmarks";
    
    public let criteria = Criteria.empty();
    
    public let features: [String] = [ ID + "+notify" ];
    
    public let id = ID;
    
    public fileprivate(set) var currentBookmarks: Bookmarks = Bookmarks();
    
    open var context: Context! {
        didSet {
            if oldValue != nil {
                oldValue.eventBus.unregister(handler: self, for: PubSubModule.NotificationReceivedEvent.TYPE);
            }
            if context != nil {
                context.eventBus.register(handler: self, for: PubSubModule.NotificationReceivedEvent.TYPE);
            }
        }
    }
    
    public init() {
        
    }
 
    public func process(stanza: Stanza) throws {
        throw ErrorCondition.bad_request;
    }
    
    public func publish(bookmarks: Bookmarks) {
        guard let discoModule: DiscoveryModule = context.modulesManager.getModule(DiscoveryModule.ID), let pubsubModule: PubSubModule = context.modulesManager.getModule(PubSubModule.ID) else {
            return;
        }
        
        let pepJID = JID(context.sessionObject.userBareJid!);
        discoModule.getInfo(for: pepJID, node: PEPBookmarksModule.ID, onInfoReceived: { (node, identities, features) in
            pubsubModule.publishItem(at: nil, to: PEPBookmarksModule.ID, payload: bookmarks.toElement(), callback: nil);
        }) { (error) in
            if (error ?? ErrorCondition.remote_server_timeout) == .item_not_found {
                let config = JabberDataElement(type: .submit);
                let formType = HiddenField(name: "FORM_TYPE");
                formType.value = "http://jabber.org/protocol/pubsub#node_config";
                config.addField(formType);
                config.addField(BooleanField(name: "pubsub#persist_items", label: nil, desc: nil, required: false, value: true));
                config.addField(TextSingleField(name: "pubsub#access_model", label: nil, desc: nil, required: false, value: "whitelist"));
                pubsubModule.createNode(at: pepJID.bareJid, node: PEPBookmarksModule.ID, with: config, onSuccess: { (stanza: Stanza, node: String)->Void in
                    guard node == PEPBookmarksModule.ID else {
                        return;
                    }
                    pubsubModule.publishItem(at: nil, to: PEPBookmarksModule.ID, payload: bookmarks.toElement(), callback: nil);
                }, onError: nil);
            }
        }
        
        
    }
    
    public func handle(event: Event) {
        switch event {
        case let e as PubSubModule.NotificationReceivedEvent:
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

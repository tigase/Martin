//
// PEPUserAvatar.swift
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

open class PEPUserAvatarModule: AbstractPEPModule {

    public static let METADATA_XMLNS = ID + ":metadata";
    public static let DATA_XMLNS = ID + ":data";
    
    public static let ID = "urn:xmpp:avatar";
    
    public static let FEATURES_NOTIFY = [ METADATA_XMLNS + "+notify" ];
    public static let FEATURES_NONE = [String]();
    
    public let id = ID;
    
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
    
    public let criteria = Criteria.empty();
    
    open var listenForAvatarChanges: Bool = true;
    
    open var features: [String] {
        get {
            if listenForAvatarChanges {
                return PEPUserAvatarModule.FEATURES_NOTIFY;
            } else {
                return PEPUserAvatarModule.FEATURES_NONE;
            }
        }
    }
    
    public init() {
        
    }
    
    open func process(stanza: Stanza) throws {
        throw ErrorCondition.bad_request;
    }
    
    open func publishAvatar(data: Data, mimeType: String, width: Int? = nil, height: Int? = nil, onSuccess: @escaping ()->Void, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        let id = Digest.sha1.digest(toHex: data)!;
        let size = data.count;
        let value = data.base64EncodedString();
        
        guard let pubsubModule: PubSubModule = context.modulesManager.getModule(PubSubModule.ID) else {
            print("Required PubSubModule is not registered!");
            return;
        }
        pubsubModule.publishItem(at: nil, to: PEPUserAvatarModule.DATA_XMLNS, payload: Element(name: "data", cdata: value, xmlns: PEPUserAvatarModule.DATA_XMLNS), onSuccess: { (stanza,node,itemId) in
            self.publishAvatarMetaData(id: itemId ?? id, mimeType: mimeType, size: size, width: width, height: height, onSuccess: onSuccess, onError: onError);
            }, onError: onError);
    }
    
    open func retractAvatar(onSuccess: @escaping ()->Void, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        guard let pubsubModule: PubSubModule = context.modulesManager.getModule(PubSubModule.ID) else {
            print("Required PubSubModule is not registered!");
            return;
        }
        
        let metadata = Element(name: "metadata", xmlns: PEPUserAvatarModule.METADATA_XMLNS);
        pubsubModule.publishItem(at: nil, to: PEPUserAvatarModule.METADATA_XMLNS, payload: metadata, onSuccess: { (stanza,node,itemId) in onSuccess(); }, onError: onError);
    }
    
    open func publishAvatarMetaData(id: String, mimeType: String, size: Int, width: Int? = nil, height: Int? = nil, url: String? = nil, onSuccess: @escaping ()->Void, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        guard let pubsubModule: PubSubModule = context.modulesManager.getModule(PubSubModule.ID) else {
            print("Required PubSubModule is not registered!");
            return;
        }
        
        let metadata = Element(name: "metadata", xmlns: PEPUserAvatarModule.METADATA_XMLNS);
        let info = Element(name: "info");
        info.setAttribute("id", value: id);
        info.setAttribute("bytes", value: String(size));
        info.setAttribute("type", value: mimeType);
        if width != nil {
            info.setAttribute("width", value: String(width!));
        }
        if height != nil {
            info.setAttribute("height", value: String(height!));
        }
        if url != nil {
            info.setAttribute("url", value: url);
        }
        metadata.addChild(info);
        
        pubsubModule.publishItem(at: nil, to: PEPUserAvatarModule.METADATA_XMLNS, payload: metadata, onSuccess: { (stanza,node,itemId) in onSuccess(); }, onError: onError);
    }
    
    open func retrieveAvatar(from jid: BareJID, itemId: String, onSuccess: @escaping (BareJID,String,Data?)->Void, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        guard let pubsubModule: PubSubModule = context.modulesManager.getModule(PubSubModule.ID) else {
            print("Required PubSubModule is not registered!");
            return;
        }
        
        pubsubModule.retrieveItems(from: jid, for: PEPUserAvatarModule.DATA_XMLNS, itemIds: [itemId], onSuccess: { (stanza,node,items,rsm) in
            var data: Data? = nil;
            if let cdata = items.first?.payload.value {
                data = Data(base64Encoded: cdata, options: NSData.Base64DecodingOptions(rawValue: 0))
            }
            onSuccess(stanza.from?.bareJid ?? jid, items.first?.id ?? itemId, data);
            }, onError: onError);
    }
    
    public func handle(event: Event) {
        switch event {
        case let nre as PubSubModule.NotificationReceivedEvent:
            guard nre.nodeName == PEPUserAvatarModule.METADATA_XMLNS else {
                return;
            }
            
            onAvatarChangeNotification(sessionObject: nre.sessionObject, from: nre.message.from!, itemId: nre.itemId!, payload: nre.payload!);
        default:
            break;
        }
    }
    
    open func onAvatarChangeNotification(sessionObject: SessionObject, from: JID, itemId: String, payload: Element) {
        let info: [Info] = payload.mapChildren(transform: { (elem) in
            guard let size = elem.getAttribute("bytes"), let id = elem.getAttribute("id"), let type = elem.getAttribute("type") else {
                return nil;
            }
            return Info(size: Int(size)!, height: Int(elem.getAttribute("height") ?? ""), id: id, mimeType: type, url: elem.getAttribute("url"), width: Int(elem.getAttribute("width") ?? ""));
        }, filter: { (elem) -> Bool in
            return elem.name == "info";
        });
        
        context.eventBus.fire(AvatarChangedEvent(sessionObject: sessionObject, jid: from, itemId: itemId, info: info));
    }
    
    public struct Info {
        public let size: Int;
        public let height: Int?;
        public let id: String;
        public let mimeType: String;
        public let url: String?;
        public let width: Int?;
    }
    
    open class AvatarChangedEvent: Event {
        public static let TYPE = AvatarChangedEvent();
        
        public let type = "PEPAvatarChanged";
        
        public let sessionObject: SessionObject!;
        public let jid: JID!
        public let itemId: String!;
        public let info: [PEPUserAvatarModule.Info]!;
        
        init() {
            self.sessionObject = nil;
            self.jid = nil;
            self.itemId = nil;
            self.info = nil;
        }
        
        init(sessionObject: SessionObject, jid: JID, itemId: String, info: [PEPUserAvatarModule.Info]) {
            self.sessionObject = sessionObject;
            self.jid = jid;
            self.itemId = itemId;
            self.info = info;
        }
    }
}

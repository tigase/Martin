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
import Combine

extension XmppModuleIdentifier {
    public static var pepUserAvatar: XmppModuleIdentifier<PEPUserAvatarModule> {
        return PEPUserAvatarModule.IDENTIFIER;
    }
}

open class PEPUserAvatarModule: AbstractPEPModule, XmppModule {

    public static let METADATA_XMLNS = ID + ":metadata";
    public static let DATA_XMLNS = ID + ":data";
    
    public static let ID = "urn:xmpp:avatar";
    public static let IDENTIFIER = XmppModuleIdentifier<PEPUserAvatarModule>();
    
    public static let FEATURES_NOTIFY = [ METADATA_XMLNS + "+notify" ];
    public static let FEATURES_NONE = [String]();
    
    public let criteria = Criteria.empty();
    
    open var listenForAvatarChanges: Bool = true;
    
    public let avatarChangePublisher = PassthroughSubject<AvatarChange,Never>();
    
    open var features: [String] {
        get {
            if listenForAvatarChanges {
                return PEPUserAvatarModule.FEATURES_NOTIFY;
            } else {
                return PEPUserAvatarModule.FEATURES_NONE;
            }
        }
    }
    
    public override init() {
        
    }
    
    open func process(stanza: Stanza) throws {
        throw XMPPError.feature_not_implemented;
    }

    open func publishAvatar(at: BareJID? = nil, data: Data, mimeType: String, width: Int? = nil, height: Int? = nil, completionHandler: @escaping (PubSubPublishItemResult)->Void) {
        let id = Digest.sha1.digest(toHex: data)!;
        let size = data.count;
        let value = data.base64EncodedString();
        
        pubsubModule.publishItem(at: at, to: PEPUserAvatarModule.DATA_XMLNS, itemId: id, payload: Element(name: "data", cdata: value, xmlns: PEPUserAvatarModule.DATA_XMLNS), completionHandler: { result in
            switch result {
            case .success(let itemId):
                self.publishAvatarMetaData(at: at, id: itemId, mimeType: mimeType, size: size, width: width, height: height, completionHandler: completionHandler);
            case .failure(_):
                completionHandler(result);
            }
        });
    }

    open func retractAvatar(from: BareJID? = nil, completionHandler: @escaping (PubSubPublishItemResult)->Void) {
        let metadata = Element(name: "metadata", xmlns: PEPUserAvatarModule.METADATA_XMLNS);
        pubsubModule.publishItem(at: from, to: PEPUserAvatarModule.METADATA_XMLNS, payload: metadata, completionHandler: completionHandler);
    }

    open func publishAvatarMetaData(at: BareJID? = nil, id: String, mimeType: String, size: Int, width: Int? = nil, height: Int? = nil, url: String? = nil, completionHandler: @escaping (PubSubPublishItemResult)->Void) {
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
        
        pubsubModule.publishItem(at: at, to: PEPUserAvatarModule.METADATA_XMLNS, payload: metadata, completionHandler: completionHandler);
    }

    open func retrieveAvatar(from jid: BareJID, itemId: String, completionHandler: @escaping (Result<(String,Data),XMPPError>)->Void) {
        pubsubModule.retrieveItems(from: jid, for: PEPUserAvatarModule.DATA_XMLNS, limit: .items(withIds: [itemId]), completionHandler: { result in
            switch result {
            case .success(let items):
                if let item = items.items.first, let cdata = item.payload?.value, let data = Data(base64Encoded: cdata, options: []) {
                    completionHandler(.success((item.id, data)));
                } else {
                    completionHandler(.failure(.item_not_found));
                }
            case .failure:
                completionHandler(.failure(.item_not_found));
            }
        })
    }
    
    open func retrieveAvatarMetadata(from jid: BareJID, itemId: String? = nil, fireEvents: Bool = true, completionHandler: @escaping (Result<Info,XMPPError>)->Void) {
        let limit: PubSubModule.QueryLimit = itemId == nil ? .lastItems(1) : .items(withIds: [itemId!]);
        pubsubModule.retrieveItems(from: jid, for: PEPUserAvatarModule.METADATA_XMLNS, limit: limit, completionHandler: { result in
            switch result {
            case .success(let items):
                guard let item = items.items.first, let info = item.payload?.mapChildren(transform: { Info(payload: $0)}).first else {
                    completionHandler(.failure(.item_not_found));
                    return;
                }
                if let context = self.context {
                    self.fire(AvatarChangedEvent(context: context, jid: JID(jid), itemId: item.id, info: [info]));
                }
                completionHandler(.success(info));
            case .failure(let pubsubError):
                completionHandler(.failure(pubsubError.error));
            }
        });
    }

    open override func onItemNotification(notification: PubSubModule.ItemNotification) {
        guard notification.node == PEPUserAvatarModule.METADATA_XMLNS, let context = self.context else {
            return;
        }
        
        switch notification.action {
        case .published(let item):
            onAvatarChangeNotification(context: context, from: notification.message.from!, itemId: item.id, payload: item.payload);
        case .retracted(_):
            break;
        }
    }
    
    open func onAvatarChangeNotification(context: Context, from: JID, itemId: String, payload: Element?) {
        guard let info: [Info] = payload?.mapChildren(transform: Info.init(payload: ), filter: { (elem) -> Bool in
            return elem.name == "info";
        }) else {
            return;
        }
        
        avatarChangePublisher.send(.init(jid: from, itemId: itemId, info: info));
        context.eventBus.fire(AvatarChangedEvent(context: context, jid: from, itemId: itemId, info: info));
    }
    
    public struct AvatarData {
        public let id: String;
        public let data: Data;
    }
    
    public struct Info {
        public let size: Int;
        public let height: Int?;
        public let id: String;
        public let mimeType: String;
        public let url: String?;
        public let width: Int?;
        
        public init?(payload: Element?) {
            guard let elem = payload, let sizeStr = elem.getAttribute("bytes"), let size = Int(sizeStr), let id = elem.getAttribute("id"), let type = elem.getAttribute("type") else {
                return nil;
            }
            self.init(id: id, size: size, mimeType: type, url: elem.getAttribute("url"), height: Int(elem.getAttribute("height") ?? ""), width: Int(elem.getAttribute("width") ?? ""));
        }
        
        public init(id: String, size: Int, mimeType: String, url: String?, height: Int?, width: Int?) {
            self.id = id;
            self.size = size;
            self.mimeType = mimeType;
            self.url = url;
            self.height = height;
            self.width = width;
        }
    }
    
    @available(*, deprecated, message: "Use PEPUserAvatarModule.avatarChangePublisher publisher")
    open class AvatarChangedEvent: AbstractEvent {
        public static let TYPE = AvatarChangedEvent();
        
        public let jid: JID!
        public let itemId: String!;
        public let info: [PEPUserAvatarModule.Info]!;
        
        init() {
            self.jid = nil;
            self.itemId = nil;
            self.info = nil;
            super.init(type: "PEPAvatarChanged");
        }
        
        init(context: Context, jid: JID, itemId: String, info: [PEPUserAvatarModule.Info]) {
            self.jid = jid;
            self.itemId = itemId;
            self.info = info;
            super.init(type: "PEPAvatarChanged", context: context);
        }
    }
    
    public struct AvatarChange {

        public let jid: JID;
        public let itemId: String;
        public let info: [PEPUserAvatarModule.Info];

    }
}

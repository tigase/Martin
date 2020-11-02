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

extension XmppModuleIdentifier {
    public static var pepUserAvatar: XmppModuleIdentifier<PEPUserAvatarModule> {
        return PEPUserAvatarModule.IDENTIFIER;
    }
}

open class PEPUserAvatarModule: AbstractPEPModule {

    public static let METADATA_XMLNS = ID + ":metadata";
    public static let DATA_XMLNS = ID + ":data";
    
    public static let ID = "urn:xmpp:avatar";
    public static let IDENTIFIER = XmppModuleIdentifier<PEPUserAvatarModule>();
    
    public static let FEATURES_NOTIFY = [ METADATA_XMLNS + "+notify" ];
    public static let FEATURES_NONE = [String]();
    
    open var context: Context! {
        didSet {
            if oldValue != nil {
                oldValue.eventBus.unregister(handler: self, for: PubSubModule.NotificationReceivedEvent.TYPE);
            }
            if context != nil {
                context.eventBus.register(handler: self, for: PubSubModule.NotificationReceivedEvent.TYPE);
                pubsubModule = context.modulesManager.module(.pubsub);
            } else {
                pubsubModule = nil;
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
    
    private var pubsubModule: PubSubModule!;
    
    public init() {
        
    }
    
    open func process(stanza: Stanza) throws {
        throw ErrorCondition.bad_request;
    }
    
    open func publishAvatar(at: BareJID? = nil, data: Data, mimeType: String, width: Int? = nil, height: Int? = nil, onSuccess: @escaping ()->Void, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        self.publishAvatar(at: at, data: data, mimeType: mimeType, width: width, height: height, completionHandler: { result in
            switch result {
            case .success(_, _, _):
                onSuccess();
            case .failure(let errorCondition, let pubSubErrorCondition, _):
                onError?(errorCondition, pubSubErrorCondition);
            }
        })
    }

    open func publishAvatar(at: BareJID? = nil, data: Data, mimeType: String, width: Int? = nil, height: Int? = nil, completionHandler: @escaping (PubSubPublishItemResult)->Void) {
        let id = Digest.sha1.digest(toHex: data)!;
        let size = data.count;
        let value = data.base64EncodedString();
        
        pubsubModule.publishItem(at: at, to: PEPUserAvatarModule.DATA_XMLNS, itemId: id, payload: Element(name: "data", cdata: value, xmlns: PEPUserAvatarModule.DATA_XMLNS), completionHandler: { result in
            switch result {
            case .success(_, _, let itemId):
                self.publishAvatarMetaData(at: at, id: itemId, mimeType: mimeType, size: size, width: width, height: height, completionHandler: completionHandler);
            case .failure(_, _, _):
                completionHandler(result);
            }
        });
    }

    open func retractAvatar(from: BareJID? = nil, onSuccess: @escaping ()->Void, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        self.retractAvatar(from: from, completionHandler: { result in
            switch result {
            case .success(_, _, _):
                onSuccess();
            case .failure(let errorCondition, let pubSubErrorCondition, _):
                onError?(errorCondition, pubSubErrorCondition);
            }
        })
    }

    open func retractAvatar(from: BareJID? = nil, completionHandler: @escaping (PubSubPublishItemResult)->Void) {
        let metadata = Element(name: "metadata", xmlns: PEPUserAvatarModule.METADATA_XMLNS);
        pubsubModule.publishItem(at: from, to: PEPUserAvatarModule.METADATA_XMLNS, payload: metadata, completionHandler: completionHandler);
    }

    open func publishAvatarMetaData(at: BareJID? = nil, id: String, mimeType: String, size: Int, width: Int? = nil, height: Int? = nil, url: String? = nil, onSuccess: @escaping ()->Void, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        self.publishAvatarMetaData(at: at, id: id, mimeType: mimeType, size: size, width: width, height: height, url: url, completionHandler: { result in
            switch result {
            case .success(_, _, _):
                onSuccess();
            case .failure(let errorCondition, let pubSubErrorCondition, _):
                onError?(errorCondition, pubSubErrorCondition);
            }
            
        });
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

    open func retrieveAvatar(from jid: BareJID, itemId: String? = nil, onSuccess: @escaping (BareJID,String,Data?)->Void, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        let itemIds: [String]? = itemId == nil ? nil : [itemId!];
        pubsubModule.retrieveItems(from: jid, for: PEPUserAvatarModule.DATA_XMLNS, itemIds: itemIds, onSuccess: { (stanza,node,items,rsm) in
            var data: Data? = nil;
            if let cdata = items.first?.payload?.value {
                data = Data(base64Encoded: cdata, options: NSData.Base64DecodingOptions(rawValue: 0))
            }
            onSuccess(stanza.from?.bareJid ?? jid, items.first?.id ?? itemId ?? "", data);
            }, onError: onError);
    }

    
    
    open func retrieveAvatarMetadata(from jid: BareJID, itemId: String? = nil, fireEvents: Bool = true, completionHandler: @escaping (Result<Info,ErrorCondition>)->Void) {
        let itemIds: [String]? = itemId == nil ? nil : [itemId!];
        pubsubModule.retrieveItems(from: jid, for: PEPUserAvatarModule.METADATA_XMLNS, itemIds: itemIds, completionHandler: { result in
            switch result {
            case .success(_, _, let items, _):
                guard let item = items.first, let info = item.payload?.mapChildren(transform: { Info(payload: $0)}).first else {
                    completionHandler(.failure(.item_not_found));
                    return;
                }
                self.context.eventBus.fire(AvatarChangedEvent(sessionObject: self.context.sessionObject, jid: JID(jid), itemId: item.id, info: [info]));
                completionHandler(.success(info));
            case .failure(let errorCondition, _, _):
                completionHandler(.failure(errorCondition));
            }
        });
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
        let info: [Info] = payload.mapChildren(transform: Info.init(payload: ), filter: { (elem) -> Bool in
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

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
    
    private let queue = DispatchQueue(label: "PEPUserAvatarModuleQueue");
    
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
    
    public struct Avatar {
        public let data: Data?;
        public let info: Info;
        
        public init(data: Data, mimeType: String, width: Int? = nil, height: Int? = nil) {
            self.data = data;
            self.info = Info(id: Digest.sha1.digest(toHex: data)!, size: data.count, mimeType: mimeType, height: height, width: width);
        }
        
        public init(id: String, url: String, size: Int, mimeType: String, width: Int? = nil, height: Int? = nil) {
            self.data = nil;
            self.info = Info(id: id, size: size, mimeType: mimeType, url: url, height: height, width: width);
        }
    }
    
    open func publishAvatar(at: BareJID? = nil, avatar avatars: [Avatar], completionHandler: @escaping(PubSubPublishItemResult)->Void) {
        queue.async {
            guard let pubsubModule = self.pubsubModule, let id = avatars.first(where: { $0.info.mimeType == "image/png" })?.info.id else {
                completionHandler(.failure(.init(error: .not_acceptable("Missing payload in image/png format!"), pubsubErrorCondition: .invalid_payload)));
                return;
            }
            
            let publish: (()->Void) = {
                let group = DispatchGroup();
                group.enter();
                var itemsError: PubSubError? = nil;
                for avatar in avatars {
                    if let data = avatar.data {
                        group.enter();
                        pubsubModule.publishItem(at: at, to: PEPUserAvatarModule.DATA_XMLNS, itemId: avatar.info.id, payload: Element(name: "data", cdata: data.base64EncodedString(), xmlns: PEPUserAvatarModule.DATA_XMLNS), completionHandler: { result in
                            self.queue.async {
                                switch result {
                                case .success(_):
                                    break;
                                case .failure(let error):
                                    itemsError = error;
                                }
                            }
                            group.leave();
                        });
                    }
                }
                group.notify(queue: self.queue, execute: {
                    if let error = itemsError {
                        completionHandler(.failure(error));
                    } else {
                        self.publishAvatarMetaData(at: at, id: id, metadata: avatars.map({ $0.info }), completionHandler: completionHandler);
                    }
                });
                group.leave();
            }
            
            // lets ensure we are allowed to have as many items published
            pubsubModule.retrieveNodeConfiguration(from: at, node: PEPUserAvatarModule.DATA_XMLNS, resultHandler: { result in
                switch result {
                case .success(let form):
                    if let limit = form.maxItems, limit < avatars.count {
                        // limit is too small, reconfiguring..
                        form.maxItems = .value(avatars.count);
                        pubsubModule.configureNode(at: at, node: PEPUserAvatarModule.DATA_XMLNS, with: form, completionHandler: { result in
                            switch result {
                            case .success(_):
                                publish();
                            case .failure(let error):
                                switch error.error.errorCondition {
                                case .not_acceptable:
                                    // let's try workaround for Openfire
                                    if let field: DataForm.Field = form.field(for: "pubsub#collection") {
                                        form.remove(field: field);
                                        pubsubModule.configureNode(at: at, node: PEPUserAvatarModule.DATA_XMLNS, with: form, completionHandler: { result in
                                            switch result {
                                            case .success(_):
                                                publish();
                                            case .failure(_):
                                                completionHandler(.failure(error));
                                            }
                                        });
                                    } else {
                                        completionHandler(.failure(error));
                                    }
                                default:
                                    completionHandler(.failure(error));
                                }
                            }
                        })
                    } else {
                        publish();
                    }
                case .failure(let error):
                     publish();
                }
            })
        }
    }

    @available(*, deprecated, message: "Use publishAvatar(at:, avatar, completionHandler:) instead")
    open func publishAvatar(at: BareJID? = nil, data: Data, mimeType: String, width: Int? = nil, height: Int? = nil, completionHandler: @escaping (PubSubPublishItemResult)->Void) {
        self.publishAvatar(at: at, avatar: [Avatar(data: data, mimeType: mimeType, width: width, height: height)], completionHandler: completionHandler);
    }

    open func retractAvatar(from: BareJID? = nil, completionHandler: @escaping (PubSubPublishItemResult)->Void) {
        let metadata = Element(name: "metadata", xmlns: PEPUserAvatarModule.METADATA_XMLNS);
        pubsubModule.publishItem(at: from, to: PEPUserAvatarModule.METADATA_XMLNS, payload: metadata, completionHandler: completionHandler);
    }

    @available(*, deprecated, message: "Use publishAvatarMetaData(at:, id:, metadata, completionHandler:) instead")
    open func publishAvatarMetaData(at: BareJID? = nil, id: String, mimeType: String, size: Int, width: Int? = nil, height: Int? = nil, url: String? = nil, completionHandler: @escaping (PubSubPublishItemResult)->Void) {
        self.publishAvatarMetaData(at: at, id: id, metadata: [Info(id: id, size: size, mimeType: mimeType, url: url, height: height, width: width)], completionHandler: completionHandler);
    }
    
    open func publishAvatarMetaData(at: BareJID? = nil, id: String, metadata infos: [Info], completionHandler: @escaping (PubSubPublishItemResult)->Void) {
        let metadata = Element(name: "metadata", xmlns: PEPUserAvatarModule.METADATA_XMLNS);
        
        metadata.addChildren(infos.map({ $0.toElement() }));
        
        pubsubModule.publishItem(at: at, to: PEPUserAvatarModule.METADATA_XMLNS, itemId: id, payload: metadata, completionHandler: completionHandler);
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
            onAvatarChangeNotification(context: context, from: notification.message.from ?? JID(context.userBareJid), itemId: item.id, payload: item.payload);
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
        
        public init(id: String, size: Int, mimeType: String, url: String? = nil, height: Int? = nil, width: Int? = nil) {
            self.id = id;
            self.size = size;
            self.mimeType = mimeType;
            self.url = url;
            self.height = height;
            self.width = width;
        }
        
        public func toElement() -> Element {
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

            return info;
        }
    }
    
    public struct AvatarChange {

        public let jid: JID;
        public let itemId: String;
        public let info: [PEPUserAvatarModule.Info];

    }
}

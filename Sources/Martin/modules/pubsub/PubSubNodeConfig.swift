//
// PubSubNodeConfig.swift
//
// TigaseSwift
// Copyright (C) 2022 "Tigase, Inc." <office@tigase.com>
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

open class PubSubNodeConfig: DataFormWrapper {
    
    public enum AccessModel: String, DataFormEnum {
        case authorize
        case open
        case presence
        case roster
        case whitelist
    }
    
    public enum ChildrenAssociationPolicy: String, DataFormEnum {
        case all
        case owners
        case whitelist
    }
    
    public enum ItemReply: String, DataFormEnum {
        case owner
        case publisher
    }
    
    public enum NodeType: String, DataFormEnum {
        case leaf
        case collection
    }
    
    public enum NotificationType: String, DataFormEnum {
        case normal
        case headline
    }
    
    public enum PublishModel: String, DataFormEnum {
        case publishers
        case subscribers
        case open
    }

    public enum SendLastPublishedItem: String, DataFormEnum {
        case never
        case on_sub
        case on_sub_and_presence
    }
        
    @Field("pubsub#access_model")
    public var accessModel: AccessModel?;
    @Field("pubsub#body_xslt")
    public var bodyXslt: String?;
    @Field("pubsub#children_association_policy")
    public var childrenAssociationPolicy: ChildrenAssociationPolicy?;
    @Field("pubsub#children_association_whitelist")
    public var childrenAssociationWhitelist: [JID]?;
    @Field("pubsub#children")
    public var children: [String]?;
    @Field("pubsub#children_max")
    public var childrenMax: DataForm.IntegerOrMax?;
    @Field("pubsub#collection")
    public var collection: String?;
    @Field("pubsub#contact")
    public var contact: [JID]?;
    @Field("pubsub#dataform_xslt")
    public var dataformXslt: String?;
    @Field("pubsub#deliver_notifications")
    public var deliverNotifications: Bool?;
    @Field("pubsub#deliver_payloads")
    public var deliverPayloads: Bool?;
    @Field("pubsub#description")
    public var description: String?;
    @Field("pubsub#item_expire")
    public var itemExpire: DataForm.IntegerOrMax?;
    @Field("pubsub#itemreply")
    public var itemReply: ItemReply?;
    @Field("pubsub#language", type: .listSingle)
    public var language: String?
    @Field("pubsub#max_items")
    public var maxItems: DataForm.IntegerOrMax?;
    @Field("pubsub#max_payload_size")
    public var maxPayloadSize: Int?;
    @Field("pubsub#node_type")
    public var nodeType: NodeType?;
    @Field("pubsub#notification_type")
    public var notificationType: NotificationType?;
    @Field("pubsub#notify_config")
    public var notifyConfig: Bool?;
    @Field("pubsub#notify_delete")
    public var notifyDelete: Bool?;
    @Field("pubsub#notify_retract")
    public var notifyRetract: Bool?;
    @Field("pubsub#notify_sub")
    public var notifySub: Bool?;
    @Field("pubsub#persist_items")
    public var persistItems: Bool?;
    @Field("pubsub#presence_based_delivery")
    public var presence_based_delivery: Bool?;
    @Field("pubsub#publish_model")
    public var publishModel: PublishModel?;
    @Field("pubsub#purge_offline")
    public var purgeOffline: Bool?
    @Field("pubsub#roster_groups_allowed")
    public var rosterGroupsAllowed: [String]?;  //-- ListSingle!
    @Field("pubsub#send_last_published_item")
    public var sendLastPublishedItem: SendLastPublishedItem?;
    @Field("pubsub#tempsub")
    public var tempsub: Bool?;
    @Field("pubsub#title")
    public var title: String?;
    @Field("pubsub#type")
    public var type: String?;
    
    public init?(element: Element) {
        guard let form = DataForm(element: element) else {
            return nil;
        }
        super.init(form: form)
    }
    
    public override init(form: DataForm? = nil) {
        super.init(form: form);
    }
}

extension PubSubModule {
    
    open func createNode(at pubSubJid: BareJID, node nodeName: String?, with configuration: PubSubNodeConfig, completionHandler: @escaping (PubSubNodeCreationResult)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let create = Element(name: "create");
        if nodeName != nil {
            create.setAttribute("node", value: nodeName);
        }
        pubsub.addChild(create);
        
//        if configuration != nil {
            let configure = Element(name: "configure");
            configure.addChild(configuration.element(type: .submit, onlyModified: true));
            pubsub.addChild(configure);
//        }
        
        write(iq, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler(result.flatMap({ response in
                if let node = response.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.findChild(name: "create")?.getAttribute("node") ?? nodeName {
                    return .success(node);
                } else {
                    return .failure(.undefined_condition);
                }
            }))
        });
    }
    
    open func configureNode(at pubSubJid: BareJID?, node nodeName: String, with configuration: PubSubNodeConfig, completionHandler: @escaping (PubSubNodeConfigurationResult)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        if let jid = pubSubJid {
            iq.to = JID(jid);
        }
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);
        
        let configure = Element(name: "configure");
        configure.setAttribute("node", value: nodeName);
        configure.addChild(configuration.element(type: .submit, onlyModified: true));
        pubsub.addChild(configure);
        
        write(iq, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler(result.map({ _ in Void() }))
        });
    }
    
    open func requestDefaultNodeConfiguration(from pubSubJid: BareJID, resultHandler: @escaping (Result<PubSubNodeConfig,PubSubError>)->Void) {
        requestDefaultNodeConfiguration(from: pubSubJid, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            resultHandler(result.flatMap({ stanza in
                guard let defaultConfigElem = stanza.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS)?.findChild(name: "default")?.findChild(name: "x", xmlns: "jabber:x:data"), let config = PubSubNodeConfig(element: defaultConfigElem) else {
                    return .failure(.undefined_condition)
                }
                return .success(config);
            }))
        });
    }
    
    open func retrieveNodeConfiguration(from pubSubJid: BareJID?, node: String, resultHandler: @escaping (Result<PubSubNodeConfig,PubSubError>)->Void) {
        retrieveNodeConfiguration(from: pubSubJid, node: node, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            resultHandler(result.flatMap({ response in
                if let formElem = response.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS)?.findChild(name: "configure")?.findChild(name: "x", xmlns: "jabber:x:data"), let config = PubSubNodeConfig(element: formElem) {
                    return .success(config);
                } else {
                    return .failure(.undefined_condition);
                }
            }))
        })
    }

    open func publishItem(at pubSubJid: BareJID?, to nodeName: String, itemId: String? = nil, payload: Element?, publishOptions: PubSubNodeConfig, completionHandler: @escaping (PubSubPublishItemResult)->Void) {
        self.publishItem(at: pubSubJid, to: nodeName, itemId: itemId, payload: payload, publishOptions: publishOptions.element(type: .submit, onlyModified: true), errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler(result.flatMap({ response in
                guard let publishEl = response.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.findChild(name: "publish"), let id = publishEl.findChild(name: "item")?.getAttribute("id") else {
                    if let id = itemId {
                        return .success(id);
                    } else {
                        return .failure(.undefined_condition);
                    }
                }
                return .success(id);
            }))
        })
    }
    
    
}

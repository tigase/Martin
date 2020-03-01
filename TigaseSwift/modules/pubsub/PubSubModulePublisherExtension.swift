//
// PubSubModulePublisherExtension.swift
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

public protocol PubSubModulePublisherExtension: class, ContextAware {
    
    func createCallback(onSuccess: ((Stanza)->Void)?, onError: ((ErrorCondition?, PubSubErrorCondition?) -> Void)?) -> ((Stanza?)->Void)?;
    
}

public enum PubSubPublishItemResult {
    case success(response: Stanza, node: String, itemId: String)
    case failure(errorCondition: ErrorCondition, pubSubErrorCondition: PubSubErrorCondition?, response: Stanza?);
}

extension PubSubModulePublisherExtension {
        
    /**
     Publish item to PubSub node
     - parameter at: jid of PubSub service
     - parameter to: node name
     - parameter itemId: id of item
     - parameter payload: item payload
     - parameter publishOptions: publish options
     - parameter completionHandler: called on completion
     */
    public func publishItem(at pubSubJid: BareJID?, to nodeName: String, itemId: String? = nil, payload: Element, publishOptions: JabberDataElement? = nil, completionHandler: @escaping (PubSubPublishItemResult)->Void) {
        let callback: (Stanza?)->Void = { stanza in
            guard let response = stanza else {
                completionHandler(.failure(errorCondition: .remote_server_timeout, pubSubErrorCondition: nil, response: nil));
                return;
            }
            switch response.type ?? .error {
            case .result:
                guard let publishEl = response.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.findChild(name: "publish"), let node = publishEl.getAttribute("node"), let id = publishEl.findChild(name: "item")?.getAttribute("id") else {
                    completionHandler(.failure(errorCondition: .undefined_condition, pubSubErrorCondition: .unsupported, response: response));
                    return;
                }
                completionHandler(.success(response: response, node: node, itemId: id));
            default:
                let pubsubError = response.findChild(name: "error")?.findChild(xmlns: PubSubModule.PUBSUB_ERROR_XMLNS);
                completionHandler(.failure(errorCondition: response.errorCondition ?? .remote_server_timeout, pubSubErrorCondition: pubsubError == nil ? nil : PubSubErrorCondition(rawValue: pubsubError!.name), response: response));
            }
        }

        self.publishItem(at: pubSubJid, to: nodeName, itemId: itemId, payload: payload, publishOptions: publishOptions, callback: callback);
    }
    
    /**
     Publish item to PubSub node
     - parameter at: jid of PubSub service
     - parameter to: node name
     - parameter itemId: id of item
     - parameter payload: item payload
     - parameter publishOptions: publish options
     - parameter onSuccess: called when request succeeds - passes instance of response stanza, node name and item id
     - parameter onError: called when request failed - passes general and detailed error condition if available
     */
    public func publishItem(at pubSubJid: BareJID?, to nodeName: String, itemId: String? = nil, payload: Element, publishOptions: JabberDataElement? = nil, onSuccess: ((Stanza,String,String?)->Void)?, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        let callback = createCallback(onSuccess: { (stanza) in
            guard let publishEl = stanza.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.findChild(name: "publish"), let node = publishEl.getAttribute("node") else {
                onError?(ErrorCondition.undefined_condition, PubSubErrorCondition.unsupported);
                return;
            }
            
            let itemId = publishEl.findChild(name: "item")?.getAttribute("id");
            
            onSuccess?(stanza, node, itemId);
        }, onError: onError);
    
        self.publishItem(at: pubSubJid, to: nodeName, itemId: itemId, payload: payload, publishOptions: publishOptions, callback: callback);
    }
    
    /**
     Publish item to PubSub node
     - parameter at: jid of PubSub service
     - parameter to: node name
     - parameter itemId: id of item
     - parameter payload: item payload
     - parameter publishOptions: publish options
     - parameter callback: called when response is received or request times out
     */
    public func publishItem(at pubSubJid: BareJID?, to nodeName: String, itemId: String? = nil, payload: Element, publishOptions: JabberDataElement? = nil, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.set;
        if pubSubJid != nil {
            iq.to = JID(pubSubJid!);
        }
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let publish = Element(name: "publish");
        publish.setAttribute("node", value: nodeName);
        pubsub.addChild(publish);
        
        let item = Element(name: "item");
        item.setAttribute("id", value: itemId);
        publish.addChild(item);
        
        item.addChild(payload);
        
        if publishOptions != nil {
            let publishOptionsEl = Element(name: "publish-options");
            publishOptionsEl.addChild(publishOptions!.submitableElement(type: .submit));
            pubsub.addChild(publishOptionsEl);
        }
        
        context.writer?.write(iq, callback: callback);
    }
    
    /**
     Retract item from PubSub node
     - parameter at: jid of PubSub service
     - parameter from: node name
     - parameter itemId: id of item
     - parameter onSuccess: called when request succeeds - passes instance of response stanza
     - parameter onError: called when request failed - passes general and detailed error condition if available
     */
    public func retractItem(at pubSubJid: BareJID?, from nodeName: String, itemId: String, onSuccess: ((Stanza)->Void)?, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        let callback = createCallback(onSuccess: onSuccess, onError: onError);
        
        self.retractItem(at: pubSubJid, from: nodeName, itemId: itemId, callback: callback);
    }
    
    /**
     Retract item from PubSub node
     - parameter at: jid of PubSub service
     - parameter from: node name
     - parameter itemId: id of item
     - parameter callback: called when response is received or request times out
     */
    public func retractItem(at pubSubJid: BareJID?, from nodeName: String, itemId: String, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.set;
        if pubSubJid != nil {
            iq.to = JID(pubSubJid!);
        }
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let retract = Element(name: "retract");
        retract.setAttribute("node", value: nodeName);
        pubsub.addChild(retract);
        
        let item = Element(name: "item");
        item.setAttribute("id", value: itemId);
        retract.addChild(item);
        
        context.writer?.write(iq, callback: callback);
    }
    
}

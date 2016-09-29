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

extension PubSubModulePublisherExtension {
    
    /**
     Publish item to PubSub node
     - parameter at: jid of PubSub service
     - parameter to: node name
     - parameter itemId: id of item
     - parameter payload: item payload
     - parameter onSuccess: called when request succeeds - passes instance of response stanza, node name and item id
     - parameter onError: called when request failed - passes general and detailed error condition if available
     */
    public func publishItem(at pubSubJid: BareJID, to nodeName: String, itemId: String? = nil, payload: Element, onSuccess: ((Stanza,String,String?)->Void)?, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        let callback = createCallback(onSuccess: { (stanza) in
            let publishEl = stanza.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)!.findChild(name: "publish")!;
            let node = publishEl.getAttribute("node")!;
            let itemId = publishEl.findChild(name: "item")?.getAttribute("id");
            
            onSuccess?(stanza, node, itemId);
        }, onError: onError);
    
        self.publishItem(at: pubSubJid, to: nodeName, payload: payload, callback: callback);
    }
    
    /**
     Publish item to PubSub node
     - parameter at: jid of PubSub service
     - parameter to: node name
     - parameter itemId: id of item
     - parameter payload: item payload
     - parameter callback: called when response is received or request times out
     */
    public func publishItem(at pubSubJid: BareJID, to nodeName: String, itemId: String? = nil, payload: Element, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let publish = Element(name: "publish");
        publish.setAttribute("node", value: nodeName);
        pubsub.addChild(publish);
        
        let item = Element(name: "item");
        item.setAttribute("id", value: itemId);
        publish.addChild(item);
        
        item.addChild(payload);
        
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
    public func retractItem(at pubSubJid: BareJID, from nodeName: String, itemId: String, onSuccess: ((Stanza)->Void)?, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
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
    public func retractItem(at pubSubJid: BareJID, from nodeName: String, itemId: String, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
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

//
// PubSubModule+Publisher.swift
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

public typealias PubSubPublishItemResult = Result<String,PubSubError>;

extension PubSubModule {
        
    /**
     Publish item to PubSub node
     - parameter at: jid of PubSub service
     - parameter to: node name
     - parameter itemId: id of item
     - parameter payload: item payload
     - parameter publishOptions: publish options
     - parameter completionHandler: called on completion
     */
    public func publishItem(at pubSubJid: BareJID?, to nodeName: String, itemId: String? = nil, payload: Element?, publishOptions: PubSubNodeConfig? = nil, completionHandler: @escaping (PubSubPublishItemResult)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        if pubSubJid != nil {
            iq.to = JID(pubSubJid!);
        }
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let publish = Element(name: "publish");
        publish.attribute("node", newValue: nodeName);
        pubsub.addChild(publish);
        
        let item = Element(name: "item");
        item.attribute("id", newValue: itemId);
        publish.addChild(item);
        
        if let payload = payload {
            item.addChild(payload);
        }
        
        if let publishOptions = publishOptions {
            let publishOptionsEl = Element(name: "publish-options");
            publishOptionsEl.addChild(publishOptions.element(type: .submit, onlyModified: true));
            pubsub.addChild(publishOptionsEl);
        }
        
        write(iq, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler(result.flatMap({ response in
                guard let publishEl = response.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.firstChild(name: "publish"), let id = publishEl.firstChild(name: "item")?.attribute("id") else {
                    if let id = itemId {
                        return .success(id);
                    } else {
                        return .failure(.undefined_condition);
                    }
                }
                return .success(id);
            }))
        });
    }

    /**
     Retract item from PubSub node
     - parameter at: jid of PubSub service
     - parameter from: node name
     - parameter itemId: id of item
     - parameter completionHandler: called when result is available
     */
    public func retractItem(at pubSubJid: BareJID?, from nodeName: String, itemId: String, completionHandler: @escaping (PubSubPublishItemResult)->Void) {
        self.retractItem(at: pubSubJid, from: nodeName, itemId: itemId, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
                completionHandler(result.map({ _ in itemId }))
        });
    }
    
    /**
     Retract item from PubSub node
     - parameter at: jid of PubSub service
     - parameter from: node name
     - parameter itemId: id of item
     - parameter errorDecoder: functon called to preprocess received stanza when error occurred
     - parameter completionHandler: called when result is available
     */
    public func retractItem<Failure: Error>(at pubSubJid: BareJID?, from nodeName: String, itemId: String, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        if pubSubJid != nil {
            iq.to = JID(pubSubJid!);
        }
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let retract = Element(name: "retract");
        retract.attribute("node", newValue: nodeName);
        pubsub.addChild(retract);
        
        let item = Element(name: "item");
        item.attribute("id", newValue: itemId);
        retract.addChild(item);
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
}

// async-await support
extension PubSubModule {
    
    public func publishItem(at pubSubJid: BareJID?, to nodeName: String, itemId: String? = nil, payload: Element?, publishOptions: PubSubNodeConfig? = nil) async throws -> String {
        return try await withUnsafeThrowingContinuation { continuation in
            publishItem(at: pubSubJid, to: nodeName, itemId: itemId, payload: payload, publishOptions: publishOptions, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func retractItem(at pubSubJid: BareJID?, from nodeName: String, itemId: String) async throws -> String {
        return try await withUnsafeThrowingContinuation { continuation in
            retractItem(at: pubSubJid, from: nodeName, itemId: itemId, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
}

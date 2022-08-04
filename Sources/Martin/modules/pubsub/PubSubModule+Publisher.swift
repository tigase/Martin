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

extension PubSubModule {
        
    /**
     Publish item to PubSub node
     - parameter at: jid of PubSub service
     - parameter to: node name
     - parameter itemId: id of item
     - parameter payload: item payload
     - parameter publishOptions: publish options
     */
    public func publishItem(at pubSubJid: BareJID?, to nodeName: String, itemId: String? = nil, payload: Element?, publishOptions: PubSubNodeConfig? = nil) async throws -> String {
        let iq = Iq(type: .set, to: pubSubJid?.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS, {
                Element(name: "publish", {
                    Attribute("node", value: nodeName)
                    Element(name: "item", {
                        Attribute("id", value: itemId)
                        payload
                    })
                })
                publishOptions?.element(type: .submit, onlyModified: true)
            })
        })
        
        let response = try await write(iq: iq);
        
        guard let publishEl = response.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.firstChild(name: "publish"), let id = publishEl.firstChild(name: "item")?.attribute("id") else {
            if let id = itemId {
                return id;
            } else {
                throw XMPPError(condition: .undefined_condition, stanza: response);
            }
        }
        return id;
    }

    /**
     Retract item from PubSub node
     - parameter at: jid of PubSub service
     - parameter from: node name
     - parameter itemId: id of item
     */
    public func retractItem(at pubSubJid: BareJID?, from nodeName: String, itemId: String) async throws -> String {
        let iq = Iq(type: .set, to: pubSubJid?.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS, {
                Element(name: "retract", {
                    Attribute("node", value: nodeName)
                    Element(name: "item", {
                        Attribute("id", value: itemId)
                    })
                });
            })
        })
        
        try await write(iq: iq);
        return itemId;
    }
    
}

// async-await support
extension PubSubModule {
    
    public func publishItem(at pubSubJid: BareJID?, to nodeName: String, itemId: String? = nil, payload: Element?, publishOptions: PubSubNodeConfig? = nil, completionHandler: @escaping (Result<String,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await publishItem(at: pubSubJid, to: nodeName, payload: payload, publishOptions: publishOptions)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func retractItem(at pubSubJid: BareJID?, from nodeName: String, itemId: String, completionHandler: @escaping (Result<String,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await retractItem(at: pubSubJid, from: nodeName, itemId: itemId)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
}

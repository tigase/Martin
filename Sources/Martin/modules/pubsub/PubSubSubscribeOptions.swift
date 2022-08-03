//
// PubSubSubscribeOptions.swift
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

open class PubSubSubscribeOptions: DataFormWrapper {
    
    public enum SubscriptionType {
        case items
        case nodes
    }
    
    @Field("pubsub#deliver")
    public var deliver: Bool?;
    @Field("pubsub#digest")
    public var digest: Bool?;
    @Field("pubsub#digest_frequency")
    public var digestFrequency: Int?;
    @Field("pubsub#expire")
    public var expire: String?;
    @Field("pubsub#include_body")
    public var includeBody: Bool?;
    @Field("pubsub#show-values", type: .listMulti)
    public var showValues: [String]?;
    @Field("pubsub#subscription_type")
    public var subscriptionType: SubscriptionType?;
    @Field("pubsub#subscription_depth", type: .listSingle)
    public var subscriptionDepth: String?;
    
    public convenience init?(element: Element) {
        guard let form = DataForm(element: element) else {
            return nil;
        }
        self.init(form: form);
    }
    
    public override init(form: DataForm? = nil) {
        super.init(form: form);
    }
    
}

extension PubSubModule {
    
    open func subscribe(at pubSubJid: BareJID, to nodeName: String, subscriber: JID, with options: PubSubSubscribeOptions? = nil, completionHandler: ((PubSubResult<PubSubSubscriptionElement>)->Void)?) {
        subscribe(at: pubSubJid, to: nodeName, subscriber: subscriber, with: options?.element(type: .submit, onlyModified: false), errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler?(result.flatMap({ response in
                guard let subscriptionEl = response.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.findChild(name: "subscription"), let subscription = PubSubSubscriptionElement(from: subscriptionEl) else {
                    return .failure(.undefined_condition);
                }
                return .success(subscription);
            }))
        })
    }
    
    open func configureSubscription(at pubSubJid: BareJID, for nodeName: String, subscriber: JID, with options: PubSubSubscribeOptions, completionHandler: ((PubSubResult<Void>)->Void)?) {
        self.configureSubscription(at: pubSubJid, for: nodeName, subscriber: subscriber, with: options.element(type: .submit, onlyModified: true), errorDecoder: PubSubError.from(stanza: ), completionHandler: { result in
            completionHandler?(result.map { _ in Void() });
        });
    }
    
    public func retrieveDefaultSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String?, resultHandler: ((PubSubResult<PubSubSubscribeOptions>)->Void)?) {
        self.retrieveDefaultSubscriptionConfiguration(from: pubSubJid, for: nodeName, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            resultHandler?(result.flatMap({ stanza in
                if let defaultEl = stanza.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.findChild(name: "default"), let x = defaultEl.findChild(name: "x", xmlns: "jabber:x:data"), let defaults = PubSubSubscribeOptions(element: x) {
                    return .success(defaults);
                }
                return .failure(.undefined_condition);
            }))
        });
    }
    
    public func retrieveSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String, subscriber: JID, resultHandler: ((PubSubResult<PubSubSubscribeOptions>)->Void)?) {
        self.retrieveSubscriptionConfiguration(from: pubSubJid, for: nodeName, subscriber: subscriber, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            resultHandler?(result.flatMap({ stanza in
                guard let optionsEl = stanza.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.findChild(name: "options"), let x = optionsEl.findChild(name: "x", xmlns: "jabber:x:data"), let options = PubSubSubscribeOptions(element: x) else {
                    return .failure(.undefined_condition);
                }
                return .success(options);
            }))
        });
    }
    
}

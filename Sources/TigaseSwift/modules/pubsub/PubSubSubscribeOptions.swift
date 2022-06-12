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

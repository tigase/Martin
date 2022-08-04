//
// PubSubErrorCondition.swift
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

/**
 Enum contains values for erros reported by PubSub service
 */
public enum PubSubErrorCondition: String, ApplicationErrorCondition {
    
    case closed_node = "closed-node"
    case configuration_required = "configuration-required"
    case conflict
    case invalid_jid = "invalid-jid"
    case invalid_payload = "invalid-payload"
    case invalid_subid = "invalid-subid"
    case item_required = "item-required"
    case jid_required = "jid-required"
    case node_required = "node-required"
    case nodeid_required = "nodeid-required"
    case not_in_roster_group = "not-in-roster-group"
    case not_subscribed = "not-subscribed"
    case payload_required = "payload-required"
    case payload_too_big = "payload-too-big"
    case pending_subscription = "pending-subscription"
    case presence_subscription_required = "presence-subscription-required"
    case subid_required = "subid-required"
    case too_many_subscriptions = "too-many-subscriptions"
    case unsupported
    case unsupported_access_authorize = "unsupported-access-authorize"
    case unsupported_access_model = "unsupported-access-model"
    case unsupported_access_open = "unsupported-access-open"
    case unsupported_access_presence = "unsupported-access-presence"
    case unsupported_access_roster = "unsupported-access-roster"
    case unsupported_access_whitelist = "unsupported-access-whitelist"
    case unsupported_auto_create = "unsupported-auto-create"
    case unsupported_auto_subscribe = "unsupported-auto-subscribe"
    case unsupported_collections = "unsupported-collections"
    case unsupported_config_node = "unsupported-config-node"
    case unsupported_create_and_configure = "unsupported-create-and-configure"
    case unsupported_create_nodes = "unsupported-create-nodes"
    case unsupported_delete_items = "unsupported-delete-items"
    case unsupported_delete_nodes = "unsupported-delete-nodes"
    case unsupported_filtered_notifications = "unsupported-filtered-notifications"
    case unsupported_get_pending = "unsupported-get-pending"
    case unsupported_instant_nodes = "unsupported-instant-nodes"
    case unsupported_item_ids = "unsupported-item-ids"
    case unsupported_last_published = "unsupported-last-published"
    case unsupported_leased_subscription = "unsupported-leased-subscription"
    case unsupported_manage_subscriptions = "unsupported-manage-subscriptions"
    case unsupported_member_affiliation = "unsupported-member-affiliation"
    case unsupported_meta_data = "unsupported-meta-data"
    case unsupported_modify_affiliations = "unsupported-modify-affiliation"
    case unsupported_multi_collection = "unsupported-multi-collection"
    case unsupported_multi_subscribe = "unsupported-multi-subscribe"
    case unsupported_outcast_affiliation = "unsupported-outcast-affiliation"
    case unsupported_persistent_items = "unsupported-persistent-items"
    case unsupported_presence_notifications = "unsupported-presence-notifications"
    case unsupported_presence_subscribe = "unsupported-presence-subscribe"
    case unsupported_publish = "unsupported-publish"
    case unsupported_publish_only_affiliation = "unsupported-publish-only-affiliations"
    case unsupported_publish_options = "unsupported-publish-options"
    case unsupported_publisher_affiliation = "unsupported-publisher-affiliation"
    case unsupported_purge_nodes = "unsupported-purge-nodes"
    case unsupported_retract_items = "unsupported-retract-items"
    case unsupported_retrieve_affiliations = "unsupported-retrieve-affiliations"
    case unsupported_retrieve_default = "unsupported-retrieve-default"
    case unsupported_retrieve_items = "unsupported-retrieve-items"
    case unsupported_retrieve_subscriptions = "unsupported-retrieve-subscriptions"
    case unsupported_subscribe = "unsupported-subscribe"
    case unsupported_subscription_notifications = "unsupported-subscription-notifications"
    case unsupported_subscription_options = "unsupported-subscription-options"
    
    public var description: String {
        return rawValue;
    }

    public init?(errorEl: Element) {
        guard let conditionName = errorEl.firstChild(xmlns: PubSubModule.PUBSUB_ERROR_XMLNS)?.name else {
            return nil;
        }
        self.init(rawValue: conditionName);
    }
    
    public func element() -> Element {
        return Element(name: rawValue, xmlns: PubSubModule.PUBSUB_ERROR_XMLNS);
    }
}

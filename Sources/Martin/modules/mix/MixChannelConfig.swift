//
// MixChannelConfig.swift
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

open class MixChannelConfig: DataFormWrapper {
    
    public enum NodePermission: String, DataFormEnum {
        case participants
        case allowed
        case anyone
    }
    
    public enum NodePermissionExtended: String, DataFormEnum {
        case participants
        case allowed
        case anyone
        case nobody
        case admin
        case owner
    }
    
    public enum NodeUpdateRights: String, DataFormEnum {
        case participants
        case admins
        case onwers
    }
    
    public enum AdminMessageRetractionRights: String, DataFormEnum {
        case onbody
        case admins
        case owners
    }
    
    @Field("Last Change Made By")
    public var lastChangeMadeBy: JID?
    @Field("Owner")
    public var owner: [JID]?;
    @Field("Administrator")
    public var administrator: [JID]?
    @Field("End of Life")
    public var endOfList: String?
    @Field("Nodes Present", type: .listMulti)
    public var nodesPresent: [String]?
    @Field("Messages Node Subscription")
    public var messagesNodeSubscription: NodePermission?;
    @Field("Presence Node Subscription")
    public var presenceNodeSubscription: NodePermission?;
    @Field("Participants Node Subscription")
    public var participantsNodeSubscription: NodePermissionExtended?;
    @Field("Information Node Subscription")
    public var informationNodeSubscription: NodePermission?;
    @Field("Allowed Node Subscription")
    public var allowedNodeSubscription: NodePermissionExtended?;
    @Field("Banned Node Subscription")
    public var bannedNodeSubscription: NodePermissionExtended?;
    @Field("Configuration Node Access")
    public var configurationNodeAccess: NodePermissionExtended?;
    @Field("Information Node Update Rights")
    public var informationNodeUpdateRights: NodeUpdateRights?;
    @Field("Avatar Nodes Update Rights")
    public var nodeUpdateRights: NodeUpdateRights?;
    @Field("Open Presence")
    public var openPresence: Bool?;
    @Field("Participants Must Provide Presence")
    public var participantsMustProvidePresence: Bool?;
    @Field("User Message Retraction")
    public var userMessageRetraction: Bool?;
    @Field("Administrator Message Retraction Rights")
    public var administratorMessageRetractionRights: AdminMessageRetractionRights?;
    @Field("Participation Addition by Invitation from Participant")
    public var participationAdditionByInvitationFromParticipant: Bool?;
    @Field("Private Messages")
    public var privateMessages: Bool?;
    @Field("Mandatory Nicks")
    public var mandatoryNicks: Bool?;
    
    public convenience init?(element: Element) {
        guard let form = DataForm(element: element) else {
            return nil;
        }
        self.init(form: form)
    }
    
    public override init(form: DataForm? = nil) {
        super.init(form: form);
        FORM_TYPE = MixModule.CORE_XMLNS;
    }
}

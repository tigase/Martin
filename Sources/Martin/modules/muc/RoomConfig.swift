//
// RoomConfig.swift
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

open class RoomConfig: DataFormWrapper, @unchecked Sendable {
    
    public enum WhoisEnum: String, DataFormEnum {
        case moderators
        case anyone
    }
    
    public enum AllowPM: String, DataFormEnum {
        case anyone
        case participants
        case moderators
        case none
    }

    @Field("muc#maxhistoryfetch")
    public var maxHistoryFetch: Int?;
    @Field("muc#roomconfig_allowpm")
    public var allowPM: AllowPM?;
    @Field("muc#roomconfig_allowinvites")
    public var allowInvites: Bool?;
    @Field("muc#roomconfig_changesubject")
    public var changeSubject: Bool?;
    @Field("muc#roomconfig_enablelogging")
    public var enableLogging: Bool?;
    @Field("muc#roomconfig_getmemberlist")
    public var getMemberList: [String]?;
    @Field("muc#roomconfig_lang")
    public var lang: String?;
    @Field("muc#roomconfig_pubsub")
    public var pubsub: String?;
    @Field("muc#roomconfig_maxusers")
    public var maxUsers: Int?;
    @Field("muc#roomconfig_membersonly")
    public var membersOnly: Bool?;
    @Field("muc#roomconfig_moderatedroom")
    public var moderatedRoom: Bool?;
    @Field("muc#roomconfig_passwordprotectedroom")
    public var passwordProtectedRoom: Bool?;
    @Field("muc#roomconfig_persistentroom")
    public var persistentRoom: Bool?;
    @Field("muc#roomconfig_publicroom")
    public var publicRoom: Bool?;
    @Field("muc#roomconfig_roomadmins")
    public var admins: [JID]?;
    @Field("muc#roomconfig_roomdesc")
    public var desc: String?;
    @Field("muc#roomconfig_roomname")
    public var name: String?;
    @Field("muc#roomconfig_roomowners")
    public var owners: [JID]?;
    @Field("muc#roomconfig_roomsecret")
    public var secret: String?;
    @Field("muc#roomconfig_whois")
    public var whois: WhoisEnum?;
    
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

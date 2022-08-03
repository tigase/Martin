//
// MucAffiliation.swift
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
 Possible affiliations of occupants to MUC room:
 - owner
 - admin
 - member
 - none
 - outcast
 
 Every affiliation contains properties which will tell 
 if action is allowed or not in this affiliation.
 */
public enum MucAffiliation: String, DataFormEnum {
    case owner
    case admin
    case member
    case none
    case outcast
    
    public var weight: Int {
        switch self {
        case .owner:
            return 40;
        case .admin:
            return 30;
        case .member:
            return 20;
        case .none:
            return 10;
        case .outcast:
            return 0;
        }
    }
    
    public var enterOpenRoom: Bool {
        switch self {
        case .outcast:
            return false;
        default:
            return true;
        }
    }

    public var registerWithOpenRoom: Bool {
        switch self {
        case .outcast:
            return false;
        default:
            return true;
        }
    }

    public var retrieveMemberList: Bool {
        switch self {
        case .outcast, .none:
            return false;
        default:
            return true;
        }
    }
    
    public var enterMembersOnly: Bool {
        switch self {
        case .outcast, .none:
            return false;
        default:
            return true;
        }
    }

    public var banMembersAndUnaffiliatedUsers: Bool {
        switch self {
        case .admin, .owner:
            return true;
        default:
            return false;
        }
    }

    public var editMemberList: Bool {
        switch self {
        case .admin, .owner:
            return true;
        default:
            return false;
        }
    }

    public var editModeratorList: Bool {
        switch self {
        case .admin, .owner:
            return true;
        default:
            return false;
        }
    }

    public var editAdminList: Bool {
        switch self {
        case .owner:
            return true;
        default:
            return false;
        }
    }

    public var editOwnerList: Bool {
        switch self {
        case .owner:
            return true;
        default:
            return false;
        }
    }

    public var changeRoomDefinition: Bool {
        switch self {
        case .owner:
            return true;
        default:
            return false;
        }
    }

    public var destroyRoom: Bool {
        switch self {
        case .owner:
            return true;
        default:
            return false;
        }
    }

    public var viewOccupantsJid: Bool {
        switch self {
        case .admin, .owner:
            return true;
        default:
            return false;
        }
    }

}

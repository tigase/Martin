//
// MucRole.swift
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
 Possible roles in MUC room:
 - moderator
 - participant
 - visitor
 - none
 
 Every role contains properties which describes what user 
 in particular role can and cannot do.
 */
public enum MucRole: String {
    
    case moderator
    case participant
    case visitor
    case none
    
    public var weight: Int {
        switch self {
        case .moderator:
            return 3;
        case .participant:
            return 2;
        case .visitor:
            return 1;
        case .none:
            return 0;
        }
    }
    
    public var presentInRoom: Bool {
        switch self {
        case .none:
            return false;
        default:
            return true;
        }
    }
    
    public var receiveMessages: Bool {
        switch self {
        case .none:
            return false;
        default:
            return true;
        }
    }

    public var receiveOccupantPresence: Bool {
        switch self {
        case .none:
            return false;
        default:
            return true;
        }
    }

    public var presenceBroadcastedToRoom: Bool {
        switch self {
        case .none:
            return false;
        default:
            return true;
        }
    }

    public var changeAvailabilityStatus: Bool {
        switch self {
        case .none:
            return false;
        default:
            return true;
        }
    }

    public var changeRoomNickname: Bool {
        switch self {
        case .none:
            return false;
        default:
            return true;
        }
    }

    public var sendPrivateMessages: Bool {
        switch self {
        case .none:
            return false;
        default:
            return true;
        }
    }

    public var inviteOtherUsers: Bool {
        switch self {
        case .none:
            return false;
        default:
            return true;
        }
    }
    
    public var sendMessagesToAll: Bool {
        switch self {
        case .none, .visitor:
            return false;
        default:
            return true;
        }
    }

    public var modifySubject: Bool {
        switch self {
        case .moderator:
            return true;
        default:
            return false;
        }
    }
    
    public var kickParticipantsAndVisitor: Bool {
        switch self {
        case .moderator:
            return true;
        default:
            return false;
        }
    }
    
    public var grantVoice: Bool {
        switch self {
        case .moderator:
            return true;
        default:
            return false;
        }
    }
    
    public var revokeVoice: Bool {
        switch self {
        case .moderator:
            return true;
        default:
            return false;
        }
    }

}

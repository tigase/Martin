//
// RoomProtocol.swift
//
// TigaseSwift
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
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
import Combine

/**
 Possible states of room:
 - joined: you are joined to room
 - not_joined: you are not joined and join is not it progress
 - requested: you are not joined but already requested join
 */
public enum RoomState: Equatable {
    public static func == (lhs: RoomState, rhs: RoomState) -> Bool {
        return lhs.value == rhs.value;
    }

    case joined
    case not_joined(reason: NotJoinedReason = .none)
    case requested
    case destroyed
    
    private var value: Int {
        switch self {
        case .joined:
            return 1;
        case .destroyed:
            return 2;
        case .requested:
            return 3;
        case .not_joined(_):
            return 4;
        }
    }
    
    public enum NotJoinedReason {
        case none
        case error(XMPPError)
    }
}

public protocol RoomProtocol: ConversationProtocol {
    
    var state: RoomState { get }
    var statePublisher: AnyPublisher<RoomState, Never> { get }
    
    var nickname: String { get }
    var password: String? { get }
    
    var role: MucRole { get set }
    var affiliation: MucAffiliation { get set }
 
    func update(state: RoomState);
    
    var occupantsPublisher: AnyPublisher<[MucOccupant], Never> { get }
    
    func occupant(nickname: String) -> MucOccupant?;
    func addOccupant(nickname: String, presence: Presence) -> MucOccupant;
    func remove(occupant: MucOccupant);

    func addTemp(nickname: String, occupant: MucOccupant);
    func removeTemp(nickname: String) -> MucOccupant?;
    
}

public enum RoomHistoryFetch {
    case skip
    case initial
    case from(Date)
}

public enum RoomJoinResult {
    case created(RoomProtocol)
    case joined(RoomProtocol)
}

extension RoomProtocol {
    
    public func rejoin(fetchHistory: RoomHistoryFetch) -> Future<RoomJoinResult, XMPPError> {
        return Future({ promise in
            guard let context = self.context else {
                promise(.failure(.undefined_condition));
                return;
            }
            context.module(.muc).join(room: self, fetchHistory: fetchHistory).handle(promise);
        })
    }
    
    public func createPrivateMessage(_ body: String, recipientNickname: String) -> Message {
        let msg = createMessage(text: body, id: UUID().uuidString, type: .chat);
        msg.to = jid.with(resource: recipientNickname);
        msg.addChild(Element(name: "x", xmlns: "http://jabber.org/protocol/muc#user"));
        return msg;
    }
    
    /**
     Send invitation
     - parameter invitee: user to invite
     - parameter reason: invitation reason
     */
    public func invite(_ invitee: JID, reason: String?) {
        let message = self.createInvitation(invitee, reason: reason);
        
        context?.writer.write(message);
    }
    
    /**
     Create invitation
     - parameter invitee: user to invite
     - parameter reason: invitation reason
     - returns: newly create message
     */
    public func createInvitation(_ invitee: JID, reason: String?) -> Message {
        let message = Message();
        message.to = JID(jid);
        
        let x = Element(name: "x", xmlns: "http://jabber.org/protocol/muc#user");
        let invite = Element(name: "invite");
        invite.setAttribute("to", value: invitee.stringValue);
        if (reason != nil) {
            invite.addChild(Element(name: "reason", cdata: reason!));
        }
        x.addChild(invite);
        message.addChild(x);

        return message;
    }
    
    /**
     Send direct invitation
     - parameter invitee: user to invite
     - parameter reason: invitation reason
     - parameter threadId: thread id to use in invitation message
     */
    public func inviteDirectly(_ invitee: JID, reason: String?, threadId: String?) {
        let message = createDirectInvitation(invitee, reason: reason, threadId: threadId);
        context?.writer.write(message);
    }
    
    /**
     Create direct invitation
     - parameter invitee: user to invite
     - parameter reason: invitation reason
     - parameter threadId: thread id to use in invitation message
     - returns: newly created invitation message
     */
    public func createDirectInvitation(_ invitee: JID, reason: String?, threadId: String?) -> Message {
        let message = Message();
        message.to = invitee;
        
        let x = Element(name: "x", xmlns: "jabber:x:conference");
        x.setAttribute("jid", value: jid.stringValue);
        
        x.setAttribute("password", value: password);
        x.setAttribute("reason", value: reason);
        
        if threadId != nil {
            x.setAttribute("thread", value: threadId);
            x.setAttribute("continue", value: "true");
        }
        
        return message;
    }
}

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

/**
 Possible states of room:
 - joined: you are joined to room
 - not_joined: you are not joined and join is not it progress
 - requested: you are not joined but already requested join
 */
public enum RoomState {
    case joined
    case not_joined
    case requested
    case destroyed
}

public protocol RoomProtocol: ConversationProtocol, RoomOccupantsStoreProtocol {
    
    var state: RoomState { get set }
    
    var nickname: String { get }
    var password: String? { get }
    
}

public enum RoomHistoryFetch {
    case skip
    case initial
    case from(Date)
}

extension RoomProtocol {
    
    public func rejoin() {
        if let date = (self as? LastMessageTimestampAware)?.lastMessageTimestamp {
            self.rejoin(fetchHistory: .from(date));
        } else {
            self.rejoin(fetchHistory: .initial);
        }
    }
    
    public func rejoin(fetchHistory: RoomHistoryFetch) -> Presence {
        let presence = Presence();
        presence.to = jid.with(resource: nickname);
        let x = Element(name: "x", xmlns: "http://jabber.org/protocol/muc");
        presence.addChild(x);
        if let password = password {
            x.addChild(Element(name: "password", cdata: password));
        }
        
        switch fetchHistory {
        case .initial:
            break;
        case .from(let date):
            let history = Element(name: "history");
            history.setAttribute("since", value: TimestampHelper.format(date: date));
            x.addChild(history);
        case .skip:
            let history = Element(name: "history");
            history.setAttribute("maxchars", value: "0");
            history.setAttribute("maxstanzas", value: "0");
            x.addChild(history);
        }
        
        state = .requested;
        context?.writer.write(presence);
        
        return presence;
    }
    
    /**
     Send message to room
     - parameter body: text to send
     - parameter additionalElement: additional elements to add to message
     */
    public func sendMessage(_ body: String?, url: String? = nil, additionalElements: [Element]? = nil) {
        let msg = createMessage(body);
        if url != nil {
            msg.oob = url;
        }
        if additionalElements != nil {
            for elem in additionalElements! {
                msg.addChild(elem);
            }
        }
        context?.writer.write(msg);
    }
    
    /**
     Prepare message for sending to room
     - parameter body: text to send
     - returns: newly create message
     */
    public func createMessage(_ body: String?) -> Message {
        let msg = Message();
        msg.to = jid;
        msg.type = StanzaType.groupchat;
        msg.body = body;
        return msg;
    }
    
    public func createPrivateMessage(_ body: String?, recipientNickname: String) -> Message {
        let msg = Message();
        msg.to = jid.with(resource: recipientNickname);
        msg.type = StanzaType.chat;
        msg.body = body;
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
        message.to = jid;
        
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

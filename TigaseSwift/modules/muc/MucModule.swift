//
// MucModule.swift
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

public class MucModule: Logger, XmppModule, ContextAware, Initializable, EventHandler {

    public static let ID = "muc";
    
    private static let DIRECT_INVITATION = Criteria.name("message", containsAttribute: "from").add(Criteria.name("x", xmlns: "jabber:x:conference"));
    private static let MEDIATED_INVITATION = Criteria.name("message", containsAttribute: "from").add(Criteria.name("x", xmlns: "http://jabber.org/protocol/muc#user").add(Criteria.name("invite")));
    private static let MEDIATED_INVITATION_DECLINE = Criteria.name("message", containsAttribute: "from").add(Criteria.name("x", xmlns: "http://jabber.org/protocol/muc#user").add(Criteria.name("decline")));

    
    public let id = ID;
    
    public var context:Context! {
        didSet {
            if oldValue != nil {
                oldValue.eventBus.unregister(self, events: SessionObject.ClearedEvent.TYPE);
            }
            roomsManager?.context = context;
            if context != nil {
                context.eventBus.register(self, events: SessionObject.ClearedEvent.TYPE);
            }
        }
    }
    
    public let criteria = Criteria.or(
        Criteria.name("message", types: [StanzaType.groupchat], containsAttribute: "from"),
        Criteria.name("presence", containsAttribute: "from"),
        DIRECT_INVITATION,
        MEDIATED_INVITATION,
        MEDIATED_INVITATION_DECLINE
        );
    
    public let features = [String]();
    
    public var roomsManager: DefaultRoomsManager! {
        didSet {
            oldValue?.context = nil;
            if roomsManager != nil {
                roomsManager.context = context;
            }
        }
    }
    
    public override init() {
        super.init();
    }
    
    public func initialize() {
        if roomsManager == nil {
            roomsManager = DefaultRoomsManager();
        }
        roomsManager.context = context;
        roomsManager.initialize();
    }
    
    public func handleEvent(event: Event) {
        switch event {
        case let sec as SessionObject.ClearedEvent:
            if sec.scopes.contains(SessionObject.Scope.session) {
                for room in roomsManager.getRooms() {
                    room._state = .not_joined;

                    let occupants = room.presences.values;
                    for occupant in occupants {
                        room.remove(occupant);
                        // should we fire this event?
                        // context.eventBus.fire(OccupantLeavedEvent(sessionObject: context.sessionObject, ))
                    }
                }
            }
        default:
            log("received event of unsupported type", event);
        }
    }
    
    public func declineInvitation(invitation: Invitation, reason: String?) {
        if invitation is MediatedInvitation {
            let message = Message();
            message.to = JID(invitation.roomJid);
            
            let x = Element(name: "x", xmlns: "http://jabber.org/protocol/muc#user");
            
            let decline = Element(name: "decline");
            if reason != nil {
                decline.addChild(Element(name: "reason", cdata: reason));
            }
            x.addChild(decline);
            
            message.addChild(x);
            context.writer?.write(message);
        }
    }
    
    
    public func invite(room: Room, invitee: JID, reason: String?) {
        room.invite(invitee, reason: reason);
    }
    
    public func inviteDirectly(room: Room, invitee: JID, reason: String?, threadId: String?) {
        room.inviteDirectly(invitee, reason: reason, threadId: threadId);
    }
    
    public func join(roomName: String, mucServer: String, nickname: String, password: String? = nil) -> Room {
        let roomJid = BareJID(localPart: roomName, domain: mucServer);
        
        var room = roomsManager.get(roomJid);
        if room != nil {
            return room!;
        }
        room = roomsManager.createRoomInstance(roomJid, nickname: nickname, password: password);
        roomsManager.register(room!);
        let presence = room!.rejoin();
        
        context.eventBus.fire(JoinRequestedEvent(sessionObject: context.sessionObject, presence: presence, room: room!, nickname: nickname));
        
        return room!;
    }
    
    public func leave(room: Room) {
        if room.state == .joined {
            room._state = .not_joined;
            
            let presence = Presence();
            presence.type = StanzaType.unavailable;
            presence.to = JID(room.roomJid, resource: room.nickname);
            context.writer?.write(presence);
        }
        
        roomsManager.remove(room);
        
        context.eventBus.fire(RoomClosedEvent());
    }
    
    public func process(stanza: Stanza) throws {
        switch stanza {
        case let p as Presence:
            try processPresence(p);
        case let m as Message:
            if MucModule.MEDIATED_INVITATION_DECLINE.match(m.element) {
                processInvitationDeclinedMessage(m);
            } else if MucModule.MEDIATED_INVITATION.match(m.element) {
                processMediatedInvitationMessage(m);
            } else if MucModule.DIRECT_INVITATION.match(m.element) {
                processDirectInvitationMessage(m);
            } else {
                processMessage(m);
            }
        default:
            throw ErrorCondition.feature_not_implemented;
        }
    }
    
    func processPresence(presence: Presence) throws {
        let from = presence.from!;
        let roomJid = from.bareJid;
        let nickname = from.resource;
        let room:Room! = roomsManager.get(roomJid);
        let type = presence.type;
        guard room != nil else {
            return;
        }
        
        if type == StanzaType.error {
            if room.state != .joined && nickname == nil {
                room._state = .not_joined;
                context.eventBus.fire(RoomClosedEvent(sessionObject: context.sessionObject, presence: presence, room: room));
            } else {
                context.eventBus.fire(PresenceErrorEvent(sessionObject: context.sessionObject, presence: presence, room: room, nickname: nickname));
                return;
            }
        }
        
        guard nickname != nil else {
            return;
        }
        
        if (type == StanzaType.unavailable && nickname == room.nickname) {
            room._state = .not_joined;
        }
        
        let xUser = XMucUserElement.extract(presence);
        
        var occupant = room.presences[nickname!];
        let presenceOld = occupant?.presence;
        if occupant == nil {
            occupant = Occupant();
        }
        occupant!.presence = presence;
        
        if (presenceOld != nil && presenceOld!.type == nil) && type == StanzaType.unavailable && xUser?.statuses.indexOf(303) != nil {
            let newNickName = xUser?.nick;
            room.remove(occupant!);
            room.addTemp(newNickName!, occupant: occupant!);
        } else if room.state != .joined && xUser?.statuses.indexOf(110) != nil {
            room._state = .joined;
            occupant!.presence = presence;
            room.add(occupant!);
            context.eventBus.fire(YouJoinedEvent(sessionObject: context.sessionObject, room: room, nickname: nickname));
        } else if (presenceOld == nil || presenceOld?.type == StanzaType.unavailable) && type == nil {
            if let tmp = room.removeTemp(nickname!) {
                let oldNickname = tmp.nickname;
                occupant = tmp;
                occupant!.presence = presence;
                room.add(occupant!);
                context.eventBus.fire(OccupantChangedNickEvent(sessionObject: context.sessionObject, presence: presence, room: room, occupant: occupant!, nickname: oldNickname));
            } else {
                occupant!.presence = presence;
                room.add(occupant!);
                context.eventBus.fire(OccupantComesEvent(sessionObject: context.sessionObject, presence: presence, room: room, occupant: occupant!, nickname: nickname, xUser: xUser));
            }
        } else if (presenceOld != nil && presenceOld!.type == nil && type == StanzaType.unavailable) {
            occupant!.presence = presence;
            room.remove(occupant!);
            context.eventBus.fire(OccupantLeavedEvent(sessionObject: context.sessionObject, presence: presence, room: room, occupant: occupant!, nickname: nickname, xUser: xUser));
        } else {
            occupant!.presence = presence;
            context.eventBus.fire(OccupantChangedPresenceEvent(sessionObject: context.sessionObject, presence: presence, room: room, occupant: occupant!, nickname: nickname, xUser: xUser));
        }
        
        if xUser != nil && xUser?.statuses.indexOf(201) != nil {
            context.eventBus.fire(NewRoomCreatedEvent(sessionObject: context.sessionObject, presence: presence, room: room));
        }
    }
    
    func processMessage(message: Message) {
        let from = message.from!;
        let roomJid = from.bareJid;
        let nickname = from.resource;
        
        let room:Room! = roomsManager.get(roomJid);
        guard room != nil else {
            return;
        }
        
        let timestamp = message.delay?.stamp ?? NSDate();
        if room.state != .joined {
            room._state = .joined;
            log("Message while not joined in room:", room, " with nickname:", nickname);
            
            context.eventBus.fire(YouJoinedEvent(sessionObject: context.sessionObject, room: room, nickname: nickname ?? room.nickname));
        }
        context.eventBus.fire(MessageReceivedEvent(sessionObject: context.sessionObject, message: message, room: room, nickname: nickname, timestamp: timestamp));
        room.lastMessageDate = timestamp;
    }
    
    func processDirectInvitationMessage(message: Message) {
        let x = message.findChild("x", xmlns: "jabber:x:conference");
        let contStr = x?.getAttribute("continue");
        let cont = contStr == "true" || contStr == "1";
        
        let invitation = DirectInvitation(sessionObject: context.sessionObject, message: message, roomJid: BareJID(x!.getAttribute("jid")!), inviter: message.from!, reason: x?.getAttribute("reason"), password: x?.getAttribute("password"), threadId: x?.getAttribute("thread"), continueFlag: cont);
        
        context.eventBus.fire(InvitationReceivedEvent(sessionObject: context.sessionObject, invitation: invitation));
    }
    
    func processMediatedInvitationMessage(message: Message) {
        let x = message.findChild("x", xmlns: "http://jabber.org/protocol/muc#user");
        let invite = x?.findChild("invite");
        
        let invitation = MediatedInvitation(sessionObject: context.sessionObject, message: message, roomJid: message.from!.bareJid, inviter: JID(invite?.stringValue), reason: invite?.getAttribute("reason"), password: x?.getAttribute("password"));
        
        context.eventBus.fire(InvitationReceivedEvent(sessionObject: context.sessionObject, invitation: invitation));
    }
    
    func processInvitationDeclinedMessage(message: Message) {
        let from = message.from!.bareJid;
        let room = roomsManager.get(from);
        guard room != nil else {
            return;
        }
        
        let decline = message.findChild("x", xmlns: "http://jabber.org/protocol/muc#user")?.findChild("decline");
        let reason = decline?.findChild("reason")?.stringValue;
        let invitee = decline?.getAttribute("from");
        
        context.eventBus.fire(InvitationDeclinedEvent(sessionObject: context.sessionObject, message: message, room: room!, invitee: invitee == nil ? nil : JID(invitee!), reason: reason));
    }

    public class JoinRequestedEvent: Event {
        
        public static let TYPE = JoinRequestedEvent();
        
        public let type = "MucModuleJoinRequestedEvent";
        
        public let sessionObject: SessionObject!;
        public let presence: Presence!;
        public let room: Room!;
        public let nickname: String?;
        
        init() {
            self.sessionObject = nil;
            self.presence = nil;
            self.room = nil;
            self.nickname = nil;
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room, nickname: String?) {
            self.sessionObject = sessionObject;
            self.presence = presence;
            self.room = room;
            self.nickname = nickname;
        }
        
    }
    
    public class MessageReceivedEvent: Event {
        
        public static let TYPE = MessageReceivedEvent();
        
        public let type = "MucModuleMessageReceivedEvent";
        
        public let sessionObject: SessionObject!;
        public let message: Message!;
        public let room: Room!;
        public let nickname: String?;
        public let timestamp: NSDate!;
        
        init() {
            self.sessionObject = nil;
            self.message = nil;
            self.room = nil;
            self.nickname = nil;
            self.timestamp = nil;
        }
        
        public init(sessionObject: SessionObject, message: Message, room: Room, nickname: String?, timestamp: NSDate) {
            self.sessionObject = sessionObject;
            self.message = message;
            self.room = room;
            self.nickname = nickname;
            self.timestamp = timestamp;
        }
        
    }
    
    public class NewRoomCreatedEvent: Event {
        
        public static let TYPE = NewRoomCreatedEvent();
        
        public let type = "MucModuleNewRoomCreatedEvent";
        
        public let sessionObject: SessionObject!;
        public let presence: Presence!;
        public let room: Room!;
        
        init() {
            self.sessionObject = nil;
            self.presence = nil;
            self.room = nil;
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room) {
            self.sessionObject = sessionObject;
            self.presence = presence;
            self.room = room;
        }
    }
    public class OccupantChangedNickEvent: Event {
        
        public static let TYPE = OccupantChangedNickEvent();
        
        public let type = "MucModuleOccupantChangedNickEvent";
        
        public let sessionObject: SessionObject!;
        public let presence: Presence!;
        public let room: Room!;
        public let occupant: Occupant!;
        public let nickname: String?;
        
        init() {
            self.sessionObject = nil;
            self.presence = nil;
            self.room = nil;
            self.occupant = nil;
            self.nickname = nil;
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room, occupant: Occupant, nickname: String?) {
            self.sessionObject = sessionObject;
            self.presence = presence;
            self.room = room;
            self.occupant = occupant;
            self.nickname = nickname;
        }
    }

    public class OccupantChangedPresenceEvent: Event {
        
        public static let TYPE = OccupantChangedPresenceEvent();
        
        public let type = "MucModuleOccupantChangedPresenceEvent";
        
        public let sessionObject: SessionObject!;
        public let presence: Presence!;
        public let room: Room!;
        public let occupant: Occupant!;
        public let nickname: String?;
        public let xUser: XMucUserElement?;
        
        init() {
            self.sessionObject = nil;
            self.presence = nil;
            self.room = nil;
            self.occupant = nil;
            self.nickname = nil;
            self.xUser = nil;
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room, occupant: Occupant, nickname: String?, xUser: XMucUserElement?) {
            self.sessionObject = sessionObject;
            self.presence = presence;
            self.room = room;
            self.occupant = occupant;
            self.nickname = nickname;
            self.xUser = xUser;
        }
    }
    
    public class OccupantComesEvent: Event {
        
        public static let TYPE = OccupantComesEvent();
        
        public let type = "MucModuleOccupantComesEvent";
        
        public let sessionObject: SessionObject!;
        public let presence: Presence!;
        public let room: Room!;
        public let occupant: Occupant!;
        public let nickname: String?;
        public let xUser: XMucUserElement?;
        
        init() {
            self.sessionObject = nil;
            self.presence = nil;
            self.room = nil;
            self.occupant = nil;
            self.nickname = nil;
            self.xUser = nil;
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room, occupant: Occupant, nickname: String?, xUser: XMucUserElement?) {
            self.sessionObject = sessionObject;
            self.presence = presence;
            self.room = room;
            self.occupant = occupant;
            self.nickname = nickname;
            self.xUser = xUser;
        }
    }
    
    public class OccupantLeavedEvent: Event {
        
        public static let TYPE = OccupantLeavedEvent();
        
        public let type = "MucModuleOccupantLeavedEvent";
        
        public let sessionObject: SessionObject!;
        public let presence: Presence!;
        public let room: Room!;
        public let occupant: Occupant!;
        public let nickname: String?;
        public let xUser: XMucUserElement?;
        
        init() {
            self.sessionObject = nil;
            self.presence = nil;
            self.room = nil;
            self.occupant = nil;
            self.nickname = nil;
            self.xUser = nil;
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room, occupant: Occupant, nickname: String?, xUser: XMucUserElement?) {
            self.sessionObject = sessionObject;
            self.presence = presence;
            self.room = room;
            self.occupant = occupant;
            self.nickname = nickname;
            self.xUser = xUser;
        }
    }
    
    public class PresenceErrorEvent: Event {
        
        public static let TYPE = PresenceErrorEvent();
        
        public let type = "MucModulePresenceErrorEvent";
        
        public let sessionObject: SessionObject!;
        public let presence: Presence!;
        public let room: Room!;
        public let nickname: String?;
        
        init() {
            self.sessionObject = nil;
            self.presence = nil;
            self.room = nil;
            self.nickname = nil;
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room, nickname: String?) {
            self.sessionObject = sessionObject;
            self.presence = presence;
            self.room = room;
            self.nickname = nickname;
        }
    }
    
    public class RoomClosedEvent: Event {
        
        public static let TYPE = RoomClosedEvent();
        
        public let type = "MucModuleRoomClosedEvent";
        
        public let sessionObject: SessionObject!;
        public let presence: Presence!;
        public let room: Room!;
        
        init() {
            self.sessionObject = nil;
            self.presence = nil;
            self.room = nil;
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room) {
            self.sessionObject = sessionObject;
            self.presence = presence;
            self.room = room;
        }
    }
    
    
    public class YouJoinedEvent: Event {
        
        public static let TYPE = YouJoinedEvent();
        
        public let type = "MucModuleYouJoinedEvent";
        
        public let sessionObject: SessionObject!;
        public let room: Room!;
        public let nickname: String?;
        
        init() {
            self.sessionObject = nil;
            self.room = nil;
            self.nickname = nil;
        }
        
        public init(sessionObject: SessionObject, room: Room, nickname: String?) {
            self.sessionObject = sessionObject;
            self.room = room;
            self.nickname = nickname;
        }
    }
    
    public class InvitationDeclinedEvent: Event {
        
        public static let TYPE = InvitationDeclinedEvent();
        
        public let type = "MucModuleInvitationDeclinedEvent";
        
        public let sessionObject: SessionObject!;
        public let message: Message!;
        public let room: Room!;
        public let invitee: JID?;
        public let reason: String?;
        
        private init() {
            self.sessionObject = nil;
            self.message = nil;
            self.room = nil;
            self.invitee = nil;
            self.reason = nil;
        }
    
        public init(sessionObject: SessionObject, message: Message, room: Room, invitee: JID?, reason: String?) {
            self.sessionObject = sessionObject;
            self.message = message;
            self.room = room;
            self.invitee = invitee;
            self.reason = reason;
        }
    }
    
    public class InvitationReceivedEvent: Event {
        
        public static let TYPE = InvitationReceivedEvent();
        
        public let type = "MucModuleInvitationReceivedEvent";
        
        public let sessionObject: SessionObject!;
        public let invitation: Invitation!;
        
        private init() {
            self.sessionObject = nil;
            self.invitation = nil;
        }
        
        public init(sessionObject: SessionObject, invitation: Invitation) {
            self.sessionObject = sessionObject;
            self.invitation = invitation;
        }
        
    }
    
    public class Invitation {
        
        public let sessionObject: SessionObject;
        public let message: Message;
        public let roomJid: BareJID;
        public let inviter: JID?;
        public let password: String?;
        public let reason: String?;
        
        public init(sessionObject: SessionObject, message: Message, roomJid: BareJID, inviter: JID?, reason: String?, password: String?) {
            self.sessionObject = sessionObject;
            self.message = message;
            self.roomJid = roomJid;
            self.inviter = inviter;
            self.reason = reason;
            self.password = password;
        }
    }
    
    public class DirectInvitation: Invitation {
        
        public let threadId: String?;
        public let continueFlag: Bool;
        
        public init(sessionObject: SessionObject, message: Message, roomJid: BareJID, inviter: JID?, reason: String?, password: String?, threadId: String?, continueFlag: Bool) {
            self.threadId = threadId;
            self.continueFlag = continueFlag;
            super.init(sessionObject: sessionObject, message: message, roomJid: roomJid, inviter: inviter, reason: reason, password: password);
        }
    }
    
    public class MediatedInvitation: Invitation {
        
        public override init(sessionObject: SessionObject, message: Message, roomJid: BareJID, inviter: JID?, reason: String?, password: String?) {
            super.init(sessionObject: sessionObject, message: message, roomJid: roomJid, inviter: inviter, reason: reason, password: password);
        }
        
    }
}
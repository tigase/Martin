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

/**
 Module provides support for [XEP-0045: Multi-User Chat]
 
 [XEP-0045: Multi-User Chat]: http://xmpp.org/extensions/xep-0045.html
 */
public class MucModule: Logger, XmppModule, ContextAware, Initializable, EventHandler {
    /// ID of module for lookup in `XmppModulesManager`
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
    
    /// Instance of DefautRoomManager
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
                    
                    context.eventBus.fire(RoomClosedEvent(sessionObject: context.sessionObject, presence: nil, room: room));
                }
            }
        default:
            log("received event of unsupported type", event);
        }
    }
    
    /**
     Decline invitation to MUC room
     - parameter invitation: initation to decline
     - parameter reason: reason why it was declined
     */
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
    
    /**
     Invite user to MUC room
     - parameter room: room for invitation
     - parameter invitee: user to invite
     - parameter reason: reason for invitation
     */
    public func invite(room: Room, invitee: JID, reason: String?) {
        room.invite(invitee, reason: reason);
    }
    
    /**
     Invite user directly to MUC room
     - parameter room: room for invitation
     - parameter invitee: user to invite
     - parameter reason: reason for invitation
     - parameter theadId: thread id for invitation
     */
    public func inviteDirectly(room: Room, invitee: JID, reason: String?, threadId: String?) {
        room.inviteDirectly(invitee, reason: reason, threadId: threadId);
    }
    
    /**
     Join MUC room
     - parameter roomName: name of room to join
     - parameter mucServer: domain of MUC server with room
     - parameter nickname: nickname to use in room
     - parameter password: password for room if needed
     - returns: instance of Room
     */
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
    
    /**
     Leave MUC room
     - parameter room: room to leave
     */
    public func leave(room: Room) {
        if room.state == .joined {
            room._state = .not_joined;
            
            let presence = Presence();
            presence.type = StanzaType.unavailable;
            presence.to = JID(room.roomJid, resource: room.nickname);
            context.writer?.write(presence);
        }
        
        roomsManager.remove(room);
        
        context.eventBus.fire(RoomClosedEvent(sessionObject: context.sessionObject, presence: nil, room: room));
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
        occupant = Occupant(occupant: occupant, presence: presence);
        
        if (presenceOld != nil && presenceOld!.type == nil) && type == StanzaType.unavailable && xUser?.statuses.indexOf(303) != nil {
            let newNickName = xUser?.nick;
            room.remove(occupant!);
            room.addTemp(newNickName!, occupant: occupant!);
        } else if room.state != .joined && xUser?.statuses.indexOf(110) != nil {
            room._state = .joined;
            room.add(occupant!);
            context.eventBus.fire(YouJoinedEvent(sessionObject: context.sessionObject, room: room, nickname: nickname));
        } else if (presenceOld == nil || presenceOld?.type == StanzaType.unavailable) && type == nil {
            if let tmp = room.removeTemp(nickname!) {
                let oldNickname = tmp.nickname;
                room.add(occupant!);
                context.eventBus.fire(OccupantChangedNickEvent(sessionObject: context.sessionObject, presence: presence, room: room, occupant: occupant!, nickname: oldNickname));
            } else {
                room.add(occupant!);
                context.eventBus.fire(OccupantComesEvent(sessionObject: context.sessionObject, presence: presence, room: room, occupant: occupant!, nickname: nickname, xUser: xUser));
            }
        } else if (presenceOld != nil && presenceOld!.type == nil && type == StanzaType.unavailable) {
            room.remove(occupant!);
            context.eventBus.fire(OccupantLeavedEvent(sessionObject: context.sessionObject, presence: presence, room: room, occupant: occupant!, nickname: nickname, xUser: xUser));
        } else {
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

    /**
     Event fired when join request is sent
     */
    public class JoinRequestedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = JoinRequestedEvent();
        
        public let type = "MucModuleJoinRequestedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Presence sent
        public let presence: Presence!;
        /// Room to join
        public let room: Room!;
        /// Nickname to use in room
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
    
    /// Event fired when received message in room
    public class MessageReceivedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = MessageReceivedEvent();
        
        public let type = "MucModuleMessageReceivedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Received message
        public let message: Message!;
        /// Room which delivered message
        public let room: Room!;
        /// Nickname of message sender
        public let nickname: String?;
        /// Timestamp of message
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
    
    /// Event fired when new room is opened locally
    public class NewRoomCreatedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = NewRoomCreatedEvent();
        
        public let type = "MucModuleNewRoomCreatedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Presence in room
        public let presence: Presence!;
        /// Created room
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
    
    /// Event fired when room occupant changes nickname
    public class OccupantChangedNickEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = OccupantChangedNickEvent();
        
        public let type = "MucModuleOccupantChangedNickEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Presence of occupant
        public let presence: Presence!;
        /// Room in which occupant changed nickname
        public let room: Room!;
        /// Occupant
        public let occupant: Occupant!;
        /// Nickname of occupant
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

    /// Event fired when room occupant changes presence
    public class OccupantChangedPresenceEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = OccupantChangedPresenceEvent();
        
        public let type = "MucModuleOccupantChangedPresenceEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// New presence
        public let presence: Presence!;
        /// Room in which occupant changed presence
        public let room: Room!;
        /// Occupant which changed presence
        public let occupant: Occupant!;
        /// Occupant nickname
        public let nickname: String?;
        /// Additional informations from new presence
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
    
    /// Event fired when occupant enters room
    public class OccupantComesEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = OccupantComesEvent();
        
        public let type = "MucModuleOccupantComesEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Occupant presence
        public let presence: Presence!;
        /// Room to which occupant entered
        public let room: Room!;
        /// Occupant
        public let occupant: Occupant!;
        /// Occupant nickname
        public let nickname: String?;
        /// Additonal informations about occupant
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
    
    /// Event fired when occupant leaves room
    public class OccupantLeavedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = OccupantLeavedEvent();
        
        public let type = "MucModuleOccupantLeavedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Occupant presence
        public let presence: Presence!;
        /// Room which occupant left
        public let room: Room!;
        /// Occupant
        public let occupant: Occupant!;
        /// Nickname of occupant
        public let nickname: String?;
        /// Additional informations about occupant
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
    
    /// Event fired when we receive presence of type error from MUC room
    public class PresenceErrorEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = PresenceErrorEvent();
        
        public let type = "MucModulePresenceErrorEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Received presence
        public let presence: Presence!;
        /// Room which sent presence
        public let room: Room!;
        /// Nickname
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
    
    /// Event fired when room is closed (left by us)
    public class RoomClosedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = RoomClosedEvent();
        
        public let type = "MucModuleRoomClosedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Received presence
        public let presence: Presence?;
        /// Closed room
        public let room: Room!;
        
        init() {
            self.sessionObject = nil;
            self.presence = nil;
            self.room = nil;
        }
        
        public init(sessionObject: SessionObject, presence: Presence?, room: Room) {
            self.sessionObject = sessionObject;
            self.presence = presence;
            self.room = room;
        }
    }
    
    /// Event fired when room is joined by us
    public class YouJoinedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = YouJoinedEvent();
        
        public let type = "MucModuleYouJoinedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Joined room
        public let room: Room!;
        /// Joined under nickname
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
    
    /// Event fired when information about declined invitation is received
    public class InvitationDeclinedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = InvitationDeclinedEvent();
        
        public let type = "MucModuleInvitationDeclinedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Received message
        public let message: Message!;
        /// Room
        public let room: Room!;
        /// Invitation decliner
        public let invitee: JID?;
        /// Reason for declining invitation
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
    
    /// Event fired when invitation is received
    public class InvitationReceivedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = InvitationReceivedEvent();
        
        public let type = "MucModuleInvitationReceivedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Received invitation
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
    
    /// Common class for invitations
    public class Invitation {
        /// Instance of `SessionObject` to identify connection which fired event
        public let sessionObject: SessionObject;
        /// Received message
        public let message: Message;
        /// Room JID
        public let roomJid: BareJID;
        /// Sender of invitation
        public let inviter: JID?;
        /// Password for room
        public let password: String?;
        /// Reason for invitation
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
    
    /// Class for direct invitations
    public class DirectInvitation: Invitation {
        /// ThreadID of invitation message
        public let threadId: String?;
        /// Continuation flag
        public let continueFlag: Bool;
        
        public init(sessionObject: SessionObject, message: Message, roomJid: BareJID, inviter: JID?, reason: String?, password: String?, threadId: String?, continueFlag: Bool) {
            self.threadId = threadId;
            self.continueFlag = continueFlag;
            super.init(sessionObject: sessionObject, message: message, roomJid: roomJid, inviter: inviter, reason: reason, password: password);
        }
    }
    
    /// Class for mediated invitations over MUC component
    public class MediatedInvitation: Invitation {
        
        public override init(sessionObject: SessionObject, message: Message, roomJid: BareJID, inviter: JID?, reason: String?, password: String?) {
            super.init(sessionObject: sessionObject, message: message, roomJid: roomJid, inviter: inviter, reason: reason, password: password);
        }
        
    }
}
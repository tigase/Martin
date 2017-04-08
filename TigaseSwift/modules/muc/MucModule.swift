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
open class MucModule: Logger, XmppModule, ContextAware, Initializable, EventHandler {
    /// ID of module for lookup in `XmppModulesManager`
    open static let ID = "muc";
    
    fileprivate static let DIRECT_INVITATION = Criteria.name("message", containsAttribute: "from").add(Criteria.name("x", xmlns: "jabber:x:conference"));
    fileprivate static let MEDIATED_INVITATION = Criteria.name("message", containsAttribute: "from").add(Criteria.name("x", xmlns: "http://jabber.org/protocol/muc#user").add(Criteria.name("invite")));
    fileprivate static let MEDIATED_INVITATION_DECLINE = Criteria.name("message", containsAttribute: "from").add(Criteria.name("x", xmlns: "http://jabber.org/protocol/muc#user").add(Criteria.name("decline")));

    
    open let id = ID;
    
    open var context:Context! {
        didSet {
            if oldValue != nil {
                oldValue.eventBus.unregister(handler: self, for: SessionObject.ClearedEvent.TYPE);
            }
            roomsManager?.context = context;
            if context != nil {
                context.eventBus.register(handler: self, for: SessionObject.ClearedEvent.TYPE);
            }
        }
    }
    
    open let criteria = Criteria.or(
        Criteria.name("message", types: [StanzaType.groupchat], containsAttribute: "from"),
        Criteria.name("presence", containsAttribute: "from"),
        DIRECT_INVITATION,
        MEDIATED_INVITATION,
        MEDIATED_INVITATION_DECLINE
        );
    
    open let features = [String]();
    
    /// Instance of DefautRoomManager
    open var roomsManager: DefaultRoomsManager! {
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
    
    open func initialize() {
        if roomsManager == nil {
            roomsManager = DefaultRoomsManager();
        }
        roomsManager.context = context;
        roomsManager.initialize();
    }
    
    open func handle(event: Event) {
        switch event {
        case let sec as SessionObject.ClearedEvent:
            if sec.scopes.contains(SessionObject.Scope.session) {
                for room in roomsManager.getRooms() {
                    room._state = .not_joined;

                    let occupants = room.presences.values;
                    for occupant in occupants {
                        room.remove(occupant: occupant);
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
    open func decline(invitation: Invitation, reason: String?) {
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
     Retrieve configuration of MUC room (only room owner is allowed to do so)
     - parameter roomJid: jid of MUC room
     - parameter onSuccess: called where response with result is received
     - parameter onError: called when received error or request timed out
     */
    open func getRoomConfiguration(roomJid: JID, onSuccess: @escaping (JabberDataElement)->Void, onError: ((ErrorCondition?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = roomJid;
        
        iq.addChild(Element(name: "query", xmlns: "http://jabber.org/protocol/muc#owner"));
        context.writer?.write(iq, callback: {(stanza:Stanza?) in
            let type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                let data = JabberDataElement(from: stanza!.findChild(name: "query", xmlns: "http://jabber.org/protocol/muc#owner")?.findChild(name: "x", xmlns: "jabber:x:data"));
                if data == nil {
                    onError?(ErrorCondition.undefined_condition)
                } else {
                    onSuccess(data!);
                }
            default:
                let errorCondition = stanza?.errorCondition;
                onError?(errorCondition);
            }
        });
    }
    
    /**
     Set configuration of MUC room (only room owner is allowed to do so)
     - parameter roomJid: jid of MUC room
     - parameter configuration: room configuration
     - parameter onSuccess: called where response with result is received
     - parameter onError: called when received error or request timed out
     */
    open func setRoomConfiguration(roomJid: JID, configuration: JabberDataElement, onSuccess: @escaping ()->Void, onError: ((ErrorCondition?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = roomJid;
        
        let query = Element(name: "query", xmlns: "http://jabber.org/protocol/muc#owner");
        iq.addChild(query);
        query.addChild(configuration.submitableElement(type: .submit));
        
        context.writer?.write(iq, callback: {(stanza:Stanza?) in
            let type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                onSuccess();
            default:
                let errorCondition = stanza?.errorCondition;
                onError?(errorCondition);
            }
        });
    }
    
    /**
     Invite user to MUC room
     - parameter room: room for invitation
     - parameter invitee: user to invite
     - parameter reason: reason for invitation
     */
    open func invite(to room: Room, invitee: JID, reason: String?) {
        room.invite(invitee, reason: reason);
    }
    
    /**
     Invite user directly to MUC room
     - parameter room: room for invitation
     - parameter invitee: user to invite
     - parameter reason: reason for invitation
     - parameter theadId: thread id for invitation
     */
    open func inviteDirectly(to room: Room, invitee: JID, reason: String?, threadId: String?) {
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
    open func join(roomName: String, mucServer: String, nickname: String, password: String? = nil) -> Room {
        let roomJid = BareJID(localPart: roomName, domain: mucServer);
        
        var room = roomsManager.getRoom(for: roomJid);
        if room != nil {
            return room!;
        }
        room = roomsManager.createRoomInstance(roomJid: roomJid, nickname: nickname, password: password);
        roomsManager.register(room: room!);
        let presence = room!.rejoin();
        
        context.eventBus.fire(JoinRequestedEvent(sessionObject: context.sessionObject, presence: presence, room: room!, nickname: nickname));
        
        return room!;
    }
    
    /**
     Leave MUC room
     - parameter room: room to leave
     */
    open func leave(room: Room) {
        if room.state == .joined {
            room._state = .not_joined;
            
            let presence = Presence();
            presence.type = StanzaType.unavailable;
            presence.to = JID(room.roomJid, resource: room.nickname);
            context.writer?.write(presence);
        }
        
        roomsManager.remove(room: room);
        
        context.eventBus.fire(RoomClosedEvent(sessionObject: context.sessionObject, presence: nil, room: room));
    }
    
    open func process(stanza: Stanza) throws {
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
    
    func processPresence(_ presence: Presence) throws {
        let from = presence.from!;
        let roomJid = from.bareJid;
        let nickname = from.resource;
        let room:Room! = roomsManager.getRoom(for: roomJid);
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
        
        let xUser = XMucUserElement.extract(from: presence);
        
        var occupant = room.presences[nickname!];
        let presenceOld = occupant?.presence;
        occupant = MucOccupant(occupant: occupant, presence: presence);
        
        if (presenceOld != nil && presenceOld!.type == nil) && type == StanzaType.unavailable && xUser?.statuses.index(of: 303) != nil {
            let newNickName = xUser?.nick;
            room.remove(occupant: occupant!);
            room.addTemp(nickname: newNickName!, occupant: occupant!);
        } else if room.state != .joined && xUser?.statuses.index(of: 110) != nil {
            room._state = .joined;
            room.add(occupant: occupant!);
            context.eventBus.fire(YouJoinedEvent(sessionObject: context.sessionObject, room: room, nickname: nickname));
        } else if (presenceOld == nil || presenceOld?.type == StanzaType.unavailable) && type == nil {
            if let tmp = room.removeTemp(nickname: nickname!) {
                let oldNickname = tmp.nickname;
                room.add(occupant: occupant!);
                context.eventBus.fire(OccupantChangedNickEvent(sessionObject: context.sessionObject, presence: presence, room: room, occupant: occupant!, nickname: oldNickname));
            } else {
                room.add(occupant: occupant!);
                context.eventBus.fire(OccupantComesEvent(sessionObject: context.sessionObject, presence: presence, room: room, occupant: occupant!, nickname: nickname, xUser: xUser));
            }
        } else if (presenceOld != nil && presenceOld!.type == nil && type == StanzaType.unavailable) {
            room.remove(occupant: occupant!);
            context.eventBus.fire(OccupantLeavedEvent(sessionObject: context.sessionObject, presence: presence, room: room, occupant: occupant!, nickname: nickname, xUser: xUser));
        } else {
            context.eventBus.fire(OccupantChangedPresenceEvent(sessionObject: context.sessionObject, presence: presence, room: room, occupant: occupant!, nickname: nickname, xUser: xUser));
        }
        
        if xUser != nil && xUser?.statuses.index(of: 201) != nil {
            context.eventBus.fire(NewRoomCreatedEvent(sessionObject: context.sessionObject, presence: presence, room: room));
        }
    }
    
    func processMessage(_ message: Message) {
        let from = message.from!;
        let roomJid = from.bareJid;
        let nickname = from.resource;
        
        let room:Room! = roomsManager.getRoom(for: roomJid);
        guard room != nil else {
            return;
        }
        
        let timestamp = message.delay?.stamp ?? Date();
        if room.state != .joined {
            room._state = .joined;
            log("Message while not joined in room:", room, " with nickname:", nickname);
            
            context.eventBus.fire(YouJoinedEvent(sessionObject: context.sessionObject, room: room, nickname: nickname ?? room.nickname));
        }
        context.eventBus.fire(MessageReceivedEvent(sessionObject: context.sessionObject, message: message, room: room, nickname: nickname, timestamp: timestamp));
        room.lastMessageDate = timestamp;
    }
    
    func processDirectInvitationMessage(_ message: Message) {
        let x = message.findChild(name: "x", xmlns: "jabber:x:conference");
        let contStr = x?.getAttribute("continue");
        let cont = contStr == "true" || contStr == "1";
        
        let invitation = DirectInvitation(sessionObject: context.sessionObject, message: message, roomJid: BareJID(x!.getAttribute("jid")!), inviter: message.from!, reason: x?.getAttribute("reason"), password: x?.getAttribute("password"), threadId: x?.getAttribute("thread"), continueFlag: cont);
        
        context.eventBus.fire(InvitationReceivedEvent(sessionObject: context.sessionObject, invitation: invitation));
    }
    
    func processMediatedInvitationMessage(_ message: Message) {
        let x = message.findChild(name: "x", xmlns: "http://jabber.org/protocol/muc#user");
        let invite = x?.findChild(name: "invite");
        
        let invitation = MediatedInvitation(sessionObject: context.sessionObject, message: message, roomJid: message.from!.bareJid, inviter: JID(invite?.stringValue), reason: invite?.getAttribute("reason"), password: x?.getAttribute("password"));
        
        context.eventBus.fire(InvitationReceivedEvent(sessionObject: context.sessionObject, invitation: invitation));
    }
    
    func processInvitationDeclinedMessage(_ message: Message) {
        let from = message.from!.bareJid;
        let room = roomsManager.getRoom(for: from);
        guard room != nil else {
            return;
        }
        
        let decline = message.findChild(name: "x", xmlns: "http://jabber.org/protocol/muc#user")?.findChild(name: "decline");
        let reason = decline?.findChild(name: "reason")?.stringValue;
        let invitee = decline?.getAttribute("from");
        
        context.eventBus.fire(InvitationDeclinedEvent(sessionObject: context.sessionObject, message: message, room: room!, invitee: invitee == nil ? nil : JID(invitee!), reason: reason));
    }

    /**
     Event fired when join request is sent
     */
    open class JoinRequestedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = JoinRequestedEvent();
        
        open let type = "MucModuleJoinRequestedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// Presence sent
        open let presence: Presence!;
        /// Room to join
        open let room: Room!;
        /// Nickname to use in room
        open let nickname: String?;
        
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
    open class MessageReceivedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = MessageReceivedEvent();
        
        open let type = "MucModuleMessageReceivedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// Received message
        open let message: Message!;
        /// Room which delivered message
        open let room: Room!;
        /// Nickname of message sender
        open let nickname: String?;
        /// Timestamp of message
        open let timestamp: Date!;
        
        init() {
            self.sessionObject = nil;
            self.message = nil;
            self.room = nil;
            self.nickname = nil;
            self.timestamp = nil;
        }
        
        public init(sessionObject: SessionObject, message: Message, room: Room, nickname: String?, timestamp: Date) {
            self.sessionObject = sessionObject;
            self.message = message;
            self.room = room;
            self.nickname = nickname;
            self.timestamp = timestamp;
        }
        
    }
    
    /// Event fired when new room is opened locally
    open class NewRoomCreatedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = NewRoomCreatedEvent();
        
        open let type = "MucModuleNewRoomCreatedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// Presence in room
        open let presence: Presence!;
        /// Created room
        open let room: Room!;
        
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
    open class OccupantChangedNickEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = OccupantChangedNickEvent();
        
        open let type = "MucModuleOccupantChangedNickEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// Presence of occupant
        open let presence: Presence!;
        /// Room in which occupant changed nickname
        open let room: Room!;
        /// Occupant
        open let occupant: MucOccupant!;
        /// Nickname of occupant
        open let nickname: String?;
        
        init() {
            self.sessionObject = nil;
            self.presence = nil;
            self.room = nil;
            self.occupant = nil;
            self.nickname = nil;
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room, occupant: MucOccupant, nickname: String?) {
            self.sessionObject = sessionObject;
            self.presence = presence;
            self.room = room;
            self.occupant = occupant;
            self.nickname = nickname;
        }
    }

    /// Event fired when room occupant changes presence
    open class OccupantChangedPresenceEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = OccupantChangedPresenceEvent();
        
        open let type = "MucModuleOccupantChangedPresenceEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// New presence
        open let presence: Presence!;
        /// Room in which occupant changed presence
        open let room: Room!;
        /// Occupant which changed presence
        open let occupant: MucOccupant!;
        /// Occupant nickname
        open let nickname: String?;
        /// Additional informations from new presence
        open let xUser: XMucUserElement?;
        
        init() {
            self.sessionObject = nil;
            self.presence = nil;
            self.room = nil;
            self.occupant = nil;
            self.nickname = nil;
            self.xUser = nil;
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room, occupant: MucOccupant, nickname: String?, xUser: XMucUserElement?) {
            self.sessionObject = sessionObject;
            self.presence = presence;
            self.room = room;
            self.occupant = occupant;
            self.nickname = nickname;
            self.xUser = xUser;
        }
    }
    
    /// Event fired when occupant enters room
    open class OccupantComesEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = OccupantComesEvent();
        
        open let type = "MucModuleOccupantComesEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// Occupant presence
        open let presence: Presence!;
        /// Room to which occupant entered
        open let room: Room!;
        /// Occupant
        open let occupant: MucOccupant!;
        /// Occupant nickname
        open let nickname: String?;
        /// Additonal informations about occupant
        open let xUser: XMucUserElement?;
        
        init() {
            self.sessionObject = nil;
            self.presence = nil;
            self.room = nil;
            self.occupant = nil;
            self.nickname = nil;
            self.xUser = nil;
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room, occupant: MucOccupant, nickname: String?, xUser: XMucUserElement?) {
            self.sessionObject = sessionObject;
            self.presence = presence;
            self.room = room;
            self.occupant = occupant;
            self.nickname = nickname;
            self.xUser = xUser;
        }
    }
    
    /// Event fired when occupant leaves room
    open class OccupantLeavedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = OccupantLeavedEvent();
        
        open let type = "MucModuleOccupantLeavedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// Occupant presence
        open let presence: Presence!;
        /// Room which occupant left
        open let room: Room!;
        /// Occupant
        open let occupant: MucOccupant!;
        /// Nickname of occupant
        open let nickname: String?;
        /// Additional informations about occupant
        open let xUser: XMucUserElement?;
        
        init() {
            self.sessionObject = nil;
            self.presence = nil;
            self.room = nil;
            self.occupant = nil;
            self.nickname = nil;
            self.xUser = nil;
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room, occupant: MucOccupant, nickname: String?, xUser: XMucUserElement?) {
            self.sessionObject = sessionObject;
            self.presence = presence;
            self.room = room;
            self.occupant = occupant;
            self.nickname = nickname;
            self.xUser = xUser;
        }
    }
    
    /// Event fired when we receive presence of type error from MUC room
    open class PresenceErrorEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = PresenceErrorEvent();
        
        open let type = "MucModulePresenceErrorEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// Received presence
        open let presence: Presence!;
        /// Room which sent presence
        open let room: Room!;
        /// Nickname
        open let nickname: String?;
        
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
    open class RoomClosedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = RoomClosedEvent();
        
        open let type = "MucModuleRoomClosedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// Received presence
        open let presence: Presence?;
        /// Closed room
        open let room: Room!;
        
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
    open class YouJoinedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = YouJoinedEvent();
        
        open let type = "MucModuleYouJoinedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// Joined room
        open let room: Room!;
        /// Joined under nickname
        open let nickname: String?;
        
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
    open class InvitationDeclinedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = InvitationDeclinedEvent();
        
        open let type = "MucModuleInvitationDeclinedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// Received message
        open let message: Message!;
        /// Room
        open let room: Room!;
        /// Invitation decliner
        open let invitee: JID?;
        /// Reason for declining invitation
        open let reason: String?;
        
        fileprivate init() {
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
    open class InvitationReceivedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = InvitationReceivedEvent();
        
        open let type = "MucModuleInvitationReceivedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// Received invitation
        open let invitation: Invitation!;
        
        fileprivate init() {
            self.sessionObject = nil;
            self.invitation = nil;
        }
        
        public init(sessionObject: SessionObject, invitation: Invitation) {
            self.sessionObject = sessionObject;
            self.invitation = invitation;
        }
        
    }
    
    /// Common class for invitations
    open class Invitation {
        /// Instance of `SessionObject` to identify connection which fired event
        open let sessionObject: SessionObject;
        /// Received message
        open let message: Message;
        /// Room JID
        open let roomJid: BareJID;
        /// Sender of invitation
        open let inviter: JID?;
        /// Password for room
        open let password: String?;
        /// Reason for invitation
        open let reason: String?;
        
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
    open class DirectInvitation: Invitation {
        /// ThreadID of invitation message
        open let threadId: String?;
        /// Continuation flag
        open let continueFlag: Bool;
        
        public init(sessionObject: SessionObject, message: Message, roomJid: BareJID, inviter: JID?, reason: String?, password: String?, threadId: String?, continueFlag: Bool) {
            self.threadId = threadId;
            self.continueFlag = continueFlag;
            super.init(sessionObject: sessionObject, message: message, roomJid: roomJid, inviter: inviter, reason: reason, password: password);
        }
    }
    
    /// Class for mediated invitations over MUC component
    open class MediatedInvitation: Invitation {
        
        public override init(sessionObject: SessionObject, message: Message, roomJid: BareJID, inviter: JID?, reason: String?, password: String?) {
            super.init(sessionObject: sessionObject, message: message, roomJid: roomJid, inviter: inviter, reason: reason, password: password);
        }
        
    }
}

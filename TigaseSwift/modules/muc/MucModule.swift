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
    public static let ID = "muc";
    
    fileprivate static let DIRECT_INVITATION = Criteria.name("message", containsAttribute: "from").add(Criteria.name("x", xmlns: "jabber:x:conference"));
    fileprivate static let MEDIATED_INVITATION = Criteria.name("message", containsAttribute: "from").add(Criteria.name("x", xmlns: "http://jabber.org/protocol/muc#user").add(Criteria.name("invite")));
    fileprivate static let MEDIATED_INVITATION_DECLINE = Criteria.name("message", containsAttribute: "from").add(Criteria.name("x", xmlns: "http://jabber.org/protocol/muc#user").add(Criteria.name("decline")));

    
    public let id = ID;
    
    open var context:Context! {
        didSet {
            if oldValue != nil {
                oldValue.eventBus.unregister(handler: self, for: SessionObject.ClearedEvent.TYPE, StreamManagementModule.FailedEvent.TYPE);
            }
            roomsManager?.context = context;
            if context != nil {
                context.eventBus.register(handler: self, for: SessionObject.ClearedEvent.TYPE, StreamManagementModule.FailedEvent.TYPE);
            }
        }
    }
    
    public let criteria = Criteria.or(
        Criteria.name("message", types: [StanzaType.groupchat, StanzaType.error], containsAttribute: "from"),
        Criteria.name("presence", containsAttribute: "from"),
        DIRECT_INVITATION,
        MEDIATED_INVITATION,
        MEDIATED_INVITATION_DECLINE
        );
    
    public let features = [String]();
    
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
                markRoomsAsNotJoined();
            }
        case is StreamManagementModule.FailedEvent:
            markRoomsAsNotJoined();
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
            if let inviter = invitation.inviter {
                decline.setAttribute("to", value: inviter.stringValue)
            }
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
    
    open func getRoomAffiliations(from room: Room, with affiliation: MucAffiliation, completionHandler: @escaping ([RoomAffiliation]?, ErrorCondition?)->Void) {
        let userRole = (room.presences[room.nickname]?.role ?? .none);
        guard userRole == .participant || userRole == .moderator else {
            completionHandler(nil, ErrorCondition.forbidden);
            return;
        };
        
        let iq = Iq();
        iq.to = room.jid;
        iq.type = StanzaType.get;
        
        let query = Element(name: "query", xmlns: "http://jabber.org/protocol/muc#admin");
        iq.addChild(query);
        query.addChild(Element(name: "item", attributes: ["affiliation": affiliation.rawValue]));
        
        context.writer?.write(iq, callback: { (stanza: Stanza?) in
            let type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                let affiliations = stanza?.findChild(name: "query", xmlns: "http://jabber.org/protocol/muc#admin")?.mapChildren(transform: { el in
                    return RoomAffiliation(from: el);
                }, filter: { el -> Bool in return el.name == "item"}) ?? [];
                completionHandler(affiliations, nil);
            default:
                completionHandler(nil, stanza?.errorCondition ?? ErrorCondition.remote_server_timeout);
                break;
            }
        });
    }
    
    open func setRoomAffiliations(to room: Room, changedAffiliations affiliations: [RoomAffiliation], completionHandler: @escaping (ErrorCondition?)->Void) {
        let userAffiliation = (room.presences[room.nickname]?.affiliation ?? .none);
        guard userAffiliation == .admin || userAffiliation == .owner else {
            completionHandler(ErrorCondition.forbidden);
            return;
        };

        let iq = Iq();
        iq.to = room.jid;
        iq.type = StanzaType.set;
        
        let query = Element(name: "query", xmlns: "http://jabber.org/protocol/muc#admin");
        iq.addChild(query);
        query.addChildren(affiliations.map({ aff -> Element in
            let el = Element(name: "item");
            el.setAttribute("jid", value: aff.jid.stringValue);
            el.setAttribute("affiliation", value: aff.affiliation.rawValue);
            return el;
        }));
        
        context.writer?.write(iq, callback: { (stanza: Stanza?) in
            let type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                completionHandler(nil);
            default:
                completionHandler(stanza?.errorCondition ?? ErrorCondition.remote_server_timeout);
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
    open func join(roomName: String, mucServer: String, nickname: String, password: String? = nil, ifCreated: ((Room)->Void)? = nil) -> Room {
        let roomJid = BareJID(localPart: roomName, domain: mucServer);
        
        return roomsManager.getRoomOrCreate(for: roomJid, nickname: nickname, password: password, onCreate: { (room) in
            room.onRoomCreated = ifCreated;            
            let presence = room.rejoin();
            self.context.eventBus.fire(JoinRequestedEvent(sessionObject: self.context.sessionObject, presence: presence, room: room, nickname: nickname));
        });
    }
    
    /**
     Destroy MUC room
     - parameter room: room to destroy
     */
    @discardableResult
    open func destroy(room: Room) -> Bool {
        guard room.state == .joined && room.presences[room.nickname]?.affiliation == .owner else {
            return false;
        }
        
        let iq = Iq();
        iq.type = .set;
        iq.to = room.jid;

        let query = Element(name: "query", xmlns: "http://jabber.org/protocol/muc#owner");
        query.addChild(Element(name: "destroy"));
        
        iq.addChild(query);
        
        context.writer?.write(iq);
        
        roomsManager.remove(room: room);
        
        room._state = .destroyed;
        context.eventBus.fire(RoomClosedEvent(sessionObject: context.sessionObject, presence: nil, room: room));
        
        return true;
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
        
        room._state = .destroyed;
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
            context.eventBus.fire(RoomClosedEvent(sessionObject: context.sessionObject, presence: presence, room: room));
            return;
        }
        
        let xUser = XMucUserElement.extract(from: presence);
        
        var occupant = room.presences[nickname!];
        let presenceOld = occupant?.presence;
        occupant = MucOccupant(occupant: occupant, presence: presence);
        
        if (presenceOld != nil && presenceOld!.type == nil) && type == StanzaType.unavailable && xUser?.statuses.firstIndex(of: 303) != nil {
            let newNickName = xUser?.nick;
            room.remove(occupant: occupant!);
            room.addTemp(nickname: newNickName!, occupant: occupant!);
        } else if room.state != .joined && xUser?.statuses.firstIndex(of: 110) != nil {
            room._state = .joined;
            room.add(occupant: occupant!);
            if xUser?.statuses.firstIndex(of: 201) == nil {
                room.onRoomCreated = nil;
            }
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
        
        if xUser != nil && xUser?.statuses.firstIndex(of: 201) != nil {
            if let onRoomCreated = room.onRoomCreated {
                room.onRoomCreated = nil;
                onRoomCreated(room);
            }

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
        if room.state != .joined && message.type != StanzaType.error {
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
        
        let invitation = MediatedInvitation(sessionObject: context.sessionObject, message: message, roomJid: message.from!.bareJid, inviter: JID(invite?.getAttribute("from")), reason: invite?.getAttribute("reason"), password: x?.getAttribute("password"));
        
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
        
        context.eventBus.fire(InvitationDeclinedEvent(sessionObject: context.sessionObject, message: message, room: room!, invitee: JID(invitee), reason: reason));
    }

    fileprivate func markRoomsAsNotJoined() {
        for room in roomsManager.getRooms() {
            room._state = .not_joined;
            
            context.eventBus.fire(RoomClosedEvent(sessionObject: context.sessionObject, presence: nil, room: room));
        }
    }
    
    /**
     Event fired when join request is sent
     */
    open class JoinRequestedEvent: Event {
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
    open class MessageReceivedEvent: Event {
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
        public let timestamp: Date!;
        
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
    
    open class AbstractOccupantEvent: Event {
        
        public let type: String;
        
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// New presence
        public let presence: Presence!;
        /// Room in which occupant changed presence
        public let room: Room!;
        /// Occupant which changed presence
        public let occupant: MucOccupant!;
        /// Occupant nickname
        public let nickname: String?;
        /// Additional informations from new presence
        public let xUser: XMucUserElement?;
        
        init(type: String, sessionObject: SessionObject?, presence: Presence?, room: Room?, occupant: MucOccupant?, nickname: String?, xUser: XMucUserElement? = nil) {
            self.type = type;
            self.sessionObject = sessionObject;
            self.presence = presence;
            self.room = room;
            self.occupant = occupant;
            self.nickname = nickname;
            self.xUser = xUser;
        }
    }
    
    /// Event fired when room occupant changes nickname
    open class OccupantChangedNickEvent: AbstractOccupantEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = OccupantChangedNickEvent();
        
        init() {
            super.init(type: "MucModuleOccupantChangedNickEvent", sessionObject: nil, presence: nil, room: nil, occupant: nil, nickname: nil, xUser: nil);
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room, occupant: MucOccupant, nickname: String?) {
            super.init(type: "MucModuleOccupantChangedNickEvent", sessionObject: sessionObject, presence: presence, room: room, occupant: occupant, nickname: nickname, xUser: nil);
        }
    }
    
    /// Event fired when room occupant changes presence
    open class OccupantChangedPresenceEvent: AbstractOccupantEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = OccupantChangedPresenceEvent();
        
        init() {
            super.init(type: "MucModuleOccupantChangedPresenceEvent", sessionObject: nil, presence: nil, room: nil, occupant: nil, nickname: nil, xUser: nil);
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room, occupant: MucOccupant, nickname: String?, xUser: XMucUserElement?) {
            super.init(type: "MucModuleOccupantChangedPresenceEvent", sessionObject: sessionObject, presence: presence, room: room, occupant: occupant, nickname: nickname, xUser: xUser);
        }
    }
    
    /// Event fired when occupant enters room
    open class OccupantComesEvent: AbstractOccupantEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = OccupantComesEvent();
        
        init() {
            super.init(type: "MucModuleOccupantComesEvent", sessionObject: nil, presence: nil, room: nil, occupant: nil, nickname: nil, xUser: nil);
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room, occupant: MucOccupant, nickname: String?, xUser: XMucUserElement?) {
            super.init(type: "MucModuleOccupantComesEvent", sessionObject: sessionObject, presence: presence, room: room, occupant: occupant, nickname: nickname, xUser: xUser);
        }
        
    }
    
    /// Event fired when occupant leaves room
    open class OccupantLeavedEvent: AbstractOccupantEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = OccupantLeavedEvent();
        
        init() {
            super.init(type: "MucModuleOccupantLeavedEvent", sessionObject: nil, presence: nil, room: nil, occupant: nil, nickname: nil, xUser: nil);
        }
        
        public init(sessionObject: SessionObject, presence: Presence, room: Room, occupant: MucOccupant, nickname: String?, xUser: XMucUserElement?) {
            super.init(type: "MucModuleOccupantLeavedEvent", sessionObject: sessionObject, presence: presence, room: room, occupant: occupant, nickname: nickname, xUser: xUser);
        }
        
    }
    
    /// Event fired when we receive presence of type error from MUC room
    open class PresenceErrorEvent: Event {
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
    open class RoomClosedEvent: Event {
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
    open class YouJoinedEvent: Event {
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
    open class InvitationDeclinedEvent: Event {
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
        public static let TYPE = InvitationReceivedEvent();
        
        public let type = "MucModuleInvitationReceivedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Received invitation
        public let invitation: Invitation!;
        
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
    open class DirectInvitation: Invitation {
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
    open class MediatedInvitation: Invitation {
        
        public override init(sessionObject: SessionObject, message: Message, roomJid: BareJID, inviter: JID?, reason: String?, password: String?) {
            super.init(sessionObject: sessionObject, message: message, roomJid: roomJid, inviter: inviter, reason: reason, password: password);
        }
        
    }
    
    public enum RoomError {
        case nicknameLockedDown
        case invalidPassword
        case registrationRequired
        case banned
        case nicknameConflict
        case maxUsersExceeded
        case roomLocked
        
        public static func from(presence: Presence) -> RoomError? {
            guard let type = presence.type, type == .error, let error = presence.errorCondition else {
                return nil;
            }
            switch error {
            case .not_acceptable:
                return .nicknameLockedDown;
            case .not_authorized:
                return .invalidPassword;
            case .registration_required:
                return .registrationRequired;
            case .forbidden:
                return .banned;
            case .conflict:
                return .nicknameConflict;
            case .service_unavailable:
                return .maxUsersExceeded;
            case .item_not_found:
                return .roomLocked;
            default:
                return nil;
            }
        }
    }
    
    open class RoomAffiliation {
        
        public let jid: JID;
        public let affiliation: MucAffiliation;
        public let nickname: String?;
        public let role: MucRole?;
        
        public convenience init?(from el: Element) {
            guard let jid = JID(el.getAttribute("jid")), let affiliation = MucAffiliation(rawValue: el.getAttribute("affiliation") ?? "") else {
                return nil;
            }
            self.init(jid: jid, affiliation: affiliation, nickname: el.getAttribute("nick"), role: MucRole(rawValue: el.getAttribute("role") ?? ""));
        }
        
        public init(jid: JID, affiliation: MucAffiliation, nickname: String? = nil, role: MucRole? = nil) {
            self.jid = jid;
            self.affiliation = affiliation;
            self.nickname = nickname;
            self.role = role;
        }
    }
}

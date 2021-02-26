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
import TigaseLogging
import Combine

extension XmppModuleIdentifier {
    public static var muc: XmppModuleIdentifier<MucModule> {
        return MucModule.IDENTIFIER;
    }
}

/**
 Module provides support for [XEP-0045: Multi-User Chat]
 
 [XEP-0045: Multi-User Chat]: http://xmpp.org/extensions/xep-0045.html
 */
open class MucModule: XmppModuleBase, XmppModule, Resetable {
    /// ID of module for lookup in `XmppModulesManager`
    public static let IDENTIFIER = XmppModuleIdentifier<MucModule>();
    public static let ID = "muc";
    
    fileprivate static let DIRECT_INVITATION = Criteria.name("message", containsAttribute: "from").add(Criteria.name("x", xmlns: "jabber:x:conference"));
    fileprivate static let MEDIATED_INVITATION = Criteria.name("message", containsAttribute: "from").add(Criteria.name("x", xmlns: "http://jabber.org/protocol/muc#user").add(Criteria.name("invite")));
    fileprivate static let MEDIATED_INVITATION_DECLINE = Criteria.name("message", containsAttribute: "from").add(Criteria.name("x", xmlns: "http://jabber.org/protocol/muc#user").add(Criteria.name("decline")));

    private let logger = Logger(subsystem: "TigaseSwift", category: "MucModule");
    
    public let criteria = Criteria.or(
        Criteria.name("message", types: [StanzaType.groupchat, StanzaType.error], containsAttribute: "from"),
        Criteria.name("presence", containsAttribute: "from"),
        DIRECT_INVITATION,
        MEDIATED_INVITATION,
        MEDIATED_INVITATION_DECLINE
        );
    
    open override var context: Context? {
        didSet {
            oldValue?.unregister(lifecycleAware: roomManager);
            context?.register(lifecycleAware: roomManager);
        }
    }
    
    public let features = [String]();
    
    public let roomManager: RoomManager;
    
    public let messagesPublisher = PassthroughSubject<MessageReceived, Never>();
    public let inivitationsPublisher = PassthroughSubject<Invitation, Never>();
    
    public init(roomManager: RoomManager) {
        self.roomManager = roomManager;
    }
        
    open func reset(scopes: Set<ResetableScope>) {
        if scopes.contains(.session) {
            markRoomsAsNotJoined();
            self.context?.dispatcher.async {
                let futures = self.joinPromises.values;
                self.joinPromises.removeAll();
                for future in futures {
                    future(.failure(XMPPError.remote_server_timeout));
                }
            }
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
            write(message);
        }
    }
    
    /**
     Retrieve configuration of MUC room (only room owner is allowed to do so)
     - parameter roomJid: jid of MUC room
     - parameter onSuccess: called where response with result is received
     - parameter onError: called when received error or request timed out
     */
    open func getRoomConfiguration(roomJid: JID, completionHandler: @escaping (Result<JabberDataElement,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = roomJid;
        
        iq.addChild(Element(name: "query", xmlns: "http://jabber.org/protocol/muc#owner"));
        write(iq, completionHandler: { result in
            completionHandler(result.flatMap({ stanza in
                guard let data = JabberDataElement(from: stanza.findChild(name: "query", xmlns: "http://jabber.org/protocol/muc#owner")?.findChild(name: "x", xmlns: "jabber:x:data")) else {
                    return .failure(.undefined_condition);
                }
                
                return .success(data);
            }))
        });
    }
    
    /**
     Set configuration of MUC room (only room owner is allowed to do so)
     - parameter roomJid: jid of MUC room
     - parameter configuration: room configuration
     - parameter onSuccess: called where response with result is received
     - parameter onError: called when received error or request timed out
     */
    open func setRoomConfiguration(roomJid: JID, configuration: JabberDataElement, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = roomJid;
        
        let query = Element(name: "query", xmlns: "http://jabber.org/protocol/muc#owner");
        iq.addChild(query);
        query.addChild(configuration.submitableElement(type: .submit));
        
        write(iq, completionHandler: { result in
            completionHandler(result.map { _ in Void() });
        });
    }
    
    open func getRoomAffiliations(from room: RoomProtocol, with affiliation: MucAffiliation, completionHandler: @escaping (Result<[RoomAffiliation],XMPPError>)->Void) {
        let userRole = room.occupant(nickname: room.nickname)?.role ?? .none;
        guard userRole == .participant || userRole == .moderator else {
            completionHandler(.failure(.forbidden("Only participant or moderator can ask for room affiliations!")));
            return;
        };
        
        let iq = Iq();
        iq.to = JID(room.jid);
        iq.type = StanzaType.get;
        
        let query = Element(name: "query", xmlns: "http://jabber.org/protocol/muc#admin");
        iq.addChild(query);
        query.addChild(Element(name: "item", attributes: ["affiliation": affiliation.rawValue]));
        
        write(iq, completionHandler: { result in
            completionHandler(result.map({ stanza in
                return stanza.findChild(name: "query", xmlns: "http://jabber.org/protocol/muc#admin")?.mapChildren(transform: { el in
                    return RoomAffiliation(from: el);
                }, filter: { el -> Bool in return el.name == "item"}) ?? [];
            }))
        });
    }
    
    open func setRoomAffiliations(to room: RoomProtocol, changedAffiliations affiliations: [RoomAffiliation], completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        let userAffiliation = room.occupant(nickname: room.nickname)?.affiliation ?? .none;
        guard userAffiliation == .admin || userAffiliation == .owner else {
            completionHandler(.failure(.forbidden("Only room admin or owner can set room affiliations!")));
            return;
        };

        let iq = Iq();
        iq.to = JID(room.jid);
        iq.type = StanzaType.set;
        
        let query = Element(name: "query", xmlns: "http://jabber.org/protocol/muc#admin");
        iq.addChild(query);
        query.addChildren(affiliations.map({ aff -> Element in
            let el = Element(name: "item");
            el.setAttribute("jid", value: aff.jid.stringValue);
            el.setAttribute("affiliation", value: aff.affiliation.rawValue);
            return el;
        }));
        
        write(iq, completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        });
    }
    
    open func setRoomSubject(roomJid: BareJID, newSubject: String?) {
        let message = Message();
        message.id = UUID().uuidString;
        message.to = JID(roomJid);
        message.type = .groupchat;
        message.subject = newSubject;
        if newSubject == nil {
            message.element.addChild(Element(name: "subject"));
        }
        write(message)
    }
    
    
    /**
     Invite user to MUC room
     - parameter room: room for invitation
     - parameter invitee: user to invite
     - parameter reason: reason for invitation
     */
    open func invite(to room: RoomProtocol, invitee: JID, reason: String?) {
        room.invite(invitee, reason: reason);
    }
    
    /**
     Invite user directly to MUC room
     - parameter room: room for invitation
     - parameter invitee: user to invite
     - parameter reason: reason for invitation
     - parameter theadId: thread id for invitation
     */
    open func inviteDirectly(to room: RoomProtocol, invitee: JID, reason: String?, threadId: String?) {
        room.inviteDirectly(invitee, reason: reason, threadId: threadId);
    }
    
    private var joinPromises: [BareJID: (Result<RoomJoinResult,XMPPError>)->Void] = [:];
    
    /**
     Join MUC room
     - parameter roomName: name of room to join
     - parameter mucServer: domain of MUC server with room
     - parameter nickname: nickname to use in room
     - parameter password: password for room if needed
     - returns: instance of Room
     */
    open func join(roomName: String, mucServer: String, nickname: String, password: String? = nil) -> Future<RoomJoinResult, XMPPError> {
        let roomJid = BareJID(localPart: roomName, domain: mucServer);
        
        return Future({ promise in
            guard let context = self.context else {
                return promise(.failure(.undefined_condition));
            }
            
            if let result = self.roomManager.createRoom(for: context, with: roomJid, nickname: nickname, password: password) {
                self.join(room: result, fetchHistory: .initial).handle(promise);
            } else {
                promise(.failure(.undefined_condition));
            }
        });
    }
    
    open func join(room: RoomProtocol, fetchHistory: RoomHistoryFetch) -> Future<RoomJoinResult, XMPPError> {
        return Future({ promise in
            guard let context = self.context else {
                promise(.failure(.undefined_condition));
                return;
            }
            context.dispatcher.async {
                self.joinPromises[room.jid] = promise;
            }
            let presence = Presence();
            presence.to = room.jid.with(resource: room.nickname);
            let x = Element(name: "x", xmlns: "http://jabber.org/protocol/muc");
            presence.addChild(x);
            if let password = room.password {
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
            
            room.update(state: .requested);
            self.fire(JoinRequestedEvent(context: context, presence: presence, room: room, nickname: room.nickname));
            self.write(presence, writeCompleted: { result in
                guard case .failure(let error) = result else {
                    return;
                }
                context.dispatcher.async {
                    self.joinPromises.removeValue(forKey: room.jid);
                }
                promise(.failure(error));
            });
        });
    }
    
    /**
     Destroy MUC room
     - parameter room: room to destroy
     */
    @discardableResult
    open func destroy(room: RoomProtocol) -> Bool {
        guard room.state == .joined && room.occupant(nickname: room.nickname)?.affiliation == .owner else {
            return false;
        }
        
        let iq = Iq();
        iq.type = .set;
        iq.to = JID(room.jid);

        let query = Element(name: "query", xmlns: "http://jabber.org/protocol/muc#owner");
        query.addChild(Element(name: "destroy"));
        
        iq.addChild(query);
        
        write(iq);
        
        roomManager.close(room: room);
        
        room.update(state: .destroyed);
        if let context = context {
            fire(RoomClosedEvent(context: context, presence: nil, room: room));
        }
        
        return true;
    }
    
    /**
     Leave MUC room
     - parameter room: room to leave
     */
    open func leave(room: RoomProtocol) {
        if room.state == .joined {
            room.update(state: .not_joined());
            
            let presence = Presence();
            presence.type = StanzaType.unavailable;
            presence.to = room.jid.with(resource: room.nickname);
            write(presence);
        }
        
        roomManager.close(room: room);
        
        room.update(state: .destroyed);
        if let context = context {
            fire(RoomClosedEvent(context: context, presence: nil, room: room));
        }
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
            throw XMPPError.feature_not_implemented;
        }
    }
    
    func processPresence(_ presence: Presence) throws {
        let from = presence.from!;
        let roomJid = from.bareJid;
        let type = presence.type;
        guard let context = context, let room = roomManager.room(for: context, with: roomJid) else {
            return;
        }
        
        if type == StanzaType.error {
            if room.state == .joined, let nickname = from.resource {
                if let oldOccupant: MucOccupant = room.occupant(nickname: nickname) {
                    room.remove(occupant: oldOccupant);
                    if let context = self.context {
                        fire(OccupantLeavedEvent(context: context, presence: presence, room: room, occupant: oldOccupant, nickname: nickname, xUser: nil));
                    }
                } else {
                    if let context = self.context {
                        fire(PresenceErrorEvent(context: context, presence: presence, room: room, nickname: nickname));
                    }
                }
                return;
            } else {
                if let error = presence.error {
                    room.update(state: .not_joined(reason: .error(error)));
                } else {
                    room.update(state: .not_joined());
                }
                self.context?.dispatcher.async {
                    self.joinPromises.removeValue(forKey: roomJid)?(.failure(presence.error ?? .undefined_condition));
                }
                if let context = self.context {
                    fire(RoomClosedEvent(context: context, presence: presence, room: room));
                }
            }
        }
        
        guard let nickname = from.resource else {
            return;
        }
        
        if (type == StanzaType.unavailable && nickname == room.nickname) {
            room.update(state: .not_joined());
            if let context = self.context {
                fire(RoomClosedEvent(context: context, presence: presence, room: room));
            }
            return;
        }
        
        let xUser = XMucUserElement.extract(from: presence);
        
        if let oldOccupant: MucOccupant = room.occupant(nickname: nickname) {
            if type == .unavailable {
                room.remove(occupant: oldOccupant);
                if let newNickName = xUser?.nick, xUser?.statuses.firstIndex(of: 303) != nil {
                    room.addTemp(nickname: newNickName, occupant: oldOccupant);
                } else {
                    if let context = self.context {
                        fire(OccupantLeavedEvent(context: context, presence: presence, room: room, occupant: oldOccupant, nickname: nickname, xUser: xUser));
                    }
                }
            } else {
                oldOccupant.set(presence: presence);
                if let context = self.context {
                    fire(OccupantChangedPresenceEvent(context: context, presence: presence, room: room, occupant: oldOccupant, nickname: nickname, xUser: xUser));
                }
            }
        } else {
            let temp = room.removeTemp(nickname: nickname);
            let occupant = room.addOccupant(nickname: nickname, presence: presence);
            
            if room.state != .joined && xUser?.statuses.firstIndex(of: 110) != nil {
                room.update(state: .joined);
                let occupant = room.addOccupant(nickname: nickname, presence: presence);
                
                let wasCreated = xUser?.statuses.firstIndex(of: 201) != nil;
                context.dispatcher.async {
                    self.joinPromises.removeValue(forKey: room.jid)?(.success(wasCreated ? .created(room) : .joined(room)));
                }
                if let context = self.context {
                    fire(YouJoinedEvent(context: context, room: room, nickname: nickname));
                    fire(OccupantComesEvent(context: context, presence: presence, room: room, occupant: occupant, nickname: nickname, xUser: xUser));
                }
            } else if let prevOccupant = temp {
                if let context = self.context {
                    fire(OccupantChangedNickEvent(context: context, presence: presence, room: room, occupant: occupant, nickname: prevOccupant.nickname));
                }
            } else {
                if let context = self.context {
                    fire(OccupantComesEvent(context: context, presence: presence, room: room, occupant: occupant, nickname: nickname, xUser: xUser));
                }
            }
        }

        if room.nickname == nickname {
            room.role = xUser?.role ?? .none;
            room.affiliation = xUser?.affiliation ?? .none;
        }
    }
    
    func processMessage(_ message: Message) {
        let from = message.from!;
        let roomJid = from.bareJid;
        let nickname = from.resource;
        
        guard let context = context else {
            return;
        }
        
        guard let room = roomManager.room(for: context, with: roomJid) else {
            return;
        }
        
        let timestamp = message.delay?.stamp ?? Date();
        messagesPublisher.send(.init(room: room, message: message));
        fire(MessageReceivedEvent(context: context, message: message, room: room, nickname: nickname, timestamp: timestamp));
    }
    
    func processDirectInvitationMessage(_ message: Message) {
        let x = message.findChild(name: "x", xmlns: "jabber:x:conference");
        let contStr = x?.getAttribute("continue");
        let cont = contStr == "true" || contStr == "1";
        
        if let context = self.context {
            let invitation = DirectInvitation(context: context, message: message, roomJid: BareJID(x!.getAttribute("jid")!), inviter: message.from!, reason: x?.getAttribute("reason"), password: x?.getAttribute("password"), threadId: x?.getAttribute("thread"), continueFlag: cont);
        
            self.inivitationsPublisher.send(invitation);
            fire(InvitationReceivedEvent(context: context, invitation: invitation));
        }
    }
    
    func processMediatedInvitationMessage(_ message: Message) {
        let x = message.findChild(name: "x", xmlns: "http://jabber.org/protocol/muc#user");
        let invite = x?.findChild(name: "invite");
                
        if let context = self.context {
            let invitation = MediatedInvitation(context: context, message: message, roomJid: message.from!.bareJid, inviter: JID(invite?.getAttribute("from")), reason: invite?.getAttribute("reason"), password: x?.getAttribute("password"));
            
            self.inivitationsPublisher.send(invitation);
            fire(InvitationReceivedEvent(context: context, invitation: invitation));
        }
    }
    
    func processInvitationDeclinedMessage(_ message: Message) {
        let from = message.from!.bareJid;
        guard let context = self.context,  let room = roomManager.room(for: context, with: from) else {
            return;
        }
        
        let decline = message.findChild(name: "x", xmlns: "http://jabber.org/protocol/muc#user")?.findChild(name: "decline");
        let reason = decline?.findChild(name: "reason")?.stringValue;
        let invitee = decline?.getAttribute("from");
        
        if let context = self.context {
            fire(InvitationDeclinedEvent(context: context, message: message, room: room, invitee: JID(invitee), reason: reason));
        }
    }

    fileprivate func markRoomsAsNotJoined() {
        if let context = self.context {
            for room in roomManager.rooms(for: context) {
                room.update(state: .not_joined());
            
                fire(RoomClosedEvent(context: context, presence: nil, room: room));
            }
        }
    }
    
    /**
     Event fired when join request is sent
     */
    @available(*, deprecated, message: "Use RoomProtocol.statePublisher")
    open class JoinRequestedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = JoinRequestedEvent();

        /// Presence sent
        public let presence: Presence!;
        /// RoomProtocolto join
        public let room: RoomProtocol!;
        /// Nickname to use in room
        public let nickname: String?;

        init() {
            self.presence = nil;
            self.room = nil;
            self.nickname = nil;
            super.init(type: "MucModuleJoinRequestedEvent");
        }

        public init(context: Context, presence: Presence, room: RoomProtocol, nickname: String?) {
            self.presence = presence;
            self.room = room;
            self.nickname = nickname;
            super.init(type: "MucModuleJoinRequestedEvent", context: context)
        }

    }

    @available(*, deprecated, message: "Use MucModule.messagesPublisher")
    /// Event fired when received message in room
    open class MessageReceivedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = MessageReceivedEvent();

        /// Received message
        public let message: Message!;
        /// RoomProtocolwhich delivered message
        public let room: RoomProtocol!;
        /// Nickname of message sender
        public let nickname: String?;
        /// Timestamp of message
        public let timestamp: Date!;

        init() {
            self.message = nil;
            self.room = nil;
            self.nickname = nil;
            self.timestamp = nil;
            super.init(type: "MucModuleMessageReceivedEvent")
        }

        public init(context: Context, message: Message, room: RoomProtocol, nickname: String?, timestamp: Date) {
            self.message = message;
            self.room = room;
            self.nickname = nickname;
            self.timestamp = timestamp;
            super.init(type: "MucModuleMessageReceivedEvent", context: context);
        }

    }

    /// Event fired when new room is opened locally
    @available(*, deprecated, message: "Use join(ifCreated:)")
    open class NewRoomCreatedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = NewRoomCreatedEvent();

        /// Presence in room
        public let presence: Presence!;
        /// Created room
        public let room: RoomProtocol!;

        init() {
            self.presence = nil;
            self.room = nil;
            super.init(type: "MucModuleNewRoomCreatedEvent");
        }

        public init(context: Context, presence: Presence, room: RoomProtocol) {
            self.presence = presence;
            self.room = room;
            super.init(type: "MucModuleNewRoomCreatedEvent", context: context);
        }
    }

    @available(*, deprecated)
    open class AbstractOccupantEvent: AbstractEvent {

        /// New presence
        public let presence: Presence!;
        /// RoomProtocolin which occupant changed presence
        public let room: RoomProtocol!;
        /// Occupant which changed presence
        public let occupant: MucOccupant!;
        /// Occupant nickname
        public let nickname: String?;
        /// Additional informations from new presence
        public let xUser: XMucUserElement?;

        fileprivate override init(type: String) {
            self.presence = nil;
            self.room = nil;
            self.occupant = nil;
            self.nickname = nil;
            self.xUser = nil;
            super.init(type: type);
        }

        init(type: String, context: Context, presence: Presence?, room: RoomProtocol?, occupant: MucOccupant?, nickname: String?, xUser: XMucUserElement? = nil) {
            self.presence = presence;
            self.room = room;
            self.occupant = occupant;
            self.nickname = nickname;
            self.xUser = xUser;
            super.init(type: type, context: context);
        }
    }

    /// Event fired when room occupant changes nickname
    @available(*, deprecated, message: "Use RoomProtocol.occupantsPublisher")
    open class OccupantChangedNickEvent: AbstractOccupantEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = OccupantChangedNickEvent();

        init() {
            super.init(type: "MucModuleOccupantChangedNickEvent");
        }

        public init(context: Context, presence: Presence, room: RoomProtocol, occupant: MucOccupant, nickname: String?) {
            super.init(type: "MucModuleOccupantChangedNickEvent", context: context, presence: presence, room: room, occupant: occupant, nickname: nickname, xUser: nil);
        }
    }

    /// Event fired when room occupant changes presence
    @available(*, deprecated, message: "Use MucOccupant.presence publisher")
    open class OccupantChangedPresenceEvent: AbstractOccupantEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = OccupantChangedPresenceEvent();

        init() {
            super.init(type: "MucModuleOccupantChangedPresenceEvent");
        }

        public init(context: Context, presence: Presence, room: RoomProtocol, occupant: MucOccupant, nickname: String?, xUser: XMucUserElement?) {
            super.init(type: "MucModuleOccupantChangedPresenceEvent", context: context, presence: presence, room: room, occupant: occupant, nickname: nickname, xUser: xUser);
        }
    }

    /// Event fired when occupant enters room
    @available(*, deprecated)
    @available(*, deprecated, message: "Use RoomProtocol.occupantsPublisher")
    open class OccupantComesEvent: AbstractOccupantEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = OccupantComesEvent();

        init() {
            super.init(type: "MucModuleOccupantComesEvent");
        }

        public init(context: Context, presence: Presence, room: RoomProtocol, occupant: MucOccupant, nickname: String?, xUser: XMucUserElement?) {
            super.init(type: "MucModuleOccupantComesEvent", context: context, presence: presence, room: room, occupant: occupant, nickname: nickname, xUser: xUser);
        }

    }

    /// Event fired when occupant leaves room
    @available(*, deprecated, message: "Use RoomProtocol.occupantsPublisher")
    open class OccupantLeavedEvent: AbstractOccupantEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = OccupantLeavedEvent();

        init() {
            super.init(type: "MucModuleOccupantLeavedEvent");
        }

        public init(context: Context, presence: Presence, room: RoomProtocol, occupant: MucOccupant, nickname: String?, xUser: XMucUserElement?) {
            super.init(type: "MucModuleOccupantLeavedEvent", context: context, presence: presence, room: room, occupant: occupant, nickname: nickname, xUser: xUser);
        }

    }

    /// Event fired when we receive presence of type error from MUC room
    @available(*, deprecated)
    open class PresenceErrorEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = PresenceErrorEvent();

        /// Received presence
        public let presence: Presence!;
        /// RoomProtocolwhich sent presence
        public let room: RoomProtocol!;
        /// Nickname
        public let nickname: String?;

        init() {
            self.presence = nil;
            self.room = nil;
            self.nickname = nil;
            super.init(type: "MucModulePresenceErrorEvent")
        }

        public init(context: Context, presence: Presence, room: RoomProtocol, nickname: String?) {
            self.presence = presence;
            self.room = room;
            self.nickname = nickname;
            super.init(type: "MucModulePresenceErrorEvent", context: context);
        }
    }

    /// Event fired when room is closed (left by us)
    @available(*, deprecated, message: "Use RoomProtocol.statePublisher")
    open class RoomClosedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = RoomClosedEvent();

        /// Received presence
        public let presence: Presence?;
        /// Closed room
        public let room: RoomProtocol!;

        init() {
            self.presence = nil;
            self.room = nil;
            super.init(type: "MucModuleRoomClosedEvent")
        }

        public init(context: Context, presence: Presence?, room: RoomProtocol) {
            self.presence = presence;
            self.room = room;
            super.init(type: "MucModuleRoomClosedEvent", context: context);
        }
    }

    /// Event fired when room is joined by us
    @available(*, deprecated, message: "Use RoomProtocol.statePublisher")
    open class YouJoinedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = YouJoinedEvent();

        /// Joined room
        public let room: RoomProtocol!;
        /// Joined under nickname
        public let nickname: String?;

        init() {
            self.room = nil;
            self.nickname = nil;
            super.init(type: "MucModuleYouJoinedEvent");
        }

        public init(context: Context, room: RoomProtocol, nickname: String?) {
            self.room = room;
            self.nickname = nickname;
            super.init(type: "MucModuleYouJoinedEvent", context: context);
        }
    }

    @available(*, deprecated)
    /// Event fired when information about declined invitation is received
    open class InvitationDeclinedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = InvitationDeclinedEvent();

        /// Received message
        public let message: Message!;
        /// Room
        public let room: RoomProtocol!;
        /// Invitation decliner
        public let invitee: JID?;
        /// Reason for declining invitation
        public let reason: String?;

        fileprivate init() {
            self.message = nil;
            self.room = nil;
            self.invitee = nil;
            self.reason = nil;
            super.init(type: "MucModuleInvitationDeclinedEvent");
        }

        public init(context: Context, message: Message, room: RoomProtocol, invitee: JID?, reason: String?) {
            self.message = message;
            self.room = room;
            self.invitee = invitee;
            self.reason = reason;
            super.init(type: "MucModuleInvitationDeclinedEvent", context: context);
        }
    }

    @available(*, deprecated, message: "Use RoomModule.invitationsPublisher")
    /// Event fired when invitation is received
    open class InvitationReceivedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = InvitationReceivedEvent();

        /// Received invitation
        public let invitation: Invitation!;

        fileprivate init() {
            self.invitation = nil;
            super.init(type: "MucModuleInvitationReceivedEvent")
        }

        public init(context: Context, invitation: Invitation) {
            self.invitation = invitation;
            super.init(type: "MucModuleInvitationReceivedEvent", context: context);
        }

    }
    
    /// Common class for invitations
    open class Invitation {
        public let context: Context;
        /// Instance of `SessionObject` to identify connection which fired event
        public var sessionObject: SessionObject {
            return context.sessionObject;
        }
        /// Received message
        public let message: Message;
        /// RoomProtocolJID
        public let roomJid: BareJID;
        /// Sender of invitation
        public let inviter: JID?;
        /// Password for room
        public let password: String?;
        /// Reason for invitation
        public let reason: String?;
        
        public init(context: Context, message: Message, roomJid: BareJID, inviter: JID?, reason: String?, password: String?) {
            self.context = context;
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
        
        public init(context: Context, message: Message, roomJid: BareJID, inviter: JID?, reason: String?, password: String?, threadId: String?, continueFlag: Bool) {
            self.threadId = threadId;
            self.continueFlag = continueFlag;
            super.init(context: context, message: message, roomJid: roomJid, inviter: inviter, reason: reason, password: password);
        }
    }
    
    /// Class for mediated invitations over MUC component
    open class MediatedInvitation: Invitation {
        
        public override init(context: Context, message: Message, roomJid: BareJID, inviter: JID?, reason: String?, password: String?) {
            super.init(context: context, message: message, roomJid: roomJid, inviter: inviter, reason: reason, password: password);
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
            guard let type = presence.type, type == .error, let error = presence.error else {
                return nil;
            }
            return from(error: error);
        }
        
        public static func from(error: XMPPError) -> RoomError? {
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
    
    public struct MessageReceived {
        public let room: RoomProtocol;
        public let message: Message;
    }
}

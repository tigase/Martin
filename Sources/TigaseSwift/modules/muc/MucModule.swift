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
            }
        }
        
        guard let nickname = from.resource else {
            return;
        }
        
        if (type == StanzaType.unavailable && nickname == room.nickname) {
            room.update(state: .not_joined());
            return;
        }
        
        let xUser = XMucUserElement.extract(from: presence);
        
        if let oldOccupant: MucOccupant = room.occupant(nickname: nickname) {
            if type == .unavailable {
                room.remove(occupant: oldOccupant);
                if let newNickName = xUser?.nick, xUser?.statuses.firstIndex(of: 303) != nil {
                    room.addTemp(nickname: newNickName, occupant: oldOccupant);
                }
            } else {
                oldOccupant.set(presence: presence);
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
        
        messagesPublisher.send(.init(room: room, message: message));
    }
    
    func processDirectInvitationMessage(_ message: Message) {
        let x = message.findChild(name: "x", xmlns: "jabber:x:conference");
        let contStr = x?.getAttribute("continue");
        let cont = contStr == "true" || contStr == "1";
        
        if let context = self.context {
            let invitation = DirectInvitation(context: context, message: message, roomJid: BareJID(x!.getAttribute("jid")!), inviter: message.from!, reason: x?.getAttribute("reason"), password: x?.getAttribute("password"), threadId: x?.getAttribute("thread"), continueFlag: cont);
        
            self.inivitationsPublisher.send(invitation);
        }
    }
    
    func processMediatedInvitationMessage(_ message: Message) {
        let x = message.findChild(name: "x", xmlns: "http://jabber.org/protocol/muc#user");
        let invite = x?.findChild(name: "invite");
                
        if let context = self.context {
            let invitation = MediatedInvitation(context: context, message: message, roomJid: message.from!.bareJid, inviter: JID(invite?.getAttribute("from")), reason: invite?.getAttribute("reason"), password: x?.getAttribute("password"));
            
            self.inivitationsPublisher.send(invitation);
        }
    }
    
    func processInvitationDeclinedMessage(_ message: Message) {
        let from = message.from!.bareJid;
        guard let context = self.context else {
            return;
        }
        
        let decline = message.findChild(name: "x", xmlns: "http://jabber.org/protocol/muc#user")?.findChild(name: "decline");
        let reason = decline?.findChild(name: "reason")?.stringValue;
        let invitee = decline?.getAttribute("from");
        
        if let context = self.context, let inviteeJid = JID(invitee) {
            let declined = DeclinedInvitation(context: context, message: message, roomJid: from, invitee: inviteeJid, reason: reason);
            self.inivitationsPublisher.send(declined)
        }
    }

    fileprivate func markRoomsAsNotJoined() {
        if let context = self.context {
            for room in roomManager.rooms(for: context) {
                room.update(state: .not_joined());
            }
        }
    }
    
    /// Common class for invitations
    open class Invitation {
        public let context: Context;
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
    
    open class DeclinedInvitation: Invitation {
        
        public let invitee: JID?
        
        public init(context: Context, message: Message, roomJid: BareJID, invitee: JID, reason: String?) {
            self.invitee = invitee;
            super.init(context: context, message: message, roomJid: roomJid, inviter: nil, reason: reason, password: nil);
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

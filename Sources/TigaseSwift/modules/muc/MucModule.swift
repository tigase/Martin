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
            self.context?.queue.async {
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
    open func decline(invitation: Invitation, reason: String?) async throws {
        if invitation is MediatedInvitation {
            let message = Message(to: invitation.roomJid.jid(), {
                Element(name: "x", xmlns: "http://jabber.org/protocol/muc#user", {
                    Element(name: "decline", {
                        Attribute("to", value: invitation.inviter?.description)
                        if let reason = reason {
                            Element(name: "reason", cdata: reason)
                        }
                    })
                })
            })
            try await write(stanza: message);
        } else {
            throw XMPPError(condition: .bad_request)
        }
    }
    
    /**
     Retrieve configuration of MUC room (only room owner is allowed to do so)
     - parameter of roomJid: jid of MUC room
     */
    open func roomConfiguration(of roomJid: JID) async throws -> RoomConfig {
        let iq = Iq(type: .get, to: roomJid, {
            Element(name: "query", xmlns: "http://jabber.org/protocol/muc#owner")
        })
        
        let response = try await write(iq: iq);
        guard let formEl = response.firstChild(name: "query", xmlns: "http://jabber.org/protocol/muc#owner")?.firstChild(name: "x", xmlns: "jabber:x:data"), let data = RoomConfig(element: formEl) else {
            throw XMPPError.undefined_condition;
        }
        
        return data;
    }
    
    /**
     Set configuration of MUC room (only room owner is allowed to do so)
     - parameter configuration: room configuration
     - parameter of roomJid: jid of MUC room
     */
    open func roomConfiguration(_ configuration: RoomConfig, of roomJid: JID) async throws {
        let iq = Iq(type: .set, to: roomJid, {
            Element(name: "query", xmlns: "http://jabber.org/protocol/muc#owner", {
                configuration.element(type: .submit, onlyModified: true)
            })
        })
        try await write(iq: iq);
    }
    
    open func roomAffiliations(from room: RoomProtocol, with affiliation: MucAffiliation, completionHandler: @escaping (Result<[RoomAffiliation],XMPPError>)->Void) {
        let userRole = room.occupant(nickname: room.nickname)?.role ?? .none;
        guard userRole == .participant || userRole == .moderator else {
            completionHandler(.failure(XMPPError(condition: .forbidden, message: "Only participant or moderator can ask for room affiliations!")));
            return;
        };
        
        let iq = Iq();
        iq.to = JID(room.jid);
        iq.type = StanzaType.get;
        
        let query = Element(name: "query", xmlns: "http://jabber.org/protocol/muc#admin");
        iq.addChild(query);
        query.addChild(Element(name: "item", attributes: ["affiliation": affiliation.rawValue]));
        
        write(iq: iq, completionHandler: { result in
            completionHandler(result.map({ stanza in
                return stanza.firstChild(name: "query", xmlns: "http://jabber.org/protocol/muc#admin")?.compactMapChildren(RoomAffiliation.init(from:)) ?? [];
            }))
        });
    }
    
    open func roomAffiliations(_ affiliations: [RoomAffiliation], to room: RoomProtocol, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        let userAffiliation = room.occupant(nickname: room.nickname)?.affiliation ?? .none;
        guard userAffiliation == .admin || userAffiliation == .owner else {
            completionHandler(.failure(XMPPError(condition: .forbidden, message: "Only room admin or owner can set room affiliations!")));
            return;
        };

        let iq = Iq();
        iq.to = JID(room.jid);
        iq.type = StanzaType.set;
        
        let query = Element(name: "query", xmlns: "http://jabber.org/protocol/muc#admin");
        iq.addChild(query);
        query.addChildren(affiliations.map({ aff -> Element in
            let el = Element(name: "item");
            el.attribute("jid", newValue: aff.jid.description);
            el.attribute("affiliation", newValue: aff.affiliation.rawValue);
            return el;
        }));
        
        write(iq: iq, completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        });
    }
    
    open func setRoomSubject(roomJid: BareJID, newSubject: String?) async throws {
        let message = Message(type: .groupchat, id: UUID().uuidString, to: roomJid.jid(), {
            Element(name: "subject", cdata: newSubject)
        });
        try await write(stanza: message)
    }
    
    /**
     Invite user to MUC room
     - parameter room: room for invitation
     - parameter invitee: user to invite
     - parameter reason: reason for invitation
     */
    open func invite(to room: RoomProtocol, invitee: JID, reason: String?) async throws {
        try await room.invite(invitee, reason: reason);
    }
        
    /**
     Invite user directly to MUC room
     - parameter room: room for invitation
     - parameter invitee: user to invite
     - parameter reason: reason for invitation
     - parameter theadId: thread id for invitation
     */
    open func inviteDirectly(to room: RoomProtocol, invitee: JID, reason: String?, threadId: String?) async throws {
        try await room.inviteDirectly(invitee, reason: reason, threadId: threadId);
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
    open func join(roomName: String, mucServer: String, nickname: String, password: String? = nil) async throws -> RoomJoinResult {
        let roomJid = BareJID(localPart: roomName, domain: mucServer);
        
        guard let context = self.context else {
            throw XMPPError.undefined_condition;
        }
        
        guard let result = self.roomManager.createRoom(for: context, with: roomJid, nickname: nickname, password: password) else {
            throw XMPPError(condition: .undefined_condition);
        }
        
        return try await join(room: result, fetchHistory: .initial);
    }
    
    open func join(room: RoomProtocol, fetchHistory: RoomHistoryFetch) async throws -> RoomJoinResult {
        return try await withUnsafeThrowingContinuation { continuation in
            self.join(room: room, fetchHistory: fetchHistory, completionHandler: { result in
                continuation.resume(with: result);
            });
        }
    }
    
    open func join(room: RoomProtocol, fetchHistory: RoomHistoryFetch, completionHandler: @escaping (Result<RoomJoinResult,XMPPError>)->Void) {
        guard let context = self.context else {
            completionHandler(.failure(.undefined_condition));
            return;
        }
        
        context.queue.async {
            self.joinPromises[room.jid] = completionHandler;
        }
        
        let presence = Presence(to: room.jid.with(resource: room.nickname), {
            Element(name: "x", xmlns: "http://jabber.org/protocol/muc", {
                if let password = room.password {
                    Element(name: "password", cdata: password)
                }
                fetchHistory.element()
            })
        })
        
        room.update(state: .requested);
        self.write(stanza: presence, completionHandler: { result in
            guard case .failure(let error) = result else {
                return;
            }
            context.queue.async {
                self.joinPromises.removeValue(forKey: room.jid);
            }
            completionHandler(.failure(error));
        });
    }

    /**
     Destroy MUC room
     - parameter room: room to destroy
     */
    open func destroy(room: RoomProtocol) async throws {
        guard room.state == .joined && room.occupant(nickname: room.nickname)?.affiliation == .owner else {
            throw XMPPError.undefined_condition;
        }
        
        let iq = Iq(type: .set, to: room.jid.jid(), {
            Element(name: "query", xmlns: "http://jabber.org/protocol/muc#owner", {
                Element(name: "destroy")
            })
        })

        try await write(iq: iq);
        
        roomManager.close(room: room);
        
        room.update(state: .destroyed);
    }
    
    /**
     Leave MUC room
     - parameter room: room to leave
     */
    open func leave(room: RoomProtocol) async throws {
        if room.state == .joined {
            room.update(state: .not_joined());
            
            let presence = Presence(type: .unavailable, to: room.jid.with(resource: room.nickname));
            try await write(stanza: presence);
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
            throw XMPPError(condition: .feature_not_implemented);
        }
    }
    
    private func processPresence(_ presence: Presence) throws {
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
                self.context?.queue.async {
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
            if room.state != .joined && xUser?.statuses.firstIndex(of: 110) != nil {
                room.update(state: .joined);
                
                let wasCreated = xUser?.statuses.firstIndex(of: 201) != nil;
                context.queue.async {
                    self.joinPromises.removeValue(forKey: room.jid)?(.success(wasCreated ? .created(room) : .joined(room)));
                }
            }
        }

        if room.nickname == nickname {
            room.role = xUser?.role ?? .none;
            room.affiliation = xUser?.affiliation ?? .none;
        }
    }
    
    private func processMessage(_ message: Message) {
        let from = message.from!;
        let roomJid = from.bareJid;
        
        guard let context = context else {
            return;
        }
        
        guard let room = roomManager.room(for: context, with: roomJid) else {
            return;
        }
        
        messagesPublisher.send(.init(room: room, message: message));
    }
    
    private func processDirectInvitationMessage(_ message: Message) {
        let x = message.firstChild(name: "x", xmlns: "jabber:x:conference");
        let contStr = x?.attribute("continue");
        let cont = contStr == "true" || contStr == "1";
        
        if let context = self.context {
            let invitation = DirectInvitation(context: context, message: message, roomJid: BareJID(x!.attribute("jid")!), inviter: message.from!, reason: x?.attribute("reason"), password: x?.attribute("password"), threadId: x?.attribute("thread"), continueFlag: cont);
        
            self.inivitationsPublisher.send(invitation);
        }
    }
    
    private func processMediatedInvitationMessage(_ message: Message) {
        let x = message.firstChild(name: "x", xmlns: "http://jabber.org/protocol/muc#user");
        let invite = x?.firstChild(name: "invite");
                
        if let context = self.context {
            let invitation = MediatedInvitation(context: context, message: message, roomJid: message.from!.bareJid, inviter: JID(invite?.attribute("from")), reason: invite?.attribute("reason"), password: x?.attribute("password"));
            
            self.inivitationsPublisher.send(invitation);
        }
    }
    
    private func processInvitationDeclinedMessage(_ message: Message) {
        let from = message.from!.bareJid;
        guard let context = self.context else {
            return;
        }
        
        let decline = message.firstChild(name: "x", xmlns: "http://jabber.org/protocol/muc#user")?.firstChild(name: "decline");
        let reason = decline?.firstChild(name: "reason")?.description;
        let invitee = decline?.attribute("from");
        
        if let inviteeJid = JID(invitee) {
            let declined = DeclinedInvitation(context: context, message: message, roomJid: from, invitee: inviteeJid, reason: reason);
            self.inivitationsPublisher.send(declined)
        }
    }

    private func markRoomsAsNotJoined() {
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
            switch error.condition {
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
    //TODO: Maybe this should be struct?
    open class RoomAffiliation {
        
        public let jid: JID;
        public let affiliation: MucAffiliation;
        public let nickname: String?;
        public let role: MucRole?;
        
        public convenience init?(from el: Element) {
            guard el.name == "item" else {
                return nil;
            }
            guard let jid = JID(el.attribute("jid")), let affiliation = MucAffiliation(rawValue: el.attribute("affiliation") ?? "") else {
                return nil;
            }
            self.init(jid: jid, affiliation: affiliation, nickname: el.attribute("nick"), role: MucRole(rawValue: el.attribute("role") ?? ""));
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

// async-await support
extension MucModule {
    
    open func decline(invitation: Invitation, reason: String?, completionHandler: ((Result<Void,XMPPError>)->Void)? = nil) {
        Task {
            do {
                completionHandler?(.success(try await decline(invitation: invitation, reason: reason)));
            } catch {
                completionHandler?(.failure(error as? XMPPError ?? .undefined_condition));
            }
        }
    }
                                   
    open func roomConfiguration(of roomJid: JID, completionHandler: @escaping (Result<RoomConfig,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await roomConfiguration(of: roomJid)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition));
            }
        }
    }
    
    open func roomConfiguration(_ configuration: RoomConfig, of roomJid: JID, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await roomConfiguration(configuration, of: roomJid)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition));
            }
        }
    }
    
    open func setRoomSubject(roomJid: BareJID, newSubject: String?) {
        Task {
            try await setRoomSubject(roomJid: roomJid, newSubject: newSubject);
        }
    }
    
    open func invite(to room: RoomProtocol, invitee: JID, reason: String?) {
        room.invite(invitee, reason: reason);
    }
    
    open func inviteDirectly(to room: RoomProtocol, invitee: JID, reason: String?, threadId: String?) {
        room.inviteDirectly(invitee, reason: reason, threadId: threadId);
    }
    
    open func join(roomName: String, mucServer: String, nickname: String, password: String? = nil, completionHandler: @escaping (Result<RoomJoinResult,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await join(roomName: roomName, mucServer: mucServer, nickname: nickname, password: password)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

    @discardableResult
    open func destroy(room: RoomProtocol) -> Bool {
        guard room.state == .joined && room.occupant(nickname: room.nickname)?.affiliation == .owner else {
            return false;
        }
        
        let iq = Iq(type: .set, to: JID(room.jid));
        let query = Element(name: "query", xmlns: "http://jabber.org/protocol/muc#owner");
        query.addChild(Element(name: "destroy"));
        
        iq.addChild(query);
        
        write(stanza: iq);
        
        roomManager.close(room: room);
        
        room.update(state: .destroyed);
        return true;
    }
 
    open func leave(room: RoomProtocol) {
        if room.state == .joined {
            room.update(state: .not_joined());
            
            let presence = Presence();
            presence.type = StanzaType.unavailable;
            presence.to = room.jid.with(resource: room.nickname);
            write(stanza: presence);
        }
        
        roomManager.close(room: room);
        
        room.update(state: .destroyed);
    }

}

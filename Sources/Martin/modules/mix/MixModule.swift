//
// MixModule.swift
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

extension XmppModuleIdentifier {
    public static var mix: XmppModuleIdentifier<MixModule> {
        return MixModule.IDENTIFIER;
    }
}

open class MixModule: XmppModuleBaseSessionStateAware, XmppStanzaProcessor, RosterAnnotationAwareProtocol, @unchecked Sendable {
    func rosterExtensionRequestElement() -> Element? {
        return Element(name: "annotate", xmlns: "urn:xmpp:mix:roster:0");
    }
    
    func process(rosterItemElem el: Element) -> RosterItemAnnotation? {
        guard let channelEl = el.firstChild(name: "channel", xmlns: "urn:xmpp:mix:roster:0"), let id = channelEl.attribute("participant-id") else {
            return nil;
        }
        return RosterItemAnnotation(type: "mix", values: ["participant-id": id]);
    }
    
    public static let CORE_XMLNS = "urn:xmpp:mix:core:1";
    public static let IDENTIFIER = XmppModuleIdentifier<MixModule>();
    public static let ID = "mix";
    public static let PAM2_XMLNS = "urn:xmpp:mix:pam:2";
    
    public let criteria: Criteria = Criteria.or(
        Criteria.name("message", types: [.groupchat], containsAttribute: "from").add(Criteria.name("mix", xmlns: MixModule.CORE_XMLNS)),
        Criteria.name("message", types: [.error], containsAttribute: "from")
    );
    
    public let features: [String] = [CORE_XMLNS];
    
    public override weak var context: Context? {
        didSet {
            oldValue?.unregister(lifecycleAware: channelManager);
            context?.register(lifecycleAware: channelManager);
            if let context = context {
                discoModule = context.modulesManager.module(.disco);
                discoModule.$accountDiscoResult.sink(receiveValue: { [weak self] info in self?.accountFeaturesChanged(info.features) }).store(in: self);
                mamModule = context.modulesManager.module(.mam);
                pubsubModule = context.modulesManager.module(.pubsub);
                pubsubModule.itemsEvents.sink(receiveValue: { [weak self] notification in
                    self?.receivedPubsubItem(notification: notification);
                }).store(in: self);
                avatarModule = context.modulesManager.module(.pepUserAvatar);
                presenceModule = context.modulesManager.module(.presence);
                rosterModule = context.modulesManager.module(.roster);
                rosterModule.events.sink(receiveValue: { [weak self] action in
                    self?.rosterItemChanged(action);
                }).store(in: self);
            } else {
                discoModule = nil;
                mamModule = nil;
                pubsubModule = nil;
                avatarModule = nil;
                presenceModule = nil;
                rosterModule = nil;
            }
        }
    }

    private var discoModule: DiscoveryModule!;
    private var mamModule: MessageArchiveManagementModule!;
    public var pubsubModule: PubSubModule!;
    private var avatarModule: PEPUserAvatarModule!;
    private var presenceModule: PresenceModule!;
    private var rosterModule: RosterModule!;

    public let channelManager: ChannelManager;
    
    public let participantsEvents = PassthroughSubject<ParticipantEvent, Never>();
    
    public let messagesPublisher = PassthroughSubject<MessageReceived, Never>();
    
    public private(set) var isPAM2SupportAvailable: Bool = false;
    
    public var localMAMStoresPubSubEvents: Bool {
        return isPAM2SupportAvailable && false;
    }
    
    public enum AutomaticRetriveActions {
        case participants
        case info
        case avatar
        case affiliations
    }
    
    public var automaticRetrieve: Set<AutomaticRetriveActions> = [.participants,.info,.avatar,.affiliations];
    
    public init(channelManager: ChannelManager) {
        self.channelManager = channelManager;
    }
    
    open func create(channel: String?, at componentJid: BareJID) async throws -> BareJID {
        guard componentJid.localPart == nil else {
            throw XMPPError(condition: .bad_request, message: "MIX component JID cannot have local part set!");
        }

        let iq = Iq(type: .set, to: JID(componentJid), {
            Element(name: "create", xmlns: MixModule.CORE_XMLNS, {
                Attribute("channel", value: channel)
            })
        })
        
        let response = try await write(iq: iq);
        guard let channel = response.firstChild(name: "create", xmlns: MixModule.CORE_XMLNS)?.attribute("channel") else {
            throw XMPPError(condition: .undefined_condition, stanza: response);
        }
        
        return BareJID(localPart: channel, domain: componentJid.domain);
    }
    
    open func destroy(channel channelJid: BareJID) async throws {
        guard channelJid.localPart != nil else {
            throw XMPPError(condition: .bad_request, message: "MIX component JID cannot have local part set!");
        }
        guard let context = self.context else {
            throw XMPPError.remote_server_timeout;
        }
        
        let iq = Iq(type: .set, to: JID(channelJid), {
            Element(name: "destroy", xmlns: MixModule.CORE_XMLNS, {
                Attribute("channel", value: channelJid.localPart)
            })
        })
        
        _ = try await write(iq: iq);
        if let channel = self.channelManager.channel(for: context, with: channelJid) {
            _  = self.channelManager.close(channel: channel);
        }
        _ = try? await self.rosterModule?.removeItem(jid: JID(channelJid));
    }
        
    open func join(channel channelJid: BareJID, withNick nick: String?, subscribeNodes nodes: [String] = ["urn:xmpp:mix:nodes:messages", "urn:xmpp:mix:nodes:participants", "urn:xmpp:mix:nodes:info", "urn:xmpp:avatar:metadata"], presenceSubscription: Bool = true, invitation: MixInvitation? = nil, messageSyncLimit: Int = 100) async throws -> Iq {
        guard let context = self.context else {
            throw XMPPError.remote_server_timeout;
        }

        if isPAM2SupportAvailable {
            let iq = Iq(type: .set, to: context.userBareJid.jid(), {
                Element(name: "client-join", xmlns: MixModule.PAM2_XMLNS, {
                    Attribute("channel", value: channelJid.description)
                    createJoinEl(withNick: nick, withNodes: nodes, invitation: invitation)
                })
            })
            
            let response = try await write(iq: iq);
            guard let joinEl = response.firstChild(name: "client-join", xmlns: MixModule.PAM2_XMLNS)?.firstChild(name: "join", xmlns: MixModule.CORE_XMLNS), let participantId: String = participantId(joinElement: joinEl)  else {
                throw XMPPError(condition: .undefined_condition, stanza: response);
            }
            
            let nick = joinEl.firstChild(name: "nick")?.value;
            _ = self.channelJoined(channelJid: channelJid, participantId: participantId, nick: nick);
            Task {
                try await self.retrieveHistory(fromChannel: channelJid, start: nil, rsm: .last(messageSyncLimit));
            }
            if presenceSubscription {
                Task {
                    try await self.presenceModule?.subscribed(by: JID(channelJid));
                }
                Task {
                    try await self.presenceModule?.subscribe(to: JID(channelJid));
                }
            }
            return response;
        } else {
            let iq = Iq(type: .set, to: channelJid.jid(), {
                createJoinEl(withNick: nick, withNodes: nodes, invitation: invitation)
            })
            
            let response = try await write(iq: iq);
            guard let joinEl = response.firstChild(name: "join", xmlns: MixModule.CORE_XMLNS), let participantId = joinEl.attribute("id") else {
                throw XMPPError(condition: .undefined_condition, stanza: response);
            }
            Task {
                try await self.retrieveHistory(fromChannel: channelJid, start: nil, rsm: .last(messageSyncLimit));
            }
            _ = self.channelJoined(channelJid: channelJid, participantId: participantId, nick: joinEl.firstChild(name: "nick")?.value);
            return response;
        }
        
    }
    
    private func participantId(joinElement joinEl: Element) -> String? {
        guard let id = joinEl.attribute("id") else {
            guard let jid = joinEl.attribute("jid"), let id = jid.split(separator: "#").first else {
                return nil;
            }
            return String(id)
        }
        return id;
    }
    
    open func leave(channel: ChannelProtocol) async throws -> Iq {
        guard let context = context else {
            throw XMPPError.remote_server_timeout;
        }
        if isPAM2SupportAvailable {
            let iq = Iq(type: .set, to: context.userBareJid.jid(), {
                Element(name: "client-leave", xmlns: MixModule.PAM2_XMLNS, {
                    Attribute("channel", value: channel.jid.description)
                    Element(name: "leave", xmlns: MixModule.CORE_XMLNS)
                })
            });

            let response = try await write(iq: iq);
            channelLeft(channel: channel);
            return response;
        } else {
            let iq = Iq(type: .set, to: channel.jid.jid(), {
                Element(name: "leave", xmlns: MixModule.CORE_XMLNS)
            })
            let response = try await write(iq: iq);
            channelLeft(channel: channel);
            return response;
        }
    }
        
    open func channelJoined(channelJid: BareJID, participantId: String, nick: String?) -> ChannelProtocol? {
        guard let context = self.context else {
            return nil;
        }
        switch self.channelManager.createChannel(for: context, with: channelJid, participantId: participantId, nick: nick, state: .joined) {
        case .created(let channel):
            if self.automaticRetrieve.contains(.participants) {
                Task {
                    try await participants(for: channel);
                }
            }
            Task {
                try await info(for: channel.jid);
            }
            Task {
                try await affiliations(for: channel);
            }
            if self.automaticRetrieve.contains(.avatar) {
                Task {
                    try await avatar(for: channel.jid);
                }
            }
            return channel;
        case .found(let channel):
            return channel;
        case .none:
            return nil;
        }
    }

    open func channelLeft(channel: ChannelProtocol) {
        _ = self.channelManager.close(channel: channel);
    }
    
    // we may want to add "status" to the channel, to know if we are in participants or not..
    
    open func createJoinEl(withNick nick: String?, withNodes nodes: [String], invitation: MixInvitation?) -> Element {
        return Element(name: "join", xmlns: MixModule.CORE_XMLNS, {
            for node in nodes {
                Element(name: "subscribe", attributes: ["node": node])
            }
            if let nick = nick {
                Element(name: "nick", cdata: nick);
            }
            invitation?.element()
        })
    }
    
    open func process(stanza: Stanza) throws {
        switch stanza {
        case let message as Message:
            // we have received groupchat message..
            guard let context = context, let channel = channelManager.channel(for: context, with: message.from!.bareJid) else {
                return;
            }
            if message.mix != nil {
                self.messagesPublisher.send(.init(channel: channel, message: message));
            }
        default:
            break;
        }
    }
    
    open func affiliations(for channel: ChannelProtocol) async throws -> Set<ChannelPermission> {
        do {
            let affiliations = try await pubsubModule.retrieveOwnAffiliations(from: channel.jid, for: nil);
            let values = Dictionary(affiliations.map({ ($0.node, $0.affiliation) }), uniquingKeysWith: { (first, _) in first });
            var permissions: Set<ChannelPermission> = [];
            switch values["urn:xmpp:mix:nodes:info"] ?? .none {
            case .owner, .publisher:
                permissions.insert(.changeInfo);
            default:
                break;
            }
            switch values["urn:xmpp:mix:nodes:config"] ?? .none {
            case .owner, .publisher:
                permissions.insert((.changeConfig));
            default:
                break;
            }
            switch values["urn:xmpp:avatar:metadata"] ?? .none {
            case .owner, .publisher:
                permissions.insert((.changeAvatar));
            default:
                break;
            }
            
            channel.update(permissions: permissions)
            return Set(permissions)
        } catch {
            channel.update(permissions: [])
            throw error;
        }
    }
    
    open func participants(for channel: ChannelProtocol) async throws -> [MixParticipant] {
        let items = try await pubsubModule.retrieveItems(from: channel.jid, for: "urn:xmpp:mix:nodes:participants");
        let participants = items.items.map({ (item) -> MixParticipant? in
            return MixParticipant(from: item, for: channel);
        }).filter({ $0 != nil }).map({ $0! });
        let oldParticipants = channel.participants;
        let left = oldParticipants.filter({ old in !participants.contains(where: { new in new.id == old.id})});
        if let ownParticipant = participants.first(where: { (participant) -> Bool in
            return participant.id == channel.participantId
        }) {
            channel.update(ownNickname: ownParticipant.nickname);
        }
        channel.set(participants: participants);
        for participant in left {
            self.participantsEvents.send(.left(participant));
        }
        for participant in participants {
            self.participantsEvents.send(.joined(participant));
        }
        return participants;
    }
    
    open func info(_ info: MixChannelInfo, for channelJid: BareJID) async throws {
        _ = try await pubsubModule.publishItem(at: channelJid, to: "urn:xmpp:mix:nodes:info", payload: info.element(type: .result, onlyModified: false))
    }
    
    open func info(_ info: ChannelInfo, for channelJid: BareJID) async throws {
        _ = try await pubsubModule.publishItem(at: channelJid, to: "urn:xmpp:mix:nodes:info", payload: info.form().element(type: .result, onlyModified: false))
    }
    
    open func info(for channelJid: BareJID) async throws -> ChannelInfo {
        let items = try await pubsubModule.retrieveItems(from: channelJid, for: "urn:xmpp:mix:nodes:info");
        guard let item = items.items.sorted(by: { (i1, i2) in return i1.id > i2.id }).first else {
            throw XMPPError(condition: .item_not_found);
        }

        guard let context = self.context, let payload = item.payload, let mixInfo = MixChannelInfo(element: payload) else {
            throw XMPPError(condition: .item_not_found);
        }

        let info = mixInfo.channelInfo();
        if let channel = self.channelManager.channel(for: context, with: channelJid) {
            channel.update(info: info);
        }

        return info;
    }
    
    open func config(for channelJid: BareJID) async throws -> MixChannelConfig {
        let items = try await pubsubModule.retrieveItems(from: channelJid, for: "urn:xmpp:mix:nodes:config", limit: .lastItems(1));
        guard let item = items.items.first else {
            throw XMPPError(condition: .item_not_found);
        }
        guard let payload = item.payload, let config = MixChannelConfig(element: payload) else {
           throw XMPPError(condition: .item_not_found);
        }
        return config;
    }
    
    open func config(_ config: MixChannelConfig, for channelJid: BareJID) async throws {
        _ = try await pubsubModule.publishItem(at: channelJid, to: "urn:xmpp:mix:nodes:config", payload: config.element(type: .submit, onlyModified: false));
    }
    
    open func allowAccess(to channelJid: BareJID, for jid: BareJID, value: Bool = true) async throws {
        try await publishAccessRule(to: channelJid, for: jid, rule: .allow, value: value);
    }
    
    open func denyAccess(to channelJid: BareJID, for jid: BareJID, value: Bool = true) async throws {
        do {
            try await publishAccessRule(to: channelJid, for: jid, rule: .deny, value: value);
        } catch let error as XMPPError {
            guard error.condition == .item_not_found, let pubsubModule = pubsubModule else {
                throw error;
            }
            _ = try await pubsubModule.createNode(at: channelJid, node: AccessRule.deny.node);
            try await publishAccessRule(to: channelJid, for: jid, rule: .deny, value: value);
        }
    }

    
    open func createInvitation(_ invitation: MixInvitation, message body: String?) -> Message {
        let message = Message();
        message.type = .chat;
        message.id = UUID().uuidString;
        message.to = JID(invitation.invitee);
        message.mixInvitation = invitation;
        message.body = body;
        return message;
    }
    
    private func publishAccessRule(to channelJid: BareJID, for jid: BareJID, rule: AccessRule, value: Bool) async throws {
        if value {
            _ = try await pubsubModule.publishItem(at: channelJid, to: rule.node, itemId: jid.description, payload: nil);
        } else {
            _ = try await pubsubModule.retractItem(at: channelJid, from: rule.node, itemId: jid.description);
        }
    }
    
    open func changeAccessPolicy(of channelJid: BareJID, isPrivate: Bool) async throws {
        guard let jid = context?.userBareJid else {
           throw XMPPError.remote_server_timeout;
        }
        if isPrivate {
            _ = try await pubsubModule.createNode(at: channelJid, node: AccessRule.allow.node);
            try await allowAccess(to: channelJid, for: jid);
        } else {
            _ = try await pubsubModule.deleteNode(from: channelJid, node: AccessRule.allow.node);
        }
    }
    
    open func checkAccessPolicy(of channelJid: BareJID) async throws -> Bool {
        do {
            _ = try await retrieveAccessRules(for: channelJid, rule: .allow);
            return true;
        } catch let error as XMPPError {
            guard error.condition == .item_not_found else {
                throw error;
            }
            return false;
        }
    }
    
    open func allowed(for channelJid: BareJID) async throws -> [BareJID] {
        return try await retrieveAccessRules(for: channelJid, rule: .allow);
    }
    
    open func banned(for channelJid: BareJID) async throws -> [BareJID] {
        return try await retrieveAccessRules(for: channelJid, rule: .deny);
    }
    
    private func retrieveAccessRules(for channelJid: BareJID, rule: AccessRule) async throws -> [BareJID] {
        let items = try await pubsubModule.retrieveItems(from: channelJid, for: rule.node);
        return items.items.map({ BareJID($0.id) });
    }
        
    public enum AccessRule {
        case allow
        case deny
        
        var node: String {
            switch self {
            case .allow:
                return "urn:xmpp:mix:nodes:allowed";
            case .deny:
                return "urn:xmpp:mix:nodes:banned";
            }
        }
    }
    
    private func accountFeaturesChanged(_ features: [String]) {
        self.isPAM2SupportAvailable = features.contains(MixModule.PAM2_XMLNS);
        
        guard let context = context, context.isConnected else {
            return;
            
        }
        
        if !localMAMStoresPubSubEvents {
            if !isPAM2SupportAvailable {
                for channel in self.channelManager.channels(for: context) {
                    if let lastMessageDate = (channel as? LastMessageTimestampAware)?.lastMessageTimestamp {
                        Task {
                            try await self.retrieveHistory(fromChannel: channel.jid, start: lastMessageDate, rsm: .max(100));
                        }
                    } else {
                        Task {
                            try await self.retrieveHistory(fromChannel: channel.jid, start: nil, rsm: .last(100));
                        }
                    }
                }
            }
            for channel in self.channelManager.channels(for: context) {
                if self.automaticRetrieve.contains(.participants) {
                    Task {
                        try await participants(for: channel);
                    }
                }
                if self.automaticRetrieve.contains(.info) {
                    Task {
                        try await info(for: channel.jid);
                    }
                }
                if self.automaticRetrieve.contains(.affiliations) {
                    Task {
                        try await affiliations(for: channel);
                    }
                }
                if self.automaticRetrieve.contains(.avatar) {
                    Task {
                        try await avatar(for: channel.jid);
                    }
                }
            }
        }
        if isPAM2SupportAvailable {
            let items = rosterModule.rosterManager.items(for: context);
            for item in items {
                if let annotation = item.annotations.first(where: { item -> Bool in
                    return item.type == "mix";
                }), let participantId = annotation.values["participant-id"] {
                    let result = self.channelJoined(channelJid: item.jid.bareJid, participantId: participantId, nick: nil);
                    if let channel = result, (channel as? LastMessageTimestampAware)?.lastMessageTimestamp == nil {
                        Task {
                            try await retrieveHistory(fromChannel: item.jid.bareJid, start: nil, rsm: .last(100));
                        }
                    }
                }
            }
        }
    }
    
    private func receivedPubsubItem(notification: PubSubModule.ItemNotification) {
        // FIXME: should we do that on a separate queue?? we are retrieving channel and updating participants which may be blocking..
        guard let context = self.context, let from = notification.message.from?.bareJid, let channel = channelManager.channel(for: context, with: from) else {
            return;
        }
        
        switch notification.node {
        case "urn:xmpp:mix:nodes:participants":
            switch notification.action {
            case .published(let item):
                if let participant = MixParticipant(from: item, for: channel) {
                    if participant.id == channel.participantId {
                        channel.update(ownNickname: participant.nickname);
                    }
                    channel.update(participant: participant);
                    participantsEvents.send(.joined(participant));
                }
            case .retracted(let itemId):
                if channel.participantId == itemId {
                    channel.update(state: .left);
                }
                if let participant = channel.removeParticipant(withId: itemId) {
                    participantsEvents.send(.left(participant));
                }
            }
        case "urn:xmpp:mix:nodes:info":
            switch notification.action {
            case .published(let item):
                guard let payload = item.payload, let info = MixChannelInfo(element: payload) else {
                    return;
                }
                channel.update(info: info.channelInfo());
            default:
                break;
            }
        default:
            break;
        }
    }
    
    private func rosterItemChanged(_ action: RosterModule.RosterItemAction) {
        guard isPAM2SupportAvailable, let context = self.context else {
            return;
        }
        
        switch action {
        case .addedOrUpdated(let item):
            guard let annotation = item.annotations.first(where: { item -> Bool in
                return item.type == "mix";
            }), let participantId = annotation.values["participant-id"] else {
                return;
            }
            
            let result = self.channelJoined(channelJid: item.jid.bareJid, participantId: participantId, nick: nil);
            if !isPAM2SupportAvailable {
                Task {
                    try await retrieveHistory(fromChannel: item.jid.bareJid, start: nil, rsm: .last(100));
                }
            } else if let channel = result, (channel as? LastMessageTimestampAware)?.lastMessageTimestamp == nil {
                Task {
                    try await retrieveHistory(fromChannel: item.jid.bareJid, start: nil, rsm: .last(100));
                }
            }
        case .removed(let jid):
            guard let channel = channelManager.channel(for: context, with: jid.bareJid) else {
                return;
            }
            self.channelLeft(channel: channel);
        }
    }
    
    open func retrieveAllHistory(fromChannel jid: BareJID, start: Date?, rsm: RSM.Query) async throws {
        let result = try await retrieveHistory(fromChannel: jid, start: start, rsm: rsm);
        if !result.complete, let nextRsm = result.rsm?.next() {
            try await retrieveAllHistory(fromChannel: jid, start: start, rsm: nextRsm);
        }
    }
    
    open func retrieveHistory(fromChannel jid: BareJID, start: Date?, rsm: RSM.Query) async throws -> MessageArchiveManagementModule.QueryResult {
        let queryId = UUID().uuidString;
        // should we query MIX messages node? or just MAM at MIX channel without a node?
        return try await mamModule.queryItems(MAMQueryForm(version: .MAM2, start: start), at: JID(jid), node: "urn:xmpp:mix:nodes:messages", queryId: queryId, rsm: rsm);
    }
    
    open func avatar(for jid: BareJID) async throws -> PEPUserAvatarModule.Info {
        return try await avatarModule.retrieveAvatarMetadata(from: jid);
    }

    public typealias ParticipantsResult = Result<[MixParticipant],XMPPError>
    
    public enum ParticipantEvent {
        case joined(MixParticipant);
        case left(MixParticipant);
    }
    
    public struct MessageReceived {
        public let channel: ChannelProtocol;
        public let message: Message;
    }
}

public final class MixInvitation: Sendable {
    public let inviter: BareJID;
    public let invitee: BareJID;
    public let channel: BareJID;
    public let token: String?;
    
    public convenience init?(from el: Element?) {
        guard el?.name == "invitation" && el?.xmlns == "urn:xmpp:mix:misc:0" else {
            return nil;
        }
        guard let inviter = BareJID(el?.firstChild(name: "inviter")?.value), let invitee = BareJID(el?.firstChild(name: "invitee")?.value), let channel = BareJID(el?.firstChild(name: "channel")?.value) else {
            return nil;
        }
        self.init(inviter: inviter, invitee: invitee, channel: channel, token: el?.firstChild(name: "token")?.value);
    }
    
    public init(inviter: BareJID, invitee: BareJID, channel: BareJID, token: String?) {
        self.inviter = inviter;
        self.invitee = invitee;
        self.channel = channel;
        self.token = token;
    }
    
    public func element() -> Element {
        return Element(name: "invitation", xmlns: "urn:xmpp:mix:misc:0", children: [
            Element(name: "inviter", cdata: inviter.description),
            Element(name: "invitee", cdata: invitee.description),
            Element(name: "channel", cdata: channel.description),
            Element(name: "token", cdata: token)
        ]);
    }
}

extension Message {
    public var mixInvitation: MixInvitation? {
        get {
            return MixInvitation(from: firstChild(name: "invitation", xmlns: "urn:xmpp:mix:misc:0"));
        }
        set {
            element.removeChildren(where: { $0.name == "invitation" && $0.xmlns == "urn:xmpp:mix:misc:0"});
            if let value = newValue {
                element.addChild(value.element());
            }
        }
    }
}

// async-await support
extension MixModule {
    
    public func create(channel: String?, at componentJid: BareJID, completionHandler: @escaping (Result<BareJID,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await create(channel: channel, at: componentJid)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func destroy(channel channelJid: BareJID, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await destroy(channel: channelJid)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func join(channel channelJid: BareJID, withNick nick: String?, subscribeNodes nodes: [String] = ["urn:xmpp:mix:nodes:messages", "urn:xmpp:mix:nodes:participants", "urn:xmpp:mix:nodes:info", "urn:xmpp:avatar:metadata"], presenceSubscription: Bool = true, invitation: MixInvitation? = nil, messageSyncLimit: Int = 100, completionHandler: @escaping (Result<Iq,XMPPError>) -> Void) {
        Task {
            do {
                completionHandler(.success(try await join(channel: channelJid, withNick: nick, subscribeNodes: nodes, presenceSubscription: presenceSubscription, invitation: invitation, messageSyncLimit: messageSyncLimit)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func leave(channel: ChannelProtocol, completionHandler: @escaping (Result<Iq,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await leave(channel: channel)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func retrieveParticipants(for channel: ChannelProtocol, completionHandler: ((ParticipantsResult)->Void)?) {
        Task {
            do {
                let result = try await participants(for: channel);
                completionHandler?(.success(result))
            } catch {
                completionHandler?(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func retrieveAffiliations(for channel: ChannelProtocol, completionHandler: ((Result<Set<ChannelPermission>,XMPPError>)->Void)?) {
        Task {
            do {
                let result = try await affiliations(for: channel);
                completionHandler?(.success(result));
            } catch {
                completionHandler?(.failure(error as? XMPPError ?? .undefined_condition));
            }
        }
    }
    
    public func publishInfo(for channelJid: BareJID, info: ChannelInfo, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await self.info(info, for: channelJid)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition));
            }
        }
    }
    
    public func retrieveInfo(for channelJid: BareJID, completionHandler: ((Result<ChannelInfo,XMPPError>)->Void)?) {
        Task {
            do {
                let result = try await info(for: channelJid);
                completionHandler?(.success(result));
            } catch {
                completionHandler?(.failure(error as? XMPPError ?? .undefined_condition));
            }
        }
    }
    
    public func retrieveConfig(for channelJid: BareJID, completionHandler: @escaping (Result<MixChannelConfig,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await config(for: channelJid)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition));
            }
        }
    }
    
    public func updateConfig(for channelJid: BareJID, config: MixChannelConfig, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await self.config(config, for: channelJid)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition));
            }
        }
    }
    
    public func allowAccess(to channelJid: BareJID, for jid: BareJID, value: Bool = true, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await allowAccess(to: channelJid, for: jid, value: value)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func denyAccess(to channelJid: BareJID, for jid: BareJID, value: Bool = true, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await denyAccess(to: channelJid, for: jid, value: value)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
        
    public func changeAccessPolicy(of channelJid: BareJID, isPrivate: Bool, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await changeAccessPolicy(of: channelJid, isPrivate: isPrivate)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func checkAccessPolicy(of channelJid: BareJID, completionHandler: @escaping (Result<Bool,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await checkAccessPolicy(of: channelJid)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

    public func retrieveAllowed(for channelJid: BareJID, completionHandler: @escaping (Result<[BareJID],XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await allowed(for: channelJid)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func retrieveBanned(for channelJid: BareJID, completionHandler: @escaping (Result<[BareJID],XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await banned(for: channelJid)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func retrieveHistory(fromChannel jid: BareJID, start: Date? = nil, rsm: RSM.Query) {
        Task {
            try await retrieveAllHistory(fromChannel: jid, start: start, rsm: rsm);
        }
    }
    
    public func retrieveAvatar(for jid: BareJID, completionHandler: ((Result<PEPUserAvatarModule.Info, XMPPError>)->Void)?) {
        Task {
            do {
                let result = try await avatar(for: jid);
                completionHandler?(.success(result))
            } catch {
                completionHandler?(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

}

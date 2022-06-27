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

open class MixModule: XmppModuleBaseSessionStateAware, XmppModule, RosterAnnotationAwareProtocol {
    func prepareRosterGetRequest(queryElem el: Element) {
        el.addChild(Element(name: "annotate", xmlns: "urn:xmpp:mix:roster:0"));
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
    
    open func create(channel: String?, at componentJid: BareJID, completionHandler: @escaping (Result<BareJID,XMPPError>)->Void) {
        guard componentJid.localPart == nil else {
            completionHandler(.failure(XMPPError(condition: .bad_request, message: "MIX component JID cannot have local part set!")));
            return;
        }
        
        let iq = Iq(type: .set, to: JID(componentJid));
        let createEl = Element(name: "create", xmlns: MixModule.CORE_XMLNS);
        if channel != nil {
            createEl.attribute("channel", newValue: channel);
        }
        iq.addChild(createEl);
        write(iq: iq, completionHandler: { result in
            switch result {
            case .success(let response):
                if let channel = response.firstChild(name: "create", xmlns: MixModule.CORE_XMLNS)?.attribute("channel") {
                    completionHandler(.success(BareJID(localPart: channel, domain: componentJid.domain)));
                } else {
                    completionHandler(.failure(.undefined_condition));
                }
            case .failure(let error):
                completionHandler(.failure(error));
            }
        });
    }
        
    open func destroy(channel channelJid: BareJID, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        guard channelJid.localPart != nil else {
            completionHandler(.failure(XMPPError(condition: .bad_request, message: "Channel JID must have a local part!")));
            return;
        }
        guard let context = self.context else {
            completionHandler(.failure(.remote_server_timeout));
            return;
        }
        
        let iq = Iq(type: .set, to: JID(channelJid.domain));
        let destroyEl = Element(name: "destroy", xmlns: MixModule.CORE_XMLNS);
        destroyEl.attribute("channel", newValue: channelJid.localPart);
        iq.addChild(destroyEl);
        write(iq: iq, completionHandler: { result in
            switch result {
            case .success(_):
                if let channel = self.channelManager.channel(for: context, with: channelJid) {
                    _  = self.channelManager.close(channel: channel);
                }
                self.rosterModule?.removeItem(jid: JID(channelJid), completionHandler: { _ in });
                completionHandler(.success(Void()));
            case .failure(let error):
                completionHandler(.failure(error));
            }
        });
    }
    
    open func join(channel channelJid: BareJID, withNick nick: String?, subscribeNodes nodes: [String] = ["urn:xmpp:mix:nodes:messages", "urn:xmpp:mix:nodes:participants", "urn:xmpp:mix:nodes:info", "urn:xmpp:avatar:metadata"], presenceSubscription: Bool = true, invitation: MixInvitation? = nil, messageSyncLimit: Int = 100, completionHandler: @escaping (Result<Iq,XMPPError>) -> Void) {
        guard let context = self.context else {
            completionHandler(.failure(.remote_server_timeout));
            return;
        }
        if isPAM2SupportAvailable {
            let iq = Iq();
            iq.to = JID(context.userBareJid);
            iq.type = .set;
            let clientJoin = Element(name: "client-join", xmlns: MixModule.PAM2_XMLNS);
            clientJoin.attribute("channel", newValue: channelJid.description);
            clientJoin.addChild(createJoinEl(withNick: nick, withNodes: nodes, invitation: invitation));
            iq.addChild(clientJoin);
            
            write(iq: iq, completionHandler: { result in
                switch result {
                case .success(let response):
                    if let joinEl = response.firstChild(name: "client-join", xmlns: MixModule.PAM2_XMLNS)?.firstChild(name: "join", xmlns: MixModule.CORE_XMLNS) {
                        if let resultJid = joinEl.attribute("jid"), let idx = resultJid.firstIndex(of: "#") {
                            let participantId = String(resultJid[resultJid.startIndex..<idx]);
                            let jid = BareJID(String(resultJid[resultJid.index(after: idx)..<resultJid.endIndex]));
                            _ = self.channelJoined(channelJid: jid, participantId: participantId, nick: joinEl.firstChild(name: "nick")?.value);
                            
                            self.retrieveHistory(fromChannel: channelJid, rsm: .last(messageSyncLimit));
                            if presenceSubscription {
                                self.presenceModule?.subscribed(by: JID(channelJid));
                                self.presenceModule?.subscribe(to: JID(channelJid));
                            }
                        } else if let participantId = joinEl.attribute("id") {
                            _ = self.channelJoined(channelJid: channelJid, participantId: participantId, nick: joinEl.firstChild(name: "nick")?.value);
                            self.retrieveHistory(fromChannel: channelJid, rsm: .last(messageSyncLimit));
                            if presenceSubscription {
                                self.presenceModule?.subscribed(by: JID(channelJid));
                                self.presenceModule?.subscribe(to: JID(channelJid));
                            }
                        }
                    }
                default:
                    break;
                }
                completionHandler(result);
            });
        } else {
            let iq = Iq(type: .set, to: JID(channelJid));
            iq.addChild(createJoinEl(withNick: nick, withNodes: nodes, invitation: invitation));
            write(iq: iq, completionHandler: { result in
                switch result {
                case .success(let response):
                    if let joinEl = response.firstChild(name: "join", xmlns: MixModule.CORE_XMLNS), let participantId = joinEl.attribute("id") {
                        self.retrieveHistory(fromChannel: channelJid, rsm: .last(messageSyncLimit));
                        _ = self.channelJoined(channelJid: channelJid, participantId: participantId, nick: joinEl.firstChild(name: "nick")?.value);
                    }
                default:
                    break;
                }
                completionHandler(result);
            });
        }
    }
    
    open func leave(channel: ChannelProtocol, completionHandler: @escaping (Result<Iq,XMPPError>)->Void) {
        guard let context = context else {
            completionHandler(.failure(.remote_server_timeout));
            return;
        }
        if isPAM2SupportAvailable {
            let iq = Iq(type: .set, to: JID(context.userBareJid));
            iq.type = .set;
            let clientLeave = Element(name: "client-leave", xmlns: MixModule.PAM2_XMLNS);
            clientLeave.attribute("channel", newValue: channel.jid.description);
            clientLeave.addChild(Element(name: "leave", xmlns: MixModule.CORE_XMLNS));
            iq.addChild(clientLeave);
            
            write(iq: iq, completionHandler: { result in
                switch result {
                case .success(_):
                    self.channelLeft(channel: channel);
                default:
                    break;
                }
                completionHandler(result);
            });
        } else {
            let iq = Iq(type: .set, to: JID(channel.jid));
            iq.addChild(Element(name: "leave", xmlns: MixModule.CORE_XMLNS));
            write(iq: iq, completionHandler: { result in
                switch result {
                case .success(_):
                    self.channelLeft(channel: channel);
                default:
                    break;
                }
                completionHandler(result);
            });
        }
    }
    
    open func channelJoined(channelJid: BareJID, participantId: String, nick: String?) -> ChannelProtocol? {
        guard let context = self.context else {
            return nil;
        }
        switch self.channelManager.createChannel(for: context, with: channelJid, participantId: participantId, nick: nick, state: .joined) {
        case .created(let channel):
            if self.automaticRetrieve.contains(.participants) {
                retrieveParticipants(for: channel, completionHandler: nil);
            }
            retrieveInfo(for: channel.jid, completionHandler: nil);
            retrieveAffiliations(for: channel, completionHandler: nil);
            if self.automaticRetrieve.contains(.avatar) {
                retrieveAvatar(for: channel.jid, completionHandler: nil);
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
        let joinEl = Element(name: "join", xmlns: MixModule.CORE_XMLNS);
        joinEl.addChildren(nodes.map({ Element(name: "subscribe", attributes: ["node": $0]) }));
        if let nick = nick {
            joinEl.addChild(Element(name: "nick", cdata: nick));
        }
        if let invitation = invitation {
            joinEl.addChild(invitation.element());
        }
        return joinEl;
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
    
    open func retrieveAffiliations(for channel: ChannelProtocol, completionHandler: ((PermissionsResult)->Void)?) {
        pubsubModule.retrieveOwnAffiliations(from: channel.jid, for: nil, completionHandler: { result in
            switch result {
            case .success(let affiliations):
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
                channel.update(permissions: permissions);
            case .failure(_):
                channel.update(permissions: []);
            }
        })
    }
    
    open func retrieveParticipants(for channel: ChannelProtocol, completionHandler: ((ParticipantsResult)->Void)?) {
        pubsubModule.retrieveItems(from: channel.jid, for: "urn:xmpp:mix:nodes:participants", completionHandler: { result in
            switch result {
            case .success(let items):
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
                completionHandler?(.success(participants));
            case .failure(let error):
                completionHandler?(.failure(error));
            }
        })
    }
    
    open func publishInfo(for channelJid: BareJID, info: ChannelInfo, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        pubsubModule.publishItem(at: channelJid, to: "urn:xmpp:mix:nodes:info", payload: info.form().element(type: .result, onlyModified: false), completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        });
    }
    
    open func retrieveInfo(for channelJid: BareJID, completionHandler: ((Result<ChannelInfo,XMPPError>)->Void)?) {
        pubsubModule.retrieveItems(from: channelJid, for: "urn:xmpp:mix:nodes:info", completionHandler: { result in
            switch result {
            case .success(let items):
                guard let item = items.items.sorted(by: { (i1, i2) in return i1.id > i2.id }).first else {
                    completionHandler?(.failure(XMPPError(condition: .item_not_found)));
                    return;
                }
                guard let context = self.context, let payload = item.payload, let mixInfo = MixChannelInfo(element: payload) else {
                    completionHandler?(.failure(XMPPError(condition: .item_not_found)));
                    return;
                }
                let info = mixInfo.channelInfo();
                if let channel = self.channelManager.channel(for: context, with: channelJid) {
                    channel.update(info: info);
                }
                completionHandler?(.success(info));
            case .failure(let error):
                completionHandler?(.failure(error));
            }
        });
    }

    open func retrieveConfig(for channelJid: BareJID, completionHandler: @escaping (Result<MixChannelConfig,XMPPError>)->Void) {
        pubsubModule.retrieveItems(from: channelJid, for: "urn:xmpp:mix:nodes:config", limit: .lastItems(1), completionHandler: { result in
            switch result {
            case .success(let items):
                guard let item = items.items.first else {
                    completionHandler(.failure(XMPPError(condition: .item_not_found)));
                    return;
                }
                guard let payload = item.payload, let config = MixChannelConfig(element: payload) else {
                    completionHandler(.failure(XMPPError(condition: .item_not_found)));
                    return;
                }
                completionHandler(.success(config));
            case .failure(let error):
                completionHandler(.failure(error));
            }
        });
    }
    
    open func updateConfig(for channelJid: BareJID, config: MixChannelConfig, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        pubsubModule.publishItem(at: channelJid, to: "urn:xmpp:mix:nodes:config", payload: config.element(type: .submit, onlyModified: false), completionHandler: { response in
            switch response {
            case .success(_):
                completionHandler(.success(Void()));
            case .failure(let error):
                completionHandler(.failure(error));
            }
        });
    }
    
    open func allowAccess(to channelJid: BareJID, for jid: BareJID, value: Bool = true, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        publishAccessRule(to: channelJid, for: jid, rule: .allow, value: value, completionHandler: completionHandler);
    }
    
    open func denyAccess(to channelJid: BareJID, for jid: BareJID, value: Bool = true, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        publishAccessRule(to: channelJid, for: jid, rule: .deny, value: value, completionHandler: { result in
            switch result {
            case.success(let r):
                completionHandler(.success(r));
            case .failure(let error):
                guard error.condition == .item_not_found, let pubsubModule = self.pubsubModule else {
                    completionHandler(.failure(error));
                    return;
                }
                pubsubModule.createNode(at: channelJid, node: AccessRule.deny.node, completionHandler: { result in
                    switch result {
                    case .success(_):
                        self.publishAccessRule(to: channelJid, for: jid, rule: .deny, value: value, completionHandler: completionHandler);
                    case .failure(let error):
                        completionHandler(.failure(error));
                    }
                })
            }
        });
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
    
    private func publishAccessRule(to channelJid: BareJID, for jid: BareJID, rule: AccessRule, value: Bool, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        if value {
            pubsubModule.publishItem(at: channelJid, to: rule.node, itemId: jid.description, payload: nil, completionHandler: { result in
                completionHandler(result.map({ _ in Void() }))
            })
        } else {
            pubsubModule.retractItem(at: channelJid, from: rule.node, itemId: jid.description, completionHandler: { result in
                completionHandler(result.map({ _ in Void() }))
            })
        }
    }
    
    open func changeAccessPolicy(of channelJid: BareJID, isPrivate: Bool, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        guard let jid = context?.userBareJid else {
            completionHandler(.failure(.remote_server_timeout));
            return;
        }
        if isPrivate {
            pubsubModule.createNode(at: channelJid, node: AccessRule.allow.node, completionHandler: { result in
                switch result {
                case .success(_):
                    self.allowAccess(to: channelJid, for: jid, completionHandler: completionHandler);
                case .failure(let error):
                    completionHandler(.failure(error));
                }
            })
        } else {
            pubsubModule.deleteNode(from: channelJid, node: AccessRule.allow.node, completionHandler: { result in
                completionHandler(result.map({ _ in Void() }))
            })
        }
    }
    
    open func checkAccessPolicy(of channelJid: BareJID, completionHandler: @escaping (Result<Bool,XMPPError>)->Void) {
        self.retrieveAccessRules(for: channelJid, rule: .allow, completionHandler: { result in
            switch result {
            case .success(_):
                completionHandler(.success(true));
            case .failure(let error):
                if error.condition == .item_not_found {
                    completionHandler(.success(false));
                } else {
                    completionHandler(.failure(error));
                }
            }
        });
    }
    
    open func retrieveAllowed(for channelJid: BareJID, completionHandler: @escaping (Result<[BareJID],XMPPError>)->Void) {
        self.retrieveAccessRules(for: channelJid, rule: .allow, completionHandler: completionHandler);
    }
    
    open func retrieveBanned(for channelJid: BareJID, completionHandler: @escaping (Result<[BareJID],XMPPError>)->Void) {
        self.retrieveAccessRules(for: channelJid, rule: .deny, completionHandler: completionHandler);
    }
    
    private func retrieveAccessRules(for channelJid: BareJID, rule: AccessRule, completionHandler: @escaping (Result<[BareJID],XMPPError>)->Void) {
        pubsubModule.retrieveItems(from: channelJid, for: rule.node, completionHandler: { result in
            completionHandler(result.map({ items in
                return items.items.map({ BareJID($0.id) })
            }))
        })
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
                        self.retrieveHistory(fromChannel: channel.jid, start: lastMessageDate, rsm: .max(100));
                    } else {
                        self.retrieveHistory(fromChannel: channel.jid, rsm: .last(100));
                    }
                }
            }
            for channel in self.channelManager.channels(for: context) {
                if self.automaticRetrieve.contains(.participants) {
                    retrieveParticipants(for: channel, completionHandler: nil);
                }
                if self.automaticRetrieve.contains(.info) {
                    retrieveInfo(for: channel.jid, completionHandler: nil);
                }
                if self.automaticRetrieve.contains(.affiliations) {
                    retrieveAffiliations(for: channel, completionHandler: nil);
                }
                if self.automaticRetrieve.contains(.avatar) {
                    retrieveAvatar(for: channel.jid, completionHandler: nil);
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
                        retrieveHistory(fromChannel: item.jid.bareJid, rsm: .last(100));
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
                retrieveHistory(fromChannel: item.jid.bareJid, rsm: .last(100));
            } else if let channel = result, (channel as? LastMessageTimestampAware)?.lastMessageTimestamp == nil {
                retrieveHistory(fromChannel: item.jid.bareJid, rsm: .last(100));
            }
        case .removed(let jid):
            guard let channel = channelManager.channel(for: context, with: jid.bareJid) else {
                return;
            }
            self.channelLeft(channel: channel);
        }
    }

    open func retrieveHistory(fromChannel jid: BareJID, start: Date? = nil, rsm: RSM.Query) {
        let queryId = UUID().uuidString;
        // should we query MIX messages node? or just MAM at MIX channel without a node?
        mamModule.queryItems(version: .MAM2, componentJid: JID(jid), node: "urn:xmpp:mix:nodes:messages", start: nil, queryId: queryId, rsm: rsm, completionHandler: { result in
            switch result {
            case .success(let queryResult):
                guard !queryResult.complete, let rsmQuery = queryResult.rsm?.next() else {
                    return;
                }
                self.retrieveHistory(fromChannel: jid, start: start, rsm: rsmQuery);
            case .failure(_):
                break;
            }
        });
    }
    
    open func retrieveAvatar(for jid: BareJID, completionHandler: ((Result<PEPUserAvatarModule.Info, XMPPError>)->Void)?) {
        avatarModule.retrieveAvatarMetadata(from: jid, itemId: nil, fireEvents: true, completionHandler: { result in
            completionHandler?(result);
        });
    }

    public typealias ParticipantsResult = Result<[MixParticipant],XMPPError>
    public typealias PermissionsResult = Result<[ChannelPermission],XMPPError>
    
    public enum ParticipantEvent {
        case joined(MixParticipant);
        case left(MixParticipant);
    }
    
    public struct MessageReceived {
        public let channel: ChannelProtocol;
        public let message: Message;
    }
}

open class MixInvitation {
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
    
    open func element() -> Element {
        return Element(name: "invitation", xmlns: "urn:xmpp:mix:misc:0", children: [
            Element(name: "inviter", cdata: inviter.description),
            Element(name: "invitee", cdata: invitee.description),
            Element(name: "channel", cdata: channel.description),
            Element(name: "token", cdata: token)
        ]);
    }
}

extension Message {
    open var mixInvitation: MixInvitation? {
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
    open func create(channel: String?, at componentJid: BareJID) async throws -> BareJID {
        return try await withUnsafeThrowingContinuation { continuation in
            create(channel: channel, at: componentJid, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func join(channel channelJid: BareJID, withNick nick: String?, subscribeNodes nodes: [String] = ["urn:xmpp:mix:nodes:messages", "urn:xmpp:mix:nodes:participants", "urn:xmpp:mix:nodes:info", "urn:xmpp:avatar:metadata"], presenceSubscription: Bool = true, invitation: MixInvitation? = nil, messageSyncLimit: Int = 100) async throws -> Iq {
        return try await withUnsafeThrowingContinuation { continuation in
            join(channel: channelJid, withNick: nick, subscribeNodes: nodes, presenceSubscription: presenceSubscription, invitation: invitation, messageSyncLimit: messageSyncLimit, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func leave(channel: ChannelProtocol, completionHandler: @escaping (Result<Iq,XMPPError>)->Void) async throws -> Iq {
        return try await withUnsafeThrowingContinuation { continuation in
            leave(channel: channel, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func retrieveAffiliations(for channel: ChannelProtocol) async throws -> [ChannelPermission] {
        return try await withUnsafeThrowingContinuation { continuation in
            retrieveAffiliations(for: channel, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func publishInfo(for channelJid: BareJID, info: ChannelInfo) async throws {
        _ = try await withUnsafeThrowingContinuation { continuation in
            publishInfo(for: channelJid, info: info, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func retrieveInfo(for channelJid: BareJID) async throws -> ChannelInfo {
        return try await withUnsafeThrowingContinuation { continuation in
            retrieveInfo(for: channelJid, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }

    open func retrieveConfig(for channelJid: BareJID) async throws -> MixChannelConfig {
        return try await withUnsafeThrowingContinuation { continuation in
            retrieveConfig(for: channelJid, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func updateConfig(for channelJid: BareJID, config: MixChannelConfig) async throws {
        return try await withUnsafeThrowingContinuation { continuation in
            updateConfig(for: channelJid, config: config, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func allowAccess(to channelJid: BareJID, for jid: BareJID, value: Bool = true) async throws {
        return try await withUnsafeThrowingContinuation { continuation in
            allowAccess(to: channelJid, for: jid, value: value, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func denyAccess(to channelJid: BareJID, for jid: BareJID, value: Bool = true) async throws {
        return try await withUnsafeThrowingContinuation { continuation in
            denyAccess(to: channelJid, for: jid, value: value, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func changeAccessPolicy(of channelJid: BareJID, isPrivate: Bool) async throws {
        return try await withUnsafeThrowingContinuation { continuation in
            changeAccessPolicy(of: channelJid, isPrivate: isPrivate, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func checkAccessPolicy(of channelJid: BareJID) async throws -> Bool {
        return try await withUnsafeThrowingContinuation { continuation in
            checkAccessPolicy(of: channelJid, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func retrieveAllowed(for channelJid: BareJID) async throws -> [BareJID] {
        return try await withUnsafeThrowingContinuation { continuation in
            retrieveAllowed(for: channelJid, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func retrieveBanned(for channelJid: BareJID) async throws -> [BareJID] {
        return try await withUnsafeThrowingContinuation { continuation in
            retrieveBanned(for: channelJid, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }

    open func retrieveHistory(fromChannel jid: BareJID, start: Date?, rsm: RSM.Query) async throws -> MessageArchiveManagementModule.QueryResult {
        let queryId = UUID().uuidString;
        // should we query MIX messages node? or just MAM at MIX channel without a node?
        return try await mamModule.queryItems(version: .MAM2, componentJid: JID(jid), node: "urn:xmpp:mix:nodes:messages", start: nil, queryId: queryId, rsm: rsm);
    }
    
    open func retrieveAvatar(for jid: BareJID, completionHandler: ((Result<PEPUserAvatarModule.Info, XMPPError>)->Void)?) async throws -> PEPUserAvatarModule.Info {
        return try await withUnsafeThrowingContinuation { continuation in
            retrieveAvatar(for: jid, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
}

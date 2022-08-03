//
// ChannelBase.swift
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

open class ChannelBase: ConversationBase, ChannelProtocol {
        
    open override var defaultMessageType: StanzaType {
        return .groupchat;
    }
    
    public let participantId: String;
    open var nickname: String?;
    open private(set) var state: ChannelState;
    
    @Published
    open private(set) var permissions: Set<ChannelPermission>?;
    
    public var permissionsPublisher: AnyPublisher<Set<ChannelPermission>,Never> {
        if permissions == nil {
            context?.module(.mix).retrieveAffiliations(for: self, completionHandler: nil);
        }
        return $permissions.compactMap({ $0 }).eraseToAnyPublisher();
    }
    
    private let participantsStore: MixParticipantsProtocol = MixParticipantsBase();
    
    private var info: ChannelInfo?;
    
    open var name: String? {
        return info?.name;
    }
    open var description: String? {
        return info?.description;
    }
    
    public init(context: Context, channelJid: BareJID, participantId: String, nickname: String?, state: ChannelState) {
        self.participantId = participantId;
        self.nickname = nickname;
        self.state = state;
        super.init(context: context, jid: channelJid);
    }
    
    public func update(info: ChannelInfo) {
        // nothing to do
    }
    
    public func update(ownNickname nickname: String?) {
        self.nickname = nickname;
    }
    
    public func update(permissions: Set<ChannelPermission>) {
        self.permissions = permissions;
    }

    public func update(state: ChannelState) {
        self.state = state;
    }
}

extension ChannelBase: MixParticipantsProtocol {
    
    public var participants: [MixParticipant] {
        return participantsStore.participants;
    }
    
    public var participantsPublisher: AnyPublisher<[MixParticipant],Never> {
        return self.participantsStore.participantsPublisher;
    }
    
    public func participant(withId: String) -> MixParticipant? {
        return participantsStore.participant(withId: withId);
    }
    
    public func set(participants: [MixParticipant]) {
        participantsStore.set(participants: participants);
    }
    
    public func update(participant: MixParticipant) {
        participantsStore.update(participant: participant);
    }
    
    public func removeParticipant(withId id: String) -> MixParticipant? {
        return participantsStore.removeParticipant(withId: id);
    }
}

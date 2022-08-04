//
// ChatMarkersModule.swift
//
// TigaseSwift
// Copyright (C) 2021 "Tigase, Inc." <office@tigase.com>
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
    public static var chatMarkers: XmppModuleIdentifier<ChatMarkersModule> {
        return ChatMarkersModule.IDENTIFIER;
    }
}

open class ChatMarkersModule: XmppModuleBase, XmppStanzaProcessor, @unchecked Sendable {
    
    public static let ID = Message.ChatMarkers.XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<ChatMarkersModule>();
    
    public let criteria: Criteria = Criteria.name("message");
    public let features: [String] = [Message.ChatMarkers.XMLNS];
    
    open override var context: Context? {
        didSet {
            context?.moduleOrNil(.messageCarbons)?.carbonsPublisher.sink(receiveValue: { [weak self] carbon in
                self?.handleCarbon(carbon: carbon);
            }).store(in: self);
            context?.moduleOrNil(.mam)?.archivedMessagesPublisher.sink(receiveValue: { [weak self] archived in
                self?.handleArchived(archived: archived);
            }).store(in: self);
        }
    }
    
    public let markersPublisher = PassthroughSubject<ChatMarkerReceived, Never>();
    
    public func process(stanza: Stanza) throws {
        guard let message = stanza as? Message else {
            return;
        }
        
        process(message: message)
    }
    
    private func handleArchived(archived: MessageArchiveManagementModule.ArchivedMessageReceived) {
        process(message: archived.message);
    }
    
    private func handleCarbon(carbon: MessageCarbonsModule.CarbonReceived) {
        process(message: carbon.message);
    }
    
    private func process(message: Message) {
        guard let marker = message.chatMarkers else {
            return;
        }
        
        markersPublisher.send(.init(message: message, marker: marker));
    }
    
    public struct ChatMarkerReceived {
        public let message: Message;
        public let marker: Message.ChatMarkers;
    }
    
}

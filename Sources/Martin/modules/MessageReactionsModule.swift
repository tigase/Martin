//
// MessageReactionsModule.swift
//
// Martin
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
    public static var messageReactions: XmppModuleIdentifier<MessageReactionsModule> {
        return MessageReactionsModule.IDENTIFIER;
    }
}

open class MessageReactionsModule: XmppModuleBase, XmppModule, @unchecked Sendable {
    
    public static let XMLNS = "urn:xmpp:reactions:0";
    public static let IDENTIFIER = XmppModuleIdentifier<MessageReactionsModule>();
    
    public static let ID = XMLNS;
    
    public let features: [String] = [XMLNS];
    
    private var discoModule: DiscoveryModule!;
    open override var context: Context? {
        didSet {
            if let context {
                discoModule = context.module(.disco);
            } else {
                discoModule = nil
            }
        }
    }
    
    public func reactionsLimits(for jid: JID) async throws -> ReactionsLimits? {
        let info = try await discoModule.info(for: jid);
        return .init(info: info);
    }

    open class ReactionsLimits: DataFormWrapper, @unchecked Sendable {
        
        @Field("allowlist")
        public var allowlist: [String]?;
        @Field("max_reactions_per_user")
        public var maxReactionsPerUser: Int?;
        
        public convenience init?(element: Element) {
            guard let form = DataForm(element: element) else {
                return nil;
            }
            self.init(form: form);
        }
        
        public override init(form: DataForm? = nil) {
            super.init(form: form);
        }
        
        public convenience init?(info: DiscoveryModule.DiscoveryInfoResult? = nil) {
            guard let form = info?.form else {
                return nil;
            }
            self.init(form: form);
        }
        
    }
}

extension Message {
    
    public struct Reactions {
        // message id for 1-1 (attribute), stable-id for MUC messages
        public let messageId: String;
        public let reactions: Set<String>;
        
    }
    
    public var reactions: Reactions? {
        get {
            guard let reactionsEl = firstChild(name: "reactions", xmlns: MessageReactionsModule.XMLNS) else {
                return nil;
            }
            guard let id = reactionsEl.attribute("id") else {
                return nil;
            }
            return .init(messageId: id, reactions: Set(reactionsEl.filterChildren(name: "reaction").compactMap({ $0.value })));
        }
        set {
            removeChildren(name: "reactions", xmlns: MessageReactionsModule.XMLNS);
            if let newValue = newValue {
                addChildren {
                    Element(name: "reactions", xmlns: MessageReactionsModule.XMLNS) {
                        Attribute("id", value: newValue.messageId);
                        newValue.reactions.map({
                            Element(name: "reactions", cdata: $0)
                        })
                    }
                }
                var hints = self.hints;
                if (!hints.contains(.store)) {
                    hints.append(.store)
                    self.hints = hints;
                }
            }
        }
    }
}

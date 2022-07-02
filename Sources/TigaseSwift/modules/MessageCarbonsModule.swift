//
// MessageCarbonsModule.swift
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
import Combine

extension XmppModuleIdentifier {
    public static var messageCarbons: XmppModuleIdentifier<MessageCarbonsModule> {
        return MessageCarbonsModule.IDENTIFIER;
    }
}

/**
 Module provides support for [XEP-0280: Message Carbons]
 
 [XEP-0280: Message Carbons]: http://xmpp.org/extensions/xep-0280.html
 */
open class MessageCarbonsModule: XmppModuleBase, XmppModule {
    /// Namespace used by Message Carbons
    public static let MC_XMLNS = "urn:xmpp:carbons:2";
    /// Namepsace used for forwarding messages
    fileprivate static let SF_XMLNS = "urn:xmpp:forward:0";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = MC_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<MessageCarbonsModule>();
    
    public let criteria = Criteria.name("message").add(Criteria.xmlns(MC_XMLNS));
    
    public let features = [MC_XMLNS];
    
    open override weak var context: Context? {
        didSet {
            messageModule = context?.modulesManager.module(.message);
            context?.module(.disco).$serverDiscoResult.sink(receiveValue: { [weak self] result in
                self?.isAvailable = result.features.contains(MessageCarbonsModule.MC_XMLNS);
            }).store(in: self);
        }
    }
    
    @Published
    open private(set) var isAvailable: Bool = false;
    
    public let carbonsPublisher = PassthroughSubject<CarbonReceived, Never>();
    
    private var messageModule: MessageModule!;
    
    public override init() {
        
    }
    
    open func process(stanza message: Stanza) throws {
        var error: XMPPError? = nil;
        for carb in message.filterChildren(xmlns: MessageCarbonsModule.MC_XMLNS) {
            guard let action = Action(rawValue: carb.name), let forwarded = getEncapsulatedMessage(carb) else {
                error = XMPPError(condition: .bad_request);
                return;
            }

            self.processForwaredMessage(forwarded, action: action);
        }
        if error != nil {
            throw error!;
        }
    }
    
    /**
     Tries to enable/disable message carbons
     */
    open func setState(_ state: Bool) async throws {
        let iq = Iq(type: .set, {
            Element(name: state ? "enable" : "disable", xmlns: MessageCarbonsModule.MC_XMLNS)
        });
        try await write(iq: iq);
    }
    
    /**
     Tries to enable message carbons
     */
    open func enable() async throws {
        try await setState(true);
    }
 
    /**
     Tries to disable message carbons
     */
    open func disable() async throws {
        try await setState(false);
    }

    /**
     Processes received message and retrieves messages forwarded inside this message
     - parameter carb: element to process
     - returns: array of forwarded Messsages
     */
    func getEncapsulatedMessage(_ carb: Element) -> Message? {
        guard let messageEl = carb.firstChild(name: "forwarded", xmlns: MessageCarbonsModule.SF_XMLNS)?.firstChild(name: "message") else {
            return nil;
        }
        return Stanza.from(element: messageEl) as? Message;
    }
    
    func processForwaredMessage(_ forwarded: Message, action: Action) {
        guard let jid = action == .received ? forwarded.from : forwarded.to else {
            return;
        }
        _ = messageModule.processMessage(forwarded, interlocutorJid: jid, fireEvents: false);
        
        carbonsPublisher.send(.init(action: action, jid: jid, message: forwarded));
    }
    
    /**
     Possible actions due to which message carbon was received
     - received: message was received by other resource
     - sent: message was sent by other resource
     */
    public enum Action: String {
        case received
        case sent
    }
    
    public struct CarbonReceived {
        
        public let action: Action;
        public let jid: JID;
        public let message: Message;
        
    }
    
}

// async-await support
extension MessageCarbonsModule {
    
    open func enable(_ callback: ((Result<Bool,XMPPError>) -> Void )? = nil) {
        setState(true, callback: callback);
    }
    
    open func disable(_ callback: ((Result<Bool,XMPPError>) -> Void )? = nil) {
        setState(false, callback: callback);
    }
    
    open func setState(_ state: Bool, callback: ((Result<Bool,XMPPError>) -> Void )?) {
        let actionName = state ? "enable" : "disable";
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.addChild(Element(name: actionName, xmlns: MessageCarbonsModule.MC_XMLNS));
        write(iq: iq, completionHandler: { result in
            callback?(result.map({ _ in state }));
        });
    }
    
}

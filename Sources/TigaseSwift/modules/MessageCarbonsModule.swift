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

extension XmppModuleIdentifier {
    public static var messageCarbons: XmppModuleIdentifier<MessageCarbonsModule> {
        return MessageCarbonsModule.IDENTIFIER;
    }
}

/**
 Module provides support for [XEP-0280: Message Carbons]
 
 [XEP-0280: Message Carbons]: http://xmpp.org/extensions/xep-0280.html
 */
open class MessageCarbonsModule: XmppModule, ContextAware {
    /// Namespace used by Message Carbons
    public static let MC_XMLNS = "urn:xmpp:carbons:2";
    /// Namepsace used for forwarding messages
    fileprivate static let SF_XMLNS = "urn:xmpp:forward:0";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = MC_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<MessageCarbonsModule>();
    
    public let criteria = Criteria.name("message").add(Criteria.xmlns(MC_XMLNS));
    
    public let features = [MC_XMLNS];
    
    open var context: Context! {
        didSet {
            messageModule = context.modulesManager.module(.message);
        }
    }
    
    open var isAvailable: Bool {
        guard let serverFeatures: [String] = context?.module(.disco).serverDiscoResult?.features else {
            return false;
        }
        return serverFeatures.contains(MessageCarbonsModule.MC_XMLNS);
    }
    
    private var messageModule: MessageModule!;
    
    public init() {
        
    }
    
    open func process(stanza message: Stanza) throws {
        var error: ErrorCondition? = nil;
        message.element.forEachChild(xmlns: MessageCarbonsModule.MC_XMLNS) { (carb) in
            let action = Action(rawValue: carb.name);
            guard action != nil else {
                error = ErrorCondition.bad_request;
                return;
            }

            if let forwardedMessages = self.getEncapsulatedMessages(carb) {
                for forwarded in forwardedMessages {
                    self.processForwaredMessage(forwarded, action: action!);
                }
            }
        }
        if error != nil {
            throw error!;
        }
    }
    
    /**
     Tries to enable message carbons
     - parameter callback - called with result
     */
    open func enable(_ callback: ((Result<Bool,ErrorCondition>) -> Void )? = nil) {
        setState(true, callback: callback);
    }
    
    /**
     Tries to disable message carbons
     - parameter callback - called with result
     */
    open func disable(_ callback: ((Result<Bool,ErrorCondition>) -> Void )? = nil) {
        setState(false, callback: callback);
    }
    
    /**
     Tries to enable/disable message carbons
     - parameter callback - called with result
     */
    open func setState(_ state: Bool, callback: ((Result<Bool,ErrorCondition>) -> Void )?) {
        let actionName = state ? "enable" : "disable";
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.addChild(Element(name: actionName, xmlns: MessageCarbonsModule.MC_XMLNS));
        context.writer?.write(iq, callback: {(stanza) -> Void in
            callback?(stanza?.type == StanzaType.result ? .success(state) : .failure(stanza?.errorCondition ?? .remote_server_timeout));
        });
    }
    
    /**
     Processes received message and retrieves messages forwarded inside this message
     - parameter carb: element to process
     - returns: array of forwarded Messsages
     */
    func getEncapsulatedMessages(_ carb: Element) -> [Message]? {
        return carb.findChild(name: "forwarded", xmlns: MessageCarbonsModule.SF_XMLNS)?.mapChildren(transform: { (messageEl) -> Message in
            return Stanza.from(element: messageEl) as! Message;
        }, filter: { (el) -> Bool in
            return el.name == "message";
        });
    }
    
    func processForwaredMessage(_ forwarded: Message, action: Action) {
        let chat = messageModule.processMessage(forwarded, interlocutorJid: action == .received ? forwarded.from : forwarded.to, fireEvents: false);
        context.eventBus.fire(CarbonReceivedEvent(context: context, action: action, message: forwarded, chat: chat));
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
    
    /// Event fired when Message Carbon is received
    open class CarbonReceivedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = CarbonReceivedEvent();
        
        /// Action due to which this carbon was created
        public let action: Action!;
        /// Forwarded message
        public let message: Message!;
        /// Chat for which this forwarded message belongs to
        public let chat: Chat?;
        
        init() {
            self.action = nil;
            self.message = nil;
            self.chat = nil;
            super.init(type: "MessageCarbonReceivedEvent")
        }
        
        init(context: Context, action: Action, message: Message, chat: Chat?) {
            self.action = action;
            self.message = message;
            self.chat = chat;
            super.init(type: "MessageCarbonReceivedEvent", context: context);
        }
    }
    
}

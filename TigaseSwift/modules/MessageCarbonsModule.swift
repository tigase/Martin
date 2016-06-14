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

/**
 Module provides support for [XEP-0280: Message Carbons]
 
 [XEP-0280: Message Carbons]: http://xmpp.org/extensions/xep-0280.html
 */
public class MessageCarbonsModule: XmppModule, ContextAware {
    /// Namespace used by Message Carbons
    public static let MC_XMLNS = "urn:xmpp:carbons:2";
    /// Namepsace used for forwarding messages
    private static let SF_XMLNS = "urn:xmpp:forward:0";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = MC_XMLNS;
    
    public let id = MC_XMLNS;
    
    public let criteria = Criteria.name("message").add(Criteria.xmlns(MC_XMLNS));
    
    public let features = [MC_XMLNS];
    
    public var context: Context!
    
    public init() {
        
    }
    
    public func process(message: Stanza) throws {
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
    public func enable(callback: ((Bool) -> Void )? = nil) {
        setState(true, callback: callback);
    }
    
    /**
     Tries to disable message carbons
     - parameter callback - called with result
     */
    public func disable(callback: ((Bool) -> Void )? = nil) {
        setState(false, callback: callback);
    }
    
    /**
     Tries to enable/disable message carbons
     - parameter callback - called with result
     */
    public func setState(state: Bool, callback: ((Bool) -> Void )?) {
        let actionName = state ? "enable" : "disable";
        var iq = Iq();
        iq.type = StanzaType.set;
        iq.addChild(Element(name: actionName, xmlns: MessageCarbonsModule.MC_XMLNS));
        context.writer?.write(iq, callback: {(stanza) -> Void in
            callback?(stanza?.type == StanzaType.result);
        });
    }
    
    /**
     Processes received message and retrieves messages forwarded inside this message
     - parameter carb: element to process
     - returns: array of forwarded Messsages
     */
    func getEncapsulatedMessages(carb: Element) -> [Message]? {
        return carb.findChild("forwarded", xmlns: MessageCarbonsModule.SF_XMLNS)?.mapChildren({ (messageEl) -> Message in
            return Stanza.fromElement(messageEl) as! Message;
        }, filter: { (el) -> Bool in
            return el.name == "message";
        });
    }
    
    func processForwaredMessage(forwarded: Message, action: Action) {
        if let messageModule: MessageModule = context.modulesManager.getModule(MessageModule.ID) {
            let chat = messageModule.processMessage(forwarded, interlocutorJid: action == .received ? forwarded.from : forwarded.to, fireEvents: false);
            context.eventBus.fire(CarbonReceivedEvent(sessionObject: context.sessionObject, action: action, message: forwarded, chat: chat));
        }
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
    public class CarbonReceivedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = CarbonReceivedEvent();
        
        public let type = "MessageCarbonReceivedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Action due to which this carbon was created
        public let action: Action!;
        /// Forwarded message
        public let message: Message!;
        /// Chat for which this forwarded message belongs to
        public let chat: Chat?;
        
        init() {
            self.sessionObject = nil;
            self.action = nil;
            self.message = nil;
            self.chat = nil;
        }
        
        init(sessionObject: SessionObject, action: Action, message: Message, chat: Chat?) {
            self.sessionObject = sessionObject;
            self.action = action;
            self.message = message;
            self.chat = chat;
        }
    }
    
}
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

public class MessageCarbonsModule: XmppModule, ContextAware {
    
    public static let MC_XMLNS = "urn:xmpp:carbons:2";

    private static let SF_XMLNS = "urn:xmpp:forward:0";
    
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
    
    public func enable(callback: ((Bool) -> Void )? = nil) {
        setState(true, callback: callback);
    }
    
    public func disable(callback: ((Bool) -> Void )? = nil) {
        setState(false, callback: callback);
    }
    
    public func setState(state: Bool, callback: ((Bool) -> Void )?) {
        let actionName = state ? "enable" : "disable";
        var iq = Iq();
        iq.type = StanzaType.set;
        iq.addChild(Element(name: actionName, xmlns: MessageCarbonsModule.MC_XMLNS));
        context.writer?.write(iq, callback: {(stanza) -> Void in
            callback?(stanza?.type == StanzaType.result);
        });
    }
    
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
    
    public enum Action: String {
        case received
        case sent
    }
    
    public class CarbonReceivedEvent: Event {
        
        public static let TYPE = CarbonReceivedEvent();
        
        public let type = "MessageCarbonReceivedEvent";
        
        public let sessionObject: SessionObject!;
        public let action: Action!;
        public let message: Message!;
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
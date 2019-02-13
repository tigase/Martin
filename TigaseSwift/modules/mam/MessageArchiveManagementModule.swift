//
// MessageArchiveManagementModule.swift
//
// TigaseSwift
// Copyright (C) 2017 "Tigase, Inc." <office@tigase.com>
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
 Module provides support for [XEP-0313: Message Archive Management]
 
 [XEP-0313: Message Archive Management]: http://xmpp.org/extensions/xep-0313.html
 */
open class MessageArchiveManagementModule: XmppModule, ContextAware {
    
    fileprivate static let stampFormatter = ({()-> DateFormatter in
        var f = DateFormatter();
        f.locale = Locale(identifier: "en_US_POSIX");
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        f.timeZone = TimeZone(secondsFromGMT: 0);
        return f;
    })();
    // namespace used by XEP-0313
    public static let MAM_XMLNS = "urn:xmpp:mam:1";
    // ID of a module for a lookup in `XmppModulesManager`
    public static let ID = "mam";
    
    public let id = ID;
    
    public let criteria: Criteria = Criteria.name("message").add(Criteria.xmlns(MessageArchiveManagementModule.MAM_XMLNS));
    
    public let features = [String]();
    
    open var context: Context!;
    
    open var isAvailable: Bool {
        if let accountFeatures: [String] = context?.sessionObject.getProperty(DiscoveryModule.ACCOUNT_FEATURES_KEY) {
            if accountFeatures.contains(MessageArchiveManagementModule.MAM_XMLNS) {
                return true;
            }
        }
        
        // TODO: fallback to handle previous behavior - remove it later on...
        if let serverFeatures: [String] = context?.sessionObject.getProperty(DiscoveryModule.SERVER_FEATURES_KEY) {
            return serverFeatures.contains(MessageArchiveManagementModule.MAM_XMLNS);
        }
        return false;
    }
    
    public init() {}
    
    open func process(stanza: Stanza) throws {
        stanza.element.forEachChild(xmlns: MessageArchiveManagementModule.MAM_XMLNS) { (result) in
            guard let messageId = result.getAttribute("id"), let queryId = result.getAttribute("queryid"), let forwardedEl = result.findChild(name: "forwarded", xmlns: "urn:xmpp:forward:0") else {
                return;
            }
            guard let message: Message = forwardedEl.mapChildren(transform: { (el) -> Message in
                return Stanza.from(element: el) as! Message;
            }, filter: { (el)->Bool in
                return el.name == "message";
            }).first, let delayEl = forwardedEl.findChild(name: "delay", xmlns: "urn:xmpp:delay") else {
                return;
            }
            guard let timestamp = Delay(element: delayEl).stamp else {
                return;
            }
            // there is no point in retrieval of chat as it will only open new chat which may not be desired behavior
//            if let messageModule: MessageModule = context.modulesManager.getModule(MessageModule.ID) {
//                var from = message.from;
//                if from == nil || from!.bareJid == context.sessionObject.userBareJid {
//                    from = message.to;
//                }
//                let chat = messageModule.processMessage(message, interlocutorJid: from, fireEvents: false)
//            context.eventBus.fire(ArchivedMessageReceivedEvent(sessionObject: context.sessionObject, queryid: queryId, messageId: messageId, message: message, timestamp: timestamp, chat: chat));
//            }
            context.eventBus.fire(ArchivedMessageReceivedEvent(sessionObject: context.sessionObject, queryid: queryId, messageId: messageId, message: message, timestamp: timestamp, chat: nil));
        }
    }
    
    /**
     Query archived messages
     - parameter componentJid: jid of an archiving component
     - parameter node: PubSub node to query (if querying PubSub component)
     - parameter with: chat participant 
     - parameter start: start date of a querying period
     - parameter end: end date of a querying period
     - parameter queryId: id of a query
     - parameter rsm: instance defining result set Management
     - parameter onSuccess: callback called when query results with a onSuccess
     - parameter onError: callback called when query fails
     */
    open func queryItems(componentJid: JID? = nil, node: String? = nil, with: JID? = nil, start: Date? = nil, end: Date? = nil, queryId: String, rsm: RSM.Query? = nil, onSuccess: @escaping (String,Bool,RSM.Result?)->Void, onError: @escaping (ErrorCondition?, Stanza?)->Void) {
        let query = JabberDataElement(type: .submit);
        let formTypeField = HiddenField(name: "FORM_TYPE");
        formTypeField.value = "urn:xmpp:mam:1";
        query.addField(formTypeField);
        if with != nil {
            let withField = JidSingleField(name: "with");
            withField.value = with;
            query.addField(withField);
        }
        if start != nil {
            let startField = TextSingleField(name: "start");
            startField.value = MessageArchiveManagementModule.stampFormatter.string(from: start!);
            query.addField(startField);
        }
        if end != nil {
            let endField = TextSingleField(name: "end");
            endField.value = MessageArchiveManagementModule.stampFormatter.string(from: end!);
            query.addField(endField);
        }
        queryItems(componentJid: componentJid, node: node, query: query, queryId: queryId, rsm: rsm, onSuccess: onSuccess, onError: onError);
    }
    
    /**
     Query archived messages
     - parameter componentJid: jid of an archiving component
     - parameter node: PubSub node to query (if querying PubSub component)
     - parameter query: instace of `JabberDataElement` with a query form
     - parameter queryId: id of a query
     - parameter rsm: instance defining result set Management
     - parameter onSuccess: callback called when query results with a onSuccess
     - parameter onError: callback called when query fails
     */
    open func queryItems(componentJid: JID? = nil, node: String? = nil, query: JabberDataElement, queryId: String, rsm: RSM.Query? = nil, onSuccess: @escaping (String,Bool,RSM.Result?)->Void, onError: @escaping (ErrorCondition?, Stanza?)->Void) {
        queryItems(componentJid: componentJid, node: node, query: query, queryId: queryId, rsm: rsm) { (stanza: Stanza?) -> Void in
            let type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                guard let fin = stanza?.findChild(name: "fin", xmlns: MessageArchiveManagementModule.MAM_XMLNS) else {
                    onError(ErrorCondition.bad_request, stanza);
                    return;
                }
                onSuccess(queryId, "true" == fin.getAttribute("complete"), RSM.Result(from: fin.findChild(name: "set", xmlns: "http://jabber.org/protocol/rsm")));
            default:
                onError(stanza?.errorCondition, stanza);
            }
        }
    }
    
    /**
     Query archived messages
     - parameter componentJid: jid of an archiving component
     - parameter node: PubSub node to query (if querying PubSub component)
     - parameter query: instace of `JabberDataElement` with a query form
     - parameter queryId: id of a query
     - parameter rsm: instance defining result set Management
     - parameter callback: callback called when response for a query is received
     */
    open func queryItems(componentJid: JID? = nil, node: String? = nil, query: JabberDataElement, queryId: String, rsm: RSM.Query? = nil, callback: ((Stanza?)->Void)?)
    {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = componentJid;
        
        let queryEl = Element(name: "query", xmlns: MessageArchiveManagementModule.MAM_XMLNS);
        iq.addChild(queryEl);
        
        queryEl.setAttribute("queryid", value: queryId);
        queryEl.setAttribute("node", value: node);
        
        queryEl.addChild(query.submitableElement(type: .submit));
        
        if (rsm != nil) {
            queryEl.addChild(rsm!.element);
        }
        
        context.writer?.write(iq, callback: callback);
    }
    
    /**
     Retrieve query form a for querying archvived messages
     - parameter componentJid: jid of an archiving component
     - parameter onSuccess: called when form was sucessfully retrieved
     - parameter onError: called if there was an error during form retrieval
     */
    open func retrieveForm(componentJid: JID? = nil, onSuccess: @escaping (JabberDataElement?)->Void, onError: @escaping (ErrorCondition?,Stanza?)->Void) {
        retieveForm(componentJid: componentJid) { (stanza: Stanza?) in
            let type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                guard let query = stanza?.findChild(name: "query", xmlns: MessageArchiveManagementModule.MAM_XMLNS) else {
                    onError(ErrorCondition.bad_request, stanza);
                    return;
                }
                guard let x = query.findChild(name: "x", xmlns: "jabber:x:data") else {
                    onError(ErrorCondition.bad_request, stanza);
                    return;
                }
                onSuccess(JabberDataElement(from: x));
            default:
                onError(stanza?.errorCondition, stanza);
            }
        }
    }
    
    /**
     Retrieve query form a for querying archvived messages
     - parameter componentJid: jid of an archiving component
     - parameter callback: called when response for a query is received
     */
    open func retieveForm(componentJid: JID? = nil, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = componentJid;
        
        let queryEl = Element(name: "query", xmlns: MessageArchiveManagementModule.MAM_XMLNS);
        iq.addChild(queryEl);
     
        context.writer?.write(iq, callback: callback);
    }
    
    /**
     Retrieve message archiving settings
     - parameter onSuccess: called when settings were retrieved
     - parameter onError: called when settings retrieval failed
     */
    open func retrieveSettings(onSuccess: @escaping (DefaultValue,[JID],[JID])->Void, onError: @escaping (ErrorCondition?,Stanza?)->Void) {
        retrieveSettings(callback: prepareSettingsCallback(onSuccess: onSuccess, onError: onError));
    }
    
    /**
     Retrieve message archiving settings
     - parameter callback: called when response is received
     */
    open func retrieveSettings(callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.addChild(Element(name: "prefs", xmlns: MessageArchiveManagementModule.MAM_XMLNS));
        
        context.writer?.write(iq, callback: callback);
    }
    
    /**
     - parameter defaultValue: default value for archiving messages
     - parameter always: list of jids for which messages should be always archived
     - parameter never: list of jids for which messages should not be archived
     - parameter onSuccess: called when change was sucessful
     - parameter onError: called when error occurred
     */
    open func updateSettings(defaultValue: DefaultValue, always: [JID], never: [JID], onSuccess: @escaping (DefaultValue, [JID], [JID])->Void, onError: @escaping (ErrorCondition?,Stanza?)->Void) {
        updateSettings(defaultValue: defaultValue, always: always, never: never, callback: prepareSettingsCallback(onSuccess: onSuccess, onError: onError));
    }
    
    /**
     - parameter defaultValue: default value for archiving messages
     - parameter always: list of jids for which messages should be always archived
     - parameter never: list of jids for which messages should not be archived
     - parameter callback: called when response is received
     */
    open func updateSettings(defaultValue: DefaultValue, always: [JID], never: [JID], callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.set;
        let prefs = Element(name: "prefs", xmlns: MessageArchiveManagementModule.MAM_XMLNS);
        prefs.setAttribute("default", value: defaultValue.rawValue);
        iq.addChild(prefs);
        if !always.isEmpty {
            let alwaysEl = Element(name: "always");
            alwaysEl.addChildren(always.map({ (jid) -> Element in Element(name: "jid", cdata: jid.stringValue) }));
            prefs.addChild(alwaysEl);
        }
        if !never.isEmpty {
            let neverEl = Element(name: "always");
            neverEl.addChildren(never.map({ (jid) -> Element in Element(name: "jid", cdata: jid.stringValue) }));
            prefs.addChild(neverEl);
        }
        
        context.writer?.write(iq, callback: callback);
    }
    
    fileprivate func prepareSettingsCallback(onSuccess: @escaping (DefaultValue,[JID],[JID])->Void, onError: @escaping (ErrorCondition?,Stanza?)->Void) -> ((Stanza?)->Void)? {
        return  { (stanza: Stanza?)->Void in
            let type = stanza?.type ?? StanzaType.error;
            if (type == .result) {
                if let prefs = stanza?.findChild(name: "prefs", xmlns: MessageArchiveManagementModule.MAM_XMLNS) {
                    let defValue = DefaultValue(rawValue: prefs.getAttribute("default") ?? "always") ?? DefaultValue.always;
                    let always: [JID] = prefs.findChild(name: "always")?.mapChildren(transform: { (elem)->JID? in
                        return JID(elem.value);
                    }) ?? [JID]();
                    let never: [JID] = prefs.findChild(name: "always")?.mapChildren(transform: { (elem)->JID? in
                        return JID(elem.value);
                    }) ?? [JID]();
                    onSuccess(defValue, always, never);
                    return;
                }
                onError(ErrorCondition.bad_request, stanza);
            } else {
                onError(stanza?.errorCondition, stanza);
            }
        };
    }
    
    fileprivate func mapElemValueToJid(elem: Element) -> JID? {
        return JID(elem.value);
    }
    
    /// Enum defines possible values for default archiving of messages
    public enum DefaultValue: String {
        /// All messages should be archive
        case always
        /// Only messages from jids in the roster should be archived
        case roster
        /// Messages should not be archived
        case never
    }
    
    /// Event fired when message from archive is retrieved
    open class ArchivedMessageReceivedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ArchivedMessageReceivedEvent();
        
        public let type = "ArchivedMessageReceivedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Timestamp of a message
        public let timestamp: Date!;
        /// Forwarded message
        public let message: Message!;
        /// Message ID
        public let messageId: String!;
        /// Chat for which this forwarded message belongs to
        public let chat: Chat?;
        
        init() {
            self.sessionObject = nil;
            self.timestamp = nil;
            self.message = nil;
            self.messageId = nil;
            self.chat = nil;
        }
        
        init(sessionObject: SessionObject, queryid: String, messageId: String, message: Message, timestamp: Date, chat: Chat?) {
            self.sessionObject = sessionObject;
            self.message = message;
            self.messageId = messageId;
            self.timestamp = timestamp;
            self.chat = chat;
        }
    }
}

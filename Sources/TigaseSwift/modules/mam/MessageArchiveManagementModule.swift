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

extension XmppModuleIdentifier {
    public static var mam: XmppModuleIdentifier<MessageArchiveManagementModule> {
        return MessageArchiveManagementModule.IDENTIFIER;
    }
}

/**
 Module provides support for [XEP-0313: Message Archive Management]
 
 [XEP-0313: Message Archive Management]: http://xmpp.org/extensions/xep-0313.html
 */
open class MessageArchiveManagementModule: XmppModule, ContextAware, EventHandler {
    
    // namespace used by XEP-0313
    public static let MAM_XMLNS = "urn:xmpp:mam:1";
    public static let MAM2_XMLNS = "urn:xmpp:mam:2";
    // ID of a module for a lookup in `XmppModulesManager`
    public static let IDENTIFIER = XmppModuleIdentifier<MessageArchiveManagementModule>();
    public static let ID = "mam";
        
    public let criteria: Criteria = Criteria.name("message").add(Criteria.or(Criteria.xmlns(MessageArchiveManagementModule.MAM_XMLNS), Criteria.xmlns(MessageArchiveManagementModule.MAM2_XMLNS)));
    
    public let features = [String]();

    private let dispatcher = QueueDispatcher(label: "MAMQueries");
    private var queries: [String: Query] = [:];
    
    open var context: Context! {
        didSet {
            oldValue?.eventBus.unregister(handler: self, for: SocketConnector.DisconnectedEvent.TYPE);
            context?.eventBus.register(handler: self, for: SocketConnector.DisconnectedEvent.TYPE);
        }
    }
    
    open var isAvailable: Bool {
        return availableVersion != nil;
    }
    
    open var availableVersion: Version? {
        if let accountFeatures: [String] = context?.module(.disco).accountDiscoResult?.features {
            return Version.values.first(where: { version in accountFeatures.contains(version.rawValue) });
        }
        if let serverFeatures: [String] = context?.module(.disco).serverDiscoResult?.features {
            return Version.values.first(where: { version in serverFeatures.contains(version.rawValue) });
        }
        return nil;
    }
    
    public init() {}
    
    open func handle(event: Event) {
        switch event {
        case is SocketConnector.DisconnectedEvent:
            // invalidate all existing queries..
            self.dispatcher.async {
                self.queries.removeAll();
            }
        default:
            break;
        }
    }
    
    open func process(stanza: Stanza) throws {
        stanza.element.forEachChild(fn: { (result) in
            guard Version.isSupported(xmlns: result.xmlns) else {
                return;
            }
            guard let messageId = result.getAttribute("id"), let queryId = result.getAttribute("queryid"), let forwardedEl = result.findChild(name: "forwarded", xmlns: "urn:xmpp:forward:0"), let query = dispatcher.sync(execute: { return self.queries[queryId]; }) else {
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
            
            if message.to == nil {
                // some services, ie. MIX may not set "to" attribute. In this case it would be reasonable to assume that "we" received this messages
                message.to = stanza.to;
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
            context.eventBus.fire(ArchivedMessageReceivedEvent(sessionObject: context.sessionObject, queryid: queryId, version: query.version, messageId: messageId, source: stanza.from?.bareJid ?? context.userBareJid, message: message, timestamp: timestamp));
        });
    }
    
    public enum QueryResult {
        case success(queryId: String, complete: Bool, rsm: RSM.Result?)
        case failure(errorCondition: ErrorCondition, response: Stanza?)
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
     - parameter completionHandler: callback called when query results
     */
    open func queryItems(version: Version? = nil, componentJid: JID? = nil, node: String? = nil, with: JID? = nil, start: Date? = nil, end: Date? = nil, queryId: String, rsm: RSM.Query? = nil, completionHandler: @escaping (QueryResult)->Void) {
        guard let version = version ?? self.availableVersion else {
            completionHandler(.failure(errorCondition: .feature_not_implemented, response: nil));
            return;
        }
        
        let query = JabberDataElement(type: .submit);
        let formTypeField = HiddenField(name: "FORM_TYPE");
        formTypeField.value = version.rawValue;
        query.addField(formTypeField);
        if with != nil {
            let withField = JidSingleField(name: "with");
            withField.value = with;
            query.addField(withField);
        }
        if start != nil {
            let startField = TextSingleField(name: "start");
            startField.value = TimestampHelper.format(date: start!);
            query.addField(startField);
        }
        if end != nil {
            let endField = TextSingleField(name: "end");
            endField.value = TimestampHelper.format(date: end!);
            query.addField(endField);
        }

        self.queryItems(version: version, componentJid: componentJid, node: node, query: query, queryId: queryId, rsm: rsm, completionHandler: completionHandler);
    }
    
    /**
     Query archived messages
     - parameter componentJid: jid of an archiving component
     - parameter node: PubSub node to query (if querying PubSub component)
     - parameter query: instace of `JabberDataElement` with a query form
     - parameter queryId: id of a query
     - parameter rsm: instance defining result set Management
     - parameter completionHandler: callback called when query results
     */
    open func queryItems(version: Version? = nil,componentJid: JID? = nil, node: String? = nil, query: JabberDataElement, queryId: String, rsm: RSM.Query? = nil, completionHandler: @escaping (QueryResult)->Void)
    {
        guard let version = version ?? self.availableVersion else {
            completionHandler(.failure(errorCondition: .feature_not_implemented, response: nil))
            return;
        }

        self.dispatcher.async {
            self.queries[queryId] = Query(id: queryId, version: version);
        }
        
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = componentJid;
        
        let queryEl = Element(name: "query", xmlns: version.rawValue);
        iq.addChild(queryEl);
        
        queryEl.setAttribute("queryid", value: queryId);
        queryEl.setAttribute("node", value: node);
        
        queryEl.addChild(query.submitableElement(type: .submit));
        
        if (rsm != nil) {
            queryEl.addChild(rsm!.element);
        }
        
        context.writer?.write(iq, completionHandler: { (result: AsyncResult<Stanza>) in
            self.dispatcher.asyncAfter(deadline: DispatchTime.now() + 60.0, execute: {
                self.queries.removeValue(forKey: queryId);
            });
            switch result {
            case .success(let response):
                guard let fin = response.findChild(name: "fin", xmlns: version.rawValue) else {
                    completionHandler(.failure(errorCondition: .bad_request, response: response));
                    return;
                }
                
                let rsmResult = RSM.Result(from: fin.findChild(name: "set", xmlns: "http://jabber.org/protocol/rsm"));
                let complete = ("true" == fin.getAttribute("complete")) || ((rsmResult?.count ?? 0) == 0);
                completionHandler(.success(queryId: queryId, complete: complete, rsm: rsmResult));
            case .failure(let errorCondition, let response):
                completionHandler(.failure(errorCondition: errorCondition, response: response));
            }
        });
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
    open func queryItems(version: Version = Version.MAM1, componentJid: JID? = nil, node: String? = nil, query: JabberDataElement, queryId: String, rsm: RSM.Query? = nil, callback: ((Stanza?)->Void)?)
    {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = componentJid;
        
        let queryEl = Element(name: "query", xmlns: version.rawValue);
        iq.addChild(queryEl);
        
        queryEl.setAttribute("queryid", value: queryId);
        queryEl.setAttribute("node", value: node);
        
        queryEl.addChild(query.submitableElement(type: .submit));
        
        if (rsm != nil) {
            queryEl.addChild(rsm!.element);
        }
        
        context.writer?.write(iq, callback: callback);
    }
    
    public enum RetrieveFormResult {
        case success(form: JabberDataElement)
        case failure(errorCondition: ErrorCondition, response: Stanza?)
    }
    /**
     Retrieve query form a for querying archvived messages
     - parameter componentJid: jid of an archiving component
     - parameter completionHandler: called with result
     */
    open func retrieveForm(version: Version? = nil, componentJid: JID? = nil, completionHandler: @escaping (RetrieveFormResult)->Void) {
        guard let version = version ?? availableVersion else {
            completionHandler(.failure(errorCondition: .feature_not_implemented, response: nil));
            return;
        }
        retieveForm(version: version, componentJid: componentJid) { (stanza: Stanza?) in
            if let stanza = stanza {
                if stanza.type == .result, let query = stanza.findChild(name: "query", xmlns: version.rawValue), let x = query.findChild(name: "x", xmlns: "jabber:x:data"), let form = JabberDataElement(from: x) {
                    completionHandler(.success(form: form));
                } else {
                    completionHandler(.failure(errorCondition: stanza.errorCondition ?? .undefined_condition, response: stanza));
                }
            } else {
                completionHandler(.failure(errorCondition: .remote_server_timeout, response: nil));
            }
        }
    }
    
    /**
     Retrieve query form a for querying archvived messages
     - parameter componentJid: jid of an archiving component
     - parameter callback: called when response for a query is received
     */
    open func retieveForm(version: Version = Version.MAM1, componentJid: JID? = nil, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = componentJid;
        
        let queryEl = Element(name: "query", xmlns: version.rawValue);
        iq.addChild(queryEl);
     
        context.writer?.write(iq, callback: callback);
    }
    
    public enum SettingsResult {
        case success(defValue: DefaultValue, always: [JID], never: [JID])
        case failure(errorCondition: ErrorCondition, response: Stanza?)
    }
    
    /**
     Retrieve message archiving settings
     - parameter completionHandler: called with result
     */
    open func retrieveSettings(version: Version? = nil, completionHandler: @escaping (SettingsResult)->Void) {
        guard let version = version ?? availableVersion else {
            completionHandler(.failure(errorCondition: .feature_not_implemented, response: nil));
            return;
        }
        retrieveSettings(version: version, callback: prepareSettingsCallback(version: version, completionHandler: completionHandler));
    }
    
    /**
     Retrieve message archiving settings
     - parameter callback: called when response is received
     */
    open func retrieveSettings(version: Version = Version.MAM1, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.addChild(Element(name: "prefs", xmlns: version.rawValue));
        
        context.writer?.write(iq, callback: callback);
    }
    
    /**
     - parameter defaultValue: default value for archiving messages
     - parameter always: list of jids for which messages should be always archived
     - parameter never: list of jids for which messages should not be archived
     - parameter completionHandler: called with result
     */
    open func updateSettings(version: Version? = nil, defaultValue: DefaultValue, always: [JID], never: [JID], completionHandler: @escaping (SettingsResult)->Void) {
        guard let version = version ?? availableVersion else {
            completionHandler(.failure(errorCondition: .feature_not_implemented, response: nil));
            return;
        }
        updateSettings(version: version, defaultValue: defaultValue, always: always, never: never, callback: prepareSettingsCallback(version: version, completionHandler: completionHandler));
    }
    
    /**
     - parameter defaultValue: default value for archiving messages
     - parameter always: list of jids for which messages should be always archived
     - parameter never: list of jids for which messages should not be archived
     - parameter callback: called when response is received
     */
    open func updateSettings(version: Version = Version.MAM1, defaultValue: DefaultValue, always: [JID], never: [JID], callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.set;
        let prefs = Element(name: "prefs", xmlns: version.rawValue);
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
    
    fileprivate func prepareSettingsCallback(version: Version, completionHandler: @escaping (SettingsResult)->Void) -> ((Stanza?)->Void)? {
        return  { (stanza: Stanza?)->Void in
            let type = stanza?.type ?? StanzaType.error;
            if (type == .result) {
                if let prefs = stanza?.findChild(name: "prefs", xmlns: version.rawValue) {
                    let defValue = DefaultValue(rawValue: prefs.getAttribute("default") ?? "always") ?? DefaultValue.always;
                    let always: [JID] = prefs.findChild(name: "always")?.mapChildren(transform: { (elem)->JID? in
                        return JID(elem.value);
                    }) ?? [JID]();
                    let never: [JID] = prefs.findChild(name: "always")?.mapChildren(transform: { (elem)->JID? in
                        return JID(elem.value);
                    }) ?? [JID]();
                    completionHandler(.success(defValue: defValue, always: always, never: never));
                    return;
                }
                completionHandler(.failure(errorCondition: .bad_request, response: stanza));
            } else {
                completionHandler(.failure(errorCondition: stanza?.errorCondition ?? .remote_server_timeout, response: stanza));
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
        /// Version of MAM request
        public let version: Version!;
        /// JID of the archive
        public let source: BareJID!;
        /// Message ID
        public let messageId: String!;
        
        init() {
            self.sessionObject = nil;
            self.timestamp = nil;
            self.message = nil;
            self.version = nil;
            self.source = nil;
            self.messageId = nil;
        }
        
        init(sessionObject: SessionObject, queryid: String, version: Version, messageId: String, source: BareJID, message: Message, timestamp: Date) {
            self.sessionObject = sessionObject;
            self.message = message;
            self.version = version;
            self.messageId = messageId;
            self.source = source;
            self.timestamp = timestamp;
        }
    }
    
    public enum Version: String {
        case MAM1 = "urn:xmpp:mam:1"
        case MAM2 = "urn:xmpp:mam:2"
        
        public static let values = [MAM2, MAM1];
        
        public static func isSupported(xmlns: String?) -> Bool {
            guard let xmlns = xmlns else {
                return false;
            }
            return Version.values.contains(where: { $0.rawValue == xmlns });
        }
    }
    
    private class Query {
        let id: String;
        let version: Version;
        private(set) var endedAt: Date?;
            
        init(id: String, version: Version) {
            self.id = id;
            self.version = version;
        }
        
        func ended(at date: Date) {
            self.endedAt = date;
        }
        
    }
}

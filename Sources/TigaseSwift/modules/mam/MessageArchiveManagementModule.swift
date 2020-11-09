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
            context.eventBus.fire(ArchivedMessageReceivedEvent(context: context, queryid: queryId, version: query.version, messageId: messageId, source: stanza.from?.bareJid ?? context.userBareJid, message: message, timestamp: timestamp));
        });
    }
        
    public struct QueryResult {
        public let queryId: String;
        public let complete: Bool;
        public let rsm: RSM.Result?;
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
    open func queryItems(version: Version? = nil, componentJid: JID? = nil, node: String? = nil, with: JID? = nil, start: Date? = nil, end: Date? = nil, queryId: String, rsm: RSM.Query? = nil, completionHandler: @escaping (Result<QueryResult,XMPPError>)->Void) {
        guard let version = version ?? self.availableVersion else {
            completionHandler(.failure(.feature_not_implemented));
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
    open func queryItems(version: Version? = nil, componentJid: JID? = nil, node: String? = nil, query: JabberDataElement, queryId: String, rsm: RSM.Query? = nil, completionHandler: @escaping (Result<QueryResult,XMPPError>)->Void)
    {
        guard let version = version ?? self.availableVersion else {
            completionHandler(.failure(.feature_not_implemented))
            return;
        }

        queryItems(version: version, componentJid: componentJid, node: node, query: query, queryId: queryId, rsm: rsm, errorDecoder: XMPPError.from(stanza:), completionHandler: { result in
            completionHandler(result.flatMap { response in
                guard let fin = response.findChild(name: "fin", xmlns: version.rawValue) else {
                    return .failure(.undefined_condition);
                }
                
                let rsmResult = RSM.Result(from: fin.findChild(name: "set", xmlns: "http://jabber.org/protocol/rsm"));
                let complete = ("true" == fin.getAttribute("complete")) || ((rsmResult?.count ?? 0) == 0);
                return .success(QueryResult(queryId: queryId, complete: complete, rsm: rsmResult));
            })
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
    open func queryItems<Failure: Error>(version: Version, componentJid: JID? = nil, node: String? = nil, query: JabberDataElement, queryId: String, rsm: RSM.Query? = nil, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void)
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
        
        self.dispatcher.async {
            self.queries[queryId] = Query(id: queryId, version: version);
        }

        context.writer?.write(iq, errorDecoder: errorDecoder, completionHandler: { (result: Result<Iq, Failure>) in
            self.dispatcher.asyncAfter(deadline: DispatchTime.now() + 60.0, execute: {
                self.queries.removeValue(forKey: queryId);
            });
            completionHandler(result);
        });
    }
    
    /**
     Retrieve query form a for querying archvived messages
     - parameter componentJid: jid of an archiving component
     - parameter completionHandler: called with result
     */
    open func retrieveForm(version: Version? = nil, componentJid: JID? = nil, completionHandler: @escaping (Result<JabberDataElement,XMPPError>)->Void) {
        guard let version = version ?? availableVersion else {
            completionHandler(.failure(.feature_not_implemented));
            return;
        }
        retieveForm(version: version, componentJid: componentJid, errorDecoder: XMPPError.from(stanza: ), completionHandler: { result in
            completionHandler(result.flatMap { stanza in
                guard let query = stanza.findChild(name: "query", xmlns: version.rawValue), let x = query.findChild(name: "x", xmlns: "jabber:x:data"), let form = JabberDataElement(from: x) else {
                    return .failure(.undefined_condition);
                }
                return .success(form);
            })
        });
    }
    
    /**
     Retrieve query form a for querying archvived messages
     - parameter componentJid: jid of an archiving component
     - parameter callback: called when response for a query is received
     */
    open func retieveForm<Failure: Error>(version: Version, componentJid: JID? = nil, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = componentJid;
        
        let queryEl = Element(name: "query", xmlns: version.rawValue);
        iq.addChild(queryEl);
     
        context.writer?.write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    public struct Settings {
        public var defaultValue: DefaultValue;
        public var always: [JID];
        public var never: [JID];
        
        public init(defaultValue: DefaultValue, always: [JID], never: [JID]) {
            self.defaultValue = defaultValue;
            self.always = always;
            self.never = never;
        }
    }
    
    /**
     Retrieve message archiving settings
     - parameter completionHandler: called with result
     */
    open func retrieveSettings(version: Version? = nil, completionHandler: @escaping (Result<Settings,XMPPError>)->Void) {
        guard let version = version ?? availableVersion else {
            completionHandler(.failure(.feature_not_implemented));
            return;
        }
        retrieveSettings(version: version, errorDecoder: XMPPError.from(stanza:), completionHandler: { result in
            completionHandler(result.flatMap({ stanza in MessageArchiveManagementModule.parseSettings(fromIq: stanza, version: version) }));
        });
    }
    
    /**
     Retrieve message archiving settings
     - parameter callback: called when response is received
     */
    open func retrieveSettings<Failure: Error>(version: Version, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.addChild(Element(name: "prefs", xmlns: version.rawValue));
        
        context.writer?.write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    /**
     - parameter settings: settings to set on the server
     - parameter completionHandler: called with result
     */
    open func updateSettings(version: Version? = nil, settings: Settings, completionHandler: @escaping (Result<Settings,XMPPError>)->Void) {
        guard let version = version ?? availableVersion else {
            completionHandler(.failure(.feature_not_implemented));
            return;
        }
        updateSettings(version: version, settings: settings, errorDecoder: XMPPError.from(stanza:), completionHandler: { result in
            completionHandler(result.flatMap({ stanza in MessageArchiveManagementModule.parseSettings(fromIq: stanza, version: version) }));
        });
    }
    
    /**
     - parameter settings: settings to set on the server
     - parameter callback: called when response is received
     */
    open func updateSettings<Failure: Error>(version: Version, settings: Settings, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        let prefs = Element(name: "prefs", xmlns: version.rawValue);
        prefs.setAttribute("default", value: settings.defaultValue.rawValue);
        iq.addChild(prefs);
        if !settings.always.isEmpty {
            let alwaysEl = Element(name: "always");
            alwaysEl.addChildren(settings.always.map({ (jid) -> Element in Element(name: "jid", cdata: jid.stringValue) }));
            prefs.addChild(alwaysEl);
        }
        if !settings.never.isEmpty {
            let neverEl = Element(name: "always");
            neverEl.addChildren(settings.never.map({ (jid) -> Element in Element(name: "jid", cdata: jid.stringValue) }));
            prefs.addChild(neverEl);
        }
        
        context.writer?.write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    private static func parseSettings(fromIq stanza: Iq, version: Version) -> Result<Settings,XMPPError> {
        if let prefs = stanza.findChild(name: "prefs", xmlns: version.rawValue) {
            let defValue = DefaultValue(rawValue: prefs.getAttribute("default") ?? "always") ?? DefaultValue.always;
            let always: [JID] = prefs.findChild(name: "always")?.mapChildren(transform: { (elem)->JID? in
                return JID(elem.value);
            }) ?? [JID]();
            let never: [JID] = prefs.findChild(name: "always")?.mapChildren(transform: { (elem)->JID? in
                return JID(elem.value);
            }) ?? [JID]();
            return .success(Settings(defaultValue: defValue, always: always, never: never));
        } else {
            return .failure(.from(stanza: stanza));
        }
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
    open class ArchivedMessageReceivedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ArchivedMessageReceivedEvent();
        
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
            self.timestamp = nil;
            self.message = nil;
            self.version = nil;
            self.source = nil;
            self.messageId = nil;
            super.init(type: "ArchivedMessageReceivedEvent");
        }
        
        init(context: Context, queryid: String, version: Version, messageId: String, source: BareJID, message: Message, timestamp: Date) {
            self.message = message;
            self.version = version;
            self.messageId = messageId;
            self.source = source;
            self.timestamp = timestamp;
            super.init(type: "ArchivedMessageReceivedEvent", context: context);
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

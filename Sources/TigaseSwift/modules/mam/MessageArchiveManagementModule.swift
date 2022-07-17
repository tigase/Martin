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
import Combine

extension XmppModuleIdentifier {
    public static var mam: XmppModuleIdentifier<MessageArchiveManagementModule> {
        return MessageArchiveManagementModule.IDENTIFIER;
    }
}

/**
 Module provides support for [XEP-0313: Message Archive Management]
 
 [XEP-0313: Message Archive Management]: http://xmpp.org/extensions/xep-0313.html
 */
open class MessageArchiveManagementModule: XmppModuleBase, XmppModule, Resetable {
    
    // namespace used by XEP-0313
    public static let MAM_XMLNS = "urn:xmpp:mam:1";
    public static let MAM2_XMLNS = "urn:xmpp:mam:2";
    // ID of a module for a lookup in `XmppModulesManager`
    public static let IDENTIFIER = XmppModuleIdentifier<MessageArchiveManagementModule>();
    public static let ID = "mam";
        
    public let criteria: Criteria = Criteria.name("message").add(Criteria.or(Criteria.xmlns(MessageArchiveManagementModule.MAM_XMLNS), Criteria.xmlns(MessageArchiveManagementModule.MAM2_XMLNS)));
    
    public let features = [String]();

    private let queue = DispatchQueue(label: "MAMQueries");
    private var queries: [String: Query] = [:];
        
    open var isAvailable: Bool {
        return !availableVersions.isEmpty;
    }
    
    open override var context: Context? {
        didSet {
            context?.module(.disco).$accountDiscoResult.sink(receiveValue: { [weak self] result in
                self?.availableVersions = Version.values.filter({ result.features.contains($0.rawValue) }).sorted(by: { $0.rawValue > $1.rawValue });
            }).store(in: self);
        }
    }
    
    @Published
    open var availableVersions: [Version] = [];
        
    public let archivedMessagesPublisher = PassthroughSubject<ArchivedMessageReceived, Never>();
    
    public override init() {}
    
    open func reset(scopes: Set<ResetableScope>) {
        self.queue.async {
            self.queries.removeAll();
        }
    }
        
    open func process(stanza: Stanza) throws {
        for result in stanza.element.children {
            guard Version.isSupported(xmlns: result.xmlns) else {
                return;
            }
            guard let messageId = result.attribute("id"), let queryId = result.attribute("queryid"), let forwardedEl = result.firstChild(name: "forwarded", xmlns: "urn:xmpp:forward:0"), let query = queue.sync(execute: { return self.queries[queryId]; }) else {
                return;
            }
            guard let messageEl = forwardedEl.firstChild(name: "message"), let message = Stanza.from(element: messageEl) as? Message, let delayEl = forwardedEl.firstChild(name: "delay", xmlns: "urn:xmpp:delay") else {
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
            if let context = context {
                archivedMessagesPublisher.send(.init(messageId: messageId, source: stanza.from?.bareJid ?? context.userBareJid, query: query, timestamp: timestamp, message: message));
            }
        }
    }
        
    public struct QueryResult {
        public let queryId: String;
        public let complete: Bool;
        public let rsm: RSM.Result?;
    }

    /**
     Query archived messages
     - parameter query: instace of `JabberDataElement` with a query form
     - parameter at componentJid: jid of an archiving component
     - parameter node: PubSub node to query (if querying PubSub component)
     - parameter queryId: id of a query
     - parameter rsm: instance defining result set Management
     */
    open func queryItems(_ query: MAMQueryForm, at componentJid: JID? = nil, node: String? = nil, queryId: String, rsm: RSM.Query? = nil) async throws -> QueryResult {
        
        guard let version = availableVersions.first(where: { $0.rawValue == query.FORM_TYPE }) else {
            throw XMPPError(condition: .feature_not_implemented);
        }
        
        let iq = Iq(type: .set, to: componentJid, {
            Element(name: "query", xmlns: version.rawValue, {
                Attribute("queryid", value: queryId)
                Attribute("node", value: node)
                query.element(type: .submit, onlyModified: false)
                rsm?.element()
            });
        });
        
        self.queue.async {
            self.queries[queryId] = Query(id: queryId, version: version);
        }

        do {
            let response = try await write(iq: iq);
            guard let fin = response.firstChild(name: "fin", xmlns: version.rawValue) else {
                throw XMPPError(condition: .undefined_condition, stanza: response);
            }
            
            let rsmResult = RSM.Result(from: fin.firstChild(name: "set", xmlns: "http://jabber.org/protocol/rsm"));

            let complete = ("true" == fin.attribute("complete")) || MessageArchiveManagementModule.isComplete(rsm: rsmResult);
            self.queue.asyncAfter(deadline: .now() + 10.0) {
                self.queries.removeValue(forKey: queryId);
            }
            return QueryResult(queryId: queryId, complete: complete, rsm: rsmResult);
        } catch {
            self.queue.async {
                self.queries.removeValue(forKey: queryId);
            }
            throw error;
        }
    }
    
    static func isComplete(rsm result: RSM.Result?) -> Bool {
        guard let rsm = result else {
            // no RSM, so we have ended
            return true;
        }
        
        if let count = rsm.count {
            return count == 0;
        }
        
        if let first = rsm.first, let last = rsm.last {
            return first == last;
        }
        
        return rsm.first == nil && rsm.last == nil;
    }

    /**
     Retrieve query form a for querying archvived messages
     - parameter from componentJid: jid of an archiving component
     */
    open func retrieveForm(version: Version? = nil, from componentJid: JID? = nil) async throws -> MAMQueryForm {
        guard let version = version ?? availableVersions.first else {
            throw XMPPError(condition: .feature_not_implemented);
        }
        let iq = Iq(type: .get, to: componentJid, {
            Element(name: "query", xmlns: version.rawValue)
        });
        
        let response = try await write(iq: iq);
        guard let query = response.firstChild(name: "query", xmlns: version.rawValue), let x = query.firstChild(name: "x", xmlns: "jabber:x:data"), let form = DataForm(element: x) else {
            throw XMPPError(condition: .undefined_condition, stanza: response);
        }
        return MAMQueryForm(form: form);
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
     - parameter version: version of specification to use
     */
    open func settings(version: Version? = nil) async throws -> Settings {
        guard let version = version ?? availableVersions.first else {
           throw XMPPError(condition: .feature_not_implemented);
        }
        
        let iq = Iq(type: .get, {
            Element(name: "prefs", xmlns: version.rawValue)
        })
        
        let response = try await write(iq: iq);
        return try MessageArchiveManagementModule.parseSettings(fromIq: response, version: version);
    }
    
    /**
     - parameter version: version of specification to use
     - parameter settings: settings to set on the server
     */
    open func settings(_ settings: Settings, version: Version? = nil) async throws -> Settings {
        guard let version = version ?? availableVersions.first else {
           throw XMPPError(condition: .feature_not_implemented);
        }
        
        let iq = Iq(type: .set, {
            Element(name: "prefs", xmlns: version.rawValue, {
                Attribute("default", value: settings.defaultValue.rawValue)
                if !settings.always.isEmpty {
                    Element(name: "always", {
                        for jid in settings.always {
                            Element(name: "jid", cdata: jid.description)
                        }
                    })
                }
                if !settings.never.isEmpty {
                    Element(name: "never", {
                        for jid in settings.never {
                            Element(name: "jid", cdata: jid.description)
                        }
                    })
                }
            })
        })

        let response = try await write(iq: iq);
        return try MessageArchiveManagementModule.parseSettings(fromIq: response, version: version);
    }
    
    private static func parseSettings(fromIq stanza: Iq, version: Version) throws -> Settings {
        if let prefs = stanza.firstChild(name: "prefs", xmlns: version.rawValue) {
            let defValue = DefaultValue(rawValue: prefs.attribute("default") ?? "always") ?? DefaultValue.always;
            let always: [JID] = prefs.firstChild(name: "always")?.compactMapChildren({ JID($0.value) }) ?? [];
            let never: [JID] = prefs.firstChild(name: "always")?.compactMapChildren({ JID($0.value) }) ?? [];
            return Settings(defaultValue: defValue, always: always, never: never);
        } else {
            throw XMPPError(condition: .undefined_condition, stanza: stanza);
        }
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
    
    public struct ArchivedMessageReceived {
        public let messageId: String;
        public let source: BareJID;
        public let query: Query;
        public let timestamp: Date;
        public let message: Message;
    }
    
    public class Query {
        public let id: String;
        public let version: Version;
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

// async-await support
extension MessageArchiveManagementModule {
    
    @available(*, deprecated, message: "use queryItems(componentJid:node:query:queryId:rsm:completionHandler:)")
    open func queryItems(version: Version? = nil, componentJid: JID? = nil, node: String? = nil, with: JID? = nil, start: Date? = nil, end: Date? = nil, queryId: String, rsm: RSM.Query? = nil, completionHandler: @escaping (Result<QueryResult,XMPPError>)->Void) {
        guard let version = version ?? availableVersions.first else {
            completionHandler(.failure(XMPPError(condition: .feature_not_implemented)));
            return;
        }
        queryItems(componentJid: componentJid, node: node, query: .init(version: version, with: with, start: start, end: end), queryId: queryId, rsm: rsm, completionHandler: completionHandler);
    }
    
    open func queryItems(componentJid: JID? = nil, node: String? = nil, query: MAMQueryForm, queryId: String, rsm: RSM.Query? = nil, completionHandler: @escaping (Result<QueryResult,XMPPError>)->Void)
    {
        Task {
            do {
                completionHandler(.success(try await queryItems(query, at: componentJid, node: node, queryId: queryId, rsm: rsm)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    open func retrieveForm(version: Version? = nil, componentJid: JID? = nil, completionHandler: @escaping (Result<MAMQueryForm,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await retrieveForm(version: version, from: componentJid)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

    open func retrieveSettings(version: Version? = nil, completionHandler: @escaping (Result<Settings,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await settings(version: version)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    open func updateSettings(version: Version? = nil, settings: Settings, completionHandler: @escaping (Result<Settings,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await self.settings(settings, version: version)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    open func updateSettings(version: Version, settings: Settings) async throws -> Settings {
        return try await withUnsafeThrowingContinuation { continuation in
            updateSettings(version: version, settings: settings, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
}

//
// JingleModule.swift
//
// TigaseSwift
// Copyright (C) 2019 "Tigase, Inc." <office@tigase.com>
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

public protocol JingleSession: Equatable {
    
    var account: BareJID { get }
    var jid: JID { get }
    var sid: String { get }
    
    init(account: BareJID, jid: JID, sid: String?, role: Jingle.Content.Creator);
    
    func terminate() -> Bool;
}

public protocol JingleSessionManager {

    func activeSessionSid(for account: BareJID, with jid: JID) -> String?;
    
}

open class JingleModule: XmppModule, ContextAware {
    
    public static let XMLNS = "urn:xmpp:jingle:1";
    
    public static let MESSAGE_INITIATION_XMLNS = "urn:xmpp:jingle-message:0";
    
    public static let ID = XMLNS;
    
    public let id = XMLNS;
    
    public let criteria = Criteria.or(Criteria.name("iq").add(Criteria.name("jingle", xmlns: XMLNS)), Criteria.name("message").add(Criteria.xmlns(MESSAGE_INITIATION_XMLNS)));
    
    public var context: Context!;
    
    public var features: [String] {
        get {
            var result = [JingleModule.XMLNS];
            if supportsMessageInitiation {
                result.append(JingleModule.MESSAGE_INITIATION_XMLNS);
            }
            result.append(contentsOf: supportedTransports.flatMap({ (type, features) in
                return features;
            }));
            result.append(contentsOf: supportedDescriptions.flatMap({ (type, features) in
                return features;
            }));
            return Array(Set(result));
        }
    }
//    var features: [String] = [XMLuNS, "urn:xmpp:jingle:apps:rtp:1", "urn:xmpp:jingle:apps:rtp:audio", "urn:xmpp:jingle:apps:rtp:video"];
    
    fileprivate var supportedDescriptions: [(JingleDescription.Type, [String])] = [];
    fileprivate var supportedTransports: [(JingleTransport.Type, [String])] = [];

    fileprivate let sessionManager: JingleSessionManager;

    public var supportsMessageInitiation = false;
    
    public init(sessionManager: JingleSessionManager) {
        self.sessionManager = sessionManager;
    }
    
    public func register(description: JingleDescription.Type, features: [String]) {
        supportedDescriptions.append((description, features));
    }
    
    public func unregister(description: JingleDescription.Type) {
        guard let idx = supportedTransports.firstIndex(where: { (desc, features) -> Bool in
            return desc == description;
        }) else {
            return;
        }
        supportedDescriptions.remove(at: idx);

    }
    
    public func register(transport: JingleTransport.Type, features: [String]) {
        supportedTransports.append((transport, features));
    }
    
    public func unregister(transport: JingleTransport.Type) {
        guard let idx = supportedTransports.firstIndex(where: { (trans, features) -> Bool in
            return trans == transport;
        }) else {
            return;
        }
        supportedTransports.remove(at: idx);
    }
 
    public func process(stanza: Stanza) throws {
        switch stanza {
        case let message as Message:
            guard supportsMessageInitiation else {
                guard message.type != .error else {
                    return;
                }
                throw ErrorCondition.feature_not_implemented;
            }
            try process(message: message);
        case let iq as Iq:
            try process(iq: iq);
        default:
            throw ErrorCondition.feature_not_implemented;
        }
    }
    
    open func process(iq stanza: Iq) throws {
        guard stanza.type ?? StanzaType.get == .set else {
            throw ErrorCondition.feature_not_implemented;
        }
        
        let jingle = stanza.findChild(name: "jingle", xmlns: JingleModule.XMLNS)!;
        
        // sid is required but Movim is not sending it so we are adding another workaround!
        guard let action = Jingle.Action(rawValue: jingle.getAttribute("action") ?? ""), let from = stanza.from, let sid = jingle.getAttribute("sid") ?? sessionManager.activeSessionSid(for: context.sessionObject.userBareJid!, with: from), let initiator = JID(jingle.getAttribute("initiator")) ?? stanza.from else {
            throw ErrorCondition.bad_request;
        }
        
        let contents = jingle.getChildren(name: "content").map({ contentEl in
            return Jingle.Content(from: contentEl, knownDescriptions: self.supportedDescriptions.map({ (desc, features) in
                return desc;
            }), knownTransports: self.supportedTransports.map({ (trans, features) in
                return trans;
            }));
        }).filter({ content -> Bool in
            return content != nil
        }).map({ content -> Jingle.Content in
            return content!;
        });
        
        let bundle = jingle.findChild(name: "group", xmlns: "urn:xmpp:jingle:apps:grouping:0")?.mapChildren(transform: { (el) -> String? in
            return el.getAttribute("name");
        }, filter: { (el) -> Bool in
            return el.name == "content" && el.getAttribute("name") != nil;
        });
        
        context.eventBus.fire(JingleEvent(sessionObject: context.sessionObject, jid: from, action: action, initiator: initiator, sid: sid, contents: contents, bundle: bundle));//, session: session));
        
        context.writer?.write(stanza.makeResult(type: .result));
    }
    
    public func process(message: Message) throws {
        guard let action = message.jingleMessageInitiationAction, let from = message.from else {
            return;
        }
        switch action {
        case .propose(_, let descriptions):
            let xmlnss = descriptions.map({ $0.xmlns });
            guard supportedDescriptions.first(where: { (type, features) -> Bool in features.contains(where: { xmlnss.contains($0)})}) != nil else {
                self.sendMessageInitiation(action: .reject(id: id), to: from);
                return;
            }
        default:
            break;
        }
        context.eventBus.fire(JingleMessageInitiationEvent(sessionObject: context.sessionObject, jid: from, action: action));
    }
    
    public func sendMessageInitiation(action: Jingle.MessageInitiationAction, to jid: JID) {
        switch action {
        case .proceed(let id):
            sendMessageInitiation(action: .accept(id: id), to: JID(context.sessionObject.userBareJid!));
        case .reject(let id):
            if jid.bareJid != context.sessionObject.userBareJid! {
                sendMessageInitiation(action: .reject(id: id), to: JID(context.sessionObject.userBareJid!));
            }
        default:
            break;
        }
        let response = Message();
        response.type = .chat;
        response.to = jid;
        response.jingleMessageInitiationAction = action;
        context.writer?.write(response);
    }
    
    public func initiateSession(to jid: JID, sid: String, initiator: JID, contents: [Jingle.Content], bundle: [String]?, callback: @escaping (ErrorCondition?)->Void) {
        let iq = Iq();
        iq.to = jid;
        iq.type = StanzaType.set;
        
        let jingle = Element(name: "jingle", xmlns: JingleModule.XMLNS);
        jingle.setAttribute("action", value: "session-initiate");
        jingle.setAttribute("sid", value: sid);
        jingle.setAttribute("initiator", value: initiator.stringValue);
    
        iq.addChild(jingle);
        
        contents.forEach { (content) in
            jingle.addChild(content.toElement());
        }
        
        if bundle != nil {
            let group = Element(name: "group", xmlns: "urn:xmpp:jingle:apps:grouping:0");
            group.setAttribute("semantics", value: "BUNDLE");
            bundle?.forEach({ (name) in
                group.addChild(Element(name: "content", attributes: ["name": name]));
            })
            jingle.addChild(group);
        }
        
        context.writer?.write(iq, callback: { (response) in
            let error = response == nil ? ErrorCondition.remote_server_timeout : response!.errorCondition;
//            if error != nil {
//                self.sessionManager.close(account: self.context.sessionObject.userBareJid!, jid: jid, sid: sid);
//            }
            callback(error);
        });
    }
    
    public func acceptSession(with jid: JID, sid: String, initiator: JID, contents: [Jingle.Content], bundle: [String]?, callback: @escaping (ErrorCondition?)->Void) {
        let iq = Iq();
        iq.to = jid;
        iq.type = StanzaType.set;
        
        let jingle = Element(name: "jingle", xmlns: JingleModule.XMLNS);
        jingle.setAttribute("action", value: "session-accept");
        jingle.setAttribute("sid", value: sid);
        jingle.setAttribute("initiator", value: initiator.stringValue);
        
        iq.addChild(jingle);
        
        contents.forEach { (content) in
            jingle.addChild(content.toElement());
        }
        
        if bundle != nil {
            let group = Element(name: "group", xmlns: "urn:xmpp:jingle:apps:grouping:0");
            group.setAttribute("semantics", value: "BUNDLE");
            bundle?.forEach({ (name) in
                group.addChild(Element(name: "content", attributes: ["name": name]));
            })
            jingle.addChild(group);
        }
        
        context.writer?.write(iq, callback: { (response) in
            let error = response == nil ? ErrorCondition.remote_server_timeout : response!.errorCondition;
            callback(error);
        });
    }
    
    public func declineSession(with jid: JID, sid: String) {
        terminateSession(with: jid, sid: sid, reason: Element(name: "reason", children: [Element(name: "decline")]));
    }
    
    public func terminateSession(with jid: JID, sid: String, reason: Element = Element(name: "reason", children: [Element(name: "success")])) {
        let iq = Iq();
        iq.to = jid;
        iq.type = StanzaType.set;
        
        let jingle = Element(name: "jingle", xmlns: JingleModule.XMLNS);
        jingle.setAttribute("action", value: "session-terminate");
        jingle.setAttribute("sid", value: sid);
        
        iq.addChild(jingle);

        // TODO: improve that in the future!
        
        jingle.addChild(reason);
        
        context.writer?.write(iq, callback: { response in
            print("session terminated and answer received", response as Any);
        });
    }
    
    public func transportInfo(with jid: JID, sid: String, contents: [Jingle.Content]) {
        let iq = Iq();
        iq.to = jid;
        iq.type = StanzaType.set;
        
        let jingle = Element(name: "jingle", xmlns: JingleModule.XMLNS);
        jingle.setAttribute("action", value: "transport-info");
        jingle.setAttribute("sid", value: sid);
        
        contents.forEach { content in
            jingle.addChild(content.toElement());
        }
        
        iq.addChild(jingle);
        
        context.writer?.write(iq, completionHandler: { response in
            print("session transport-info response received:", response as Any);
        });
    }
    
    open class JingleEvent: Event {
        
        public static let TYPE = JingleEvent();
        
        public let type = "JingleEvent";
        
        public let sessionObject: SessionObject!;
        public let jid: JID!;
        public let action: Jingle.Action!;
        public let initiator: JID!;
        public let sid: String!;
        public let contents: [Jingle.Content];
        public let bundle: [String]?;
//        let session: Jingle.Session!;
        
        init() {
            self.sessionObject = nil;
            self.jid = nil;
            self.action = nil;
            self.initiator = nil;
            self.sid = nil;
            self.contents = [];
            self.bundle = nil;
//            self.session = nil;
        }
        
        public init(sessionObject: SessionObject, jid: JID, action: Jingle.Action, initiator: JID, sid: String, contents: [Jingle.Content], bundle: [String]?) {//}, session: Jingle.Session) {
            self.sessionObject = sessionObject;
            self.jid = jid;
            self.action = action;
            self.initiator = initiator;
            self.sid = sid;
            self.contents = contents;
            self.bundle = bundle;
//            self.session = session;
        }
        
    }
    
    open class JingleMessageInitiationEvent: Event {
        
        public static let TYPE = JingleMessageInitiationEvent();
                
        public let type = "JingleMessageInitiationEvent";
                
        public let sessionObject: SessionObject!;
        public let jid: JID!;
        public let action: Jingle.MessageInitiationAction!;
                
        init() {
            self.sessionObject = nil;
            self.jid = nil;
            self.action = nil;
        }
                
        public init(sessionObject: SessionObject, jid: JID, action: Jingle.MessageInitiationAction) {
            self.sessionObject = sessionObject;
            self.jid = jid;
            self.action = action;
        }
    }
}


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
import Combine

extension XmppModuleIdentifier {
    public static var jingle: XmppModuleIdentifier<JingleModule> {
        return JingleModule.IDENTIFIER;
    }
}

open class JingleModule: XmppModuleBase, XmppModule {
    
    public static let XMLNS = "urn:xmpp:jingle:1";
    
    public static let MESSAGE_INITIATION_XMLNS = "urn:xmpp:jingle-message:0";
    
    public static let ID = XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<JingleModule>();
    
    public let criteria = Criteria.or(Criteria.name("iq").add(Criteria.name("jingle", xmlns: XMLNS)), Criteria.name("message").add(Criteria.xmlns(MESSAGE_INITIATION_XMLNS)));
    
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
    
    private var supportedDescriptions: [(JingleDescription.Type, [String])] = [];
    private var supportedTransports: [(JingleTransport.Type, [String])] = [];

    private let sessionManager: JingleSessionManager;

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
                throw XMPPError.feature_not_implemented;
            }
            try process(message: message);
        case let iq as Iq:
            try process(iq: iq);
        default:
            throw XMPPError.feature_not_implemented;
        }
    }
    
    open func process(iq stanza: Iq) throws {
        guard stanza.type ?? StanzaType.get == .set else {
            throw XMPPError.bad_request("All messages should be of type 'set'");
        }
        
        let jingle = stanza.findChild(name: "jingle", xmlns: JingleModule.XMLNS)!;
        
        guard let action = Jingle.Action(rawValue: jingle.getAttribute("action") ?? ""), let from = stanza.from else {
            throw XMPPError.bad_request("Missing or invalid action attribute");
        }
        
        guard let sid = jingle.getAttribute("sid") else {
            throw XMPPError.bad_request("Missing sid attributed")
        }
        guard let initiator = JID(jingle.getAttribute("initiator")) ?? stanza.from else {
            throw XMPPError.bad_request("Missing initiator attribute");
        }
        
        guard let context = self.context else {
            throw XMPPError.resource_constraint(nil);
        }
        
        let contents = self.contents(from: jingle);
        let bundle = self.bundle(from: jingle);
        
        fire(JingleEvent(context: context, jid: from, action: action, initiator: initiator, sid: sid, contents: contents, bundle: bundle));

        switch action {
        case .sessionInitiate:
            try self.sessionManager.sessionInitiated(for: context, with: from, sid: sid, contents: contents, bundle: bundle);
        case .sessionAccept:
            try self.sessionManager.sessionAccepted(for: context, with: from, sid: sid,contents: contents, bundle: bundle);
        case .sessionTerminate:
            try self.sessionManager.sessionTerminated(for: context, with: from, sid: sid);
        case .transportInfo:
            try self.sessionManager.transportInfo(for: context, with: from, sid: sid, contents: contents);
        case .contentAdd, .contentModify, .contentRemove:
            guard let contentAction = Jingle.ContentAction.from(action) else {
                throw XMPPError.bad_request("Invalid action");
            }
            try self.sessionManager.contentModified(for: context, with: from, sid: sid, action: contentAction, contents: contents, bundle: bundle);
        case .sessionInfo:
            let infos = jingle.getChildren(name: nil, xmlns: Jingle.SessionInfo.XMLNS).compactMap(Jingle.SessionInfo.from(element:));
            try self.sessionManager.sessionInfo(for: context, with: from, sid: sid, info: infos);
        default:
            throw XMPPError.feature_not_implemented;
        }
        
        write(stanza.makeResult(type: .result));
    }
        
    open func bundle(from jingle: Element) -> [String]? {
        return jingle.findChild(name: "group", xmlns: "urn:xmpp:jingle:apps:grouping:0")?.mapChildren(transform: { (el) -> String? in
            return el.getAttribute("name");
        }, filter: { (el) -> Bool in
            return el.name == "content" && el.getAttribute("name") != nil;
        });
    }
    
    open func contents(from jingle: Element) -> [Jingle.Content] {
        return jingle.getChildren(name: "content").compactMap({ contentEl in
            return Jingle.Content(from: contentEl, knownDescriptions: self.supportedDescriptions.map({ (desc, features) in
                return desc;
            }), knownTransports: self.supportedTransports.map({ (trans, features) in
                return trans;
            }));
        });
    }
    
    public func process(message: Message) throws {
        guard let action = message.jingleMessageInitiationAction, let from = message.from else {
            return;
        }
        switch action {
        case .propose(let id, let descriptions):
            let xmlnss = descriptions.map({ $0.xmlns });
            guard supportedDescriptions.first(where: { (type, features) -> Bool in features.contains(where: { xmlnss.contains($0)})}) != nil else {
                self.sendMessageInitiation(action: .reject(id: id), to: from);
                return;
            }
        case .accept(_):
            guard from != context?.boundJid else {
                return;
            }
        default:
            break;
        }
        if let context = context {
            fire(JingleMessageInitiationEvent(context: context, jid: from, action: action));
            try sessionManager.messageInitiation(for: context, from: from, action: action);
        }
    }
    
    public func sendMessageInitiation(action: Jingle.MessageInitiationAction, to jid: JID, writeCompleted: ((Result<Void,XMPPError>)->Void)? = nil) {
        guard let userJid = context?.userBareJid else {
            return;
        }
        switch action {
        case .proceed(let id):
            sendMessageInitiation(action: .accept(id: id), to: JID(userJid));
        case .reject(let id):
            if jid.bareJid != userJid {
                sendMessageInitiation(action: .reject(id: id), to: JID(userJid));
            }
        default:
            break;
        }
        let response = Message();
        response.type = .chat;
        response.to = jid;
        response.jingleMessageInitiationAction = action;
        write(response, writeCompleted: writeCompleted);
    }

    public func initiateSession(to jid: JID, sid: String, contents: [Jingle.Content], bundle: [String]?, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        guard let initiatior = context?.boundJid else {
            completionHandler(.failure(.undefined_condition));
            return;
        }
        let iq = Iq();
        iq.to = jid;
        iq.type = StanzaType.set;
        
        let jingle = Element(name: "jingle", xmlns: JingleModule.XMLNS);
        jingle.setAttribute("action", value: "session-initiate");
        jingle.setAttribute("sid", value: sid);
        jingle.setAttribute("initiator", value: initiatior.stringValue);
    
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
        
        write(iq, completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        });
    }
    
    public func acceptSession(with jid: JID, sid: String, contents: [Jingle.Content], bundle: [String]?, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        guard let responder = context?.boundJid else {
            completionHandler(.failure(.undefined_condition));
            return;
        }
        let iq = Iq();
        iq.to = jid;
        iq.type = StanzaType.set;
        
        let jingle = Element(name: "jingle", xmlns: JingleModule.XMLNS);
        jingle.setAttribute("action", value: "session-accept");
        jingle.setAttribute("sid", value: sid);
        jingle.setAttribute("responder", value: responder.stringValue);
        
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
        
        write(iq, completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        });
    }
    
    public func sessionInfo(with jid: JID, sid: String, actions: [Jingle.SessionInfo], creatorProvider: (String)->Jingle.Content.Creator) {
        guard !actions.isEmpty else {
            return;
        }
        
        let iq = Iq();
        iq.to = jid;
        iq.type = StanzaType.set;
        
        let jingle = Element(name: "jingle", xmlns: JingleModule.XMLNS);
        jingle.setAttribute("action", value: "session-info");
        jingle.setAttribute("sid", value: sid);

        actions.map({ it in it.element(creatorProvider: creatorProvider)}).forEach(jingle.addChild(_:));
        
        iq.addChild(jingle);
        
        write(iq, completionHandler: { result in
            print("session info sent and answer received", result);
        });
    }
    
    public func terminateSession(with jid: JID, sid: String, reason: JingleSessionTerminateReason) {
        let iq = Iq();
        iq.to = jid;
        iq.type = StanzaType.set;
        
        let jingle = Element(name: "jingle", xmlns: JingleModule.XMLNS);
        jingle.setAttribute("action", value: "session-terminate");
        jingle.setAttribute("sid", value: sid);
        
        iq.addChild(jingle);

        jingle.addChild(reason.toReasonElement());
        
        write(iq, completionHandler: { result in
            print("session terminated and answer received", result);
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
        
        write(iq, completionHandler: { response in
            print("session transport-info response received:", response as Any);
        });
    }
    
    public func contentModify(with jid: JID, sid: String, action: Jingle.ContentAction, contents: [Jingle.Content], bundle: [String]?) -> Future<Void, XMPPError> {
        return Future({ promise in
            let iq = Iq();
            iq.to = jid;
            iq.type = StanzaType.set;
            
            let jingle = Element(name: "jingle", xmlns: JingleModule.XMLNS);
            jingle.setAttribute("action", value: action.jingleAction.rawValue);
            jingle.setAttribute("sid", value: sid);
        
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
            
            self.write(iq, completionHandler: { result in
                promise(result.map({ _ in Void() }));
            });
        });
    }
    
    open class JingleEvent: AbstractEvent {
        
        public static let TYPE = JingleEvent();
        
        public let jid: JID!;
        public let action: Jingle.Action!;
        public let initiator: JID!;
        public let sid: String!;
        public let contents: [Jingle.Content];
        public let bundle: [String]?;
        
        init() {
            self.jid = nil;
            self.action = nil;
            self.initiator = nil;
            self.sid = nil;
            self.contents = [];
            self.bundle = nil;
            super.init(type: "JingleEvent");
        }
        
        public init(context: Context, jid: JID, action: Jingle.Action, initiator: JID, sid: String, contents: [Jingle.Content], bundle: [String]?) {//}, session: Jingle.Session) {
            self.jid = jid;
            self.action = action;
            self.initiator = initiator;
            self.sid = sid;
            self.contents = contents;
            self.bundle = bundle;
            super.init(type: "JingleEvent", context: context);
        }
        
    }
    
    open class JingleMessageInitiationEvent: AbstractEvent {
        
        public static let TYPE = JingleMessageInitiationEvent();
                
        public let jid: JID!;
        public let action: Jingle.MessageInitiationAction!;
                
        init() {
            self.jid = nil;
            self.action = nil;
            super.init(type: "JingleMessageInitiationEvent");
        }
                
        public init(context: Context, jid: JID, action: Jingle.MessageInitiationAction) {
            self.jid = jid;
            self.action = action;
            super.init(type: "JingleMessageInitiationEvent", context: context);
        }
    }
    
}

public enum JingleSessionTerminateReason: String {
    case alternativeSession = "alternative-session"
    case busy = "busy"
    case cancel = "cancel"
    case connectivityError = "connectivity-error"
    case decline = "decline"
    case expired = "expired"
    case failedApplication = "failed-application"
    case failedTransport = "failed-transport"
    case generalError = "general-error"
    case gone = "gone"
    case incompatibleParameters = "incompatible-parameters"
    case mediaError = "media-error"
    case securityError = "security-error"
    case success = "success"
    case timeout = "timeout"
    case unsupportedApplications = "unsupported-applications"
    case unsupportedTransports = "unsupported-transports"
    
    func toElement() -> Element {
        return Element(name: rawValue);
    }
    
    func toReasonElement() -> Element {
        return Element(name: "reason", children: [toElement()]);
    }
}

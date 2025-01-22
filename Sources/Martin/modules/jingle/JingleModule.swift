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

open class JingleModule: XmppModuleBase, XmppStanzaProcessor, @unchecked Sendable {
    
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

    private let supportsMessageInitiation: Bool;
    
    public init(sessionManager: JingleSessionManager, supportsMessageInitiation: Bool = false) {
        self.sessionManager = sessionManager;
        self.supportsMessageInitiation = supportsMessageInitiation;
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
                throw XMPPError(condition: .feature_not_implemented);
            }
            try process(message: message);
        case let iq as Iq:
            try process(iq: iq);
        default:
            throw XMPPError(condition: .feature_not_implemented);
        }
    }
    
    open func process(iq stanza: Iq) throws {
        guard stanza.type ?? StanzaType.get == .set else {
            throw XMPPError(condition: .bad_request, message: "All messages should be of type 'set'");
        }
        
        let jingle = stanza.firstChild(name: "jingle", xmlns: JingleModule.XMLNS)!;
        
        guard let action = Jingle.Action(rawValue: jingle.attribute("action") ?? ""), let from = stanza.from else {
            throw XMPPError(condition: .bad_request, message: "Missing or invalid action attribute");
        }
        
        guard let sid = jingle.attribute("sid") else {
            throw XMPPError(condition: .bad_request, message: "Missing sid attributed")
        }
        guard (JID(jingle.attribute("initiator")) ?? stanza.from) != nil else {
            throw XMPPError(condition: .bad_request, message: "Missing initiator attribute");
        }
        
        guard let context = self.context else {
            throw XMPPError(condition: .resource_constraint);
        }
        
        let contents = self.contents(from: jingle);
        let bundle = Jingle.Bundle(jingle: jingle);
        
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
                throw XMPPError(condition: .bad_request, message: "Invalid action");
            }
            try self.sessionManager.contentModified(for: context, with: from, sid: sid, action: contentAction, contents: contents, bundle: bundle);
        case .sessionInfo:
            let infos = jingle.filterChildren(xmlns: Jingle.SessionInfo.XMLNS).compactMap(Jingle.SessionInfo.from(element:));
            try self.sessionManager.sessionInfo(for: context, with: from, sid: sid, info: infos);
        default:
            throw XMPPError(condition: .feature_not_implemented);
        }
        
        write(stanza: stanza.makeResult(type: .result));
    }
    
    open func contents(from jingle: Element) -> [Jingle.Content] {
        return jingle.filterChildren(name: "content").compactMap({ contentEl in
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
                Task {
                    try await self.sendMessageInitiation(action: .reject(id: id), to: from);
                }
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
            try sessionManager.messageInitiation(for: context, from: from, action: action);
        }
    }
    
    public func sendMessageInitiation(action: Jingle.MessageInitiationAction, to jid: JID) async throws {
        guard let userJid = context?.userBareJid else {
            throw XMPPError.undefined_condition;
        }
        
        try await withThrowingTaskGroup(of: Void.self, body: { group in
            switch action {
            case .proceed(let id):
                group.addTask {
                    try await self.sendMessageInitiation(action: .accept(id: id), to: JID(userJid));
                }
            case .reject(let id):
                group.addTask {
                    if jid.bareJid != userJid {
                        try await self.sendMessageInitiation(action: .reject(id: id), to: JID(userJid));
                    }
                }
            default:
                break;
            }
            group.addTask {
                let response = Message(type: .chat, to: jid);
                response.jingleMessageInitiationAction = action;
                try await self.write(stanza: response);
            }
            
            for try await _ in group {
            }
        })
    }

    public func initiateSession(to jid: JID, sid: String, contents: [Jingle.Content], bundle: Jingle.Bundle?) async throws {
        guard let initiatior = context?.boundJid else {
            throw XMPPError.undefined_condition
        }
        let iq = Iq(type: .set, to: jid, {
            Element(name: "jingle", xmlns: JingleModule.XMLNS, {
                Attribute("action", value: "session-initiate")
                Attribute("sid", value: sid)
                Attribute("initiator", value: initiatior.description)
                for content in contents {
                    content.element();
                }
                bundle?.element()
            })
        });
        
        try await write(iq: iq);
    }
    
    public func acceptSession(with jid: JID, sid: String, contents: [Jingle.Content], bundle: Jingle.Bundle?) async throws {
        guard let responder = context?.boundJid else {
            throw XMPPError.undefined_condition
        }
        let iq = Iq(type: .set, to: jid, {
            Element(name: "jingle", xmlns: JingleModule.XMLNS, {
                Attribute("action", value: "session-accept")
                Attribute("sid", value: sid)
                Attribute("responder", value: responder.description)
                for content in contents {
                    content.element();
                }
                bundle?.element()
            })
        });
        
        try await write(iq: iq);
    }
    
    public func sessionInfo(with jid: JID, sid: String, actions: [Jingle.SessionInfo], creatorProvider: (String)->Jingle.Content.Creator) async throws {
        guard !actions.isEmpty else {
            return;
        }
        
        let iq = Iq(type: .set, to: jid, {
            Element(name: "jingle", xmlns: JingleModule.XMLNS, {
                Attribute("action", value: "session-info")
                Attribute("sid", value: sid)
                for action in actions {
                    action.element(creatorProvider: creatorProvider);
                }
            })
        });
        
        try await write(iq: iq);
    }
    
    public func terminateSession(with jid: JID, sid: String, reason: JingleSessionTerminateReason) async throws {
        let iq = Iq(type: .set, to: jid, {
            Element(name: "jingle", xmlns: JingleModule.XMLNS, {
                Attribute("action", value: "session-terminate")
                Attribute("sid", value: sid)
                Element(name: "reason", {
                    reason.toElement()
                })
            })
        });
        
        // intentionally we do not wait for the result
        try await write(stanza: iq);
    }
    
    public func transportInfo(with jid: JID, sid: String, contents: [Jingle.Content]) async throws {
        let iq = Iq(type: .set, to: jid, {
            Element(name: "jingle", xmlns: JingleModule.XMLNS, {
                Attribute("action", value: "transport-info")
                Attribute("sid", value: sid)
                for content in contents {
                    content.element();
                }
            })
        });

        try await write(iq: iq);
    }
    
    public func contentModify(with jid: JID, sid: String, action: Jingle.ContentAction, contents: [Jingle.Content], bundle: Jingle.Bundle?) async throws {
        let iq = Iq(type: .set, to: jid, {
            Element(name: "jingle", xmlns: JingleModule.XMLNS, {
                Attribute("action", value: action.jingleAction.rawValue)
                Attribute("sid", value: sid)
                for content in contents {
                    content.element();
                }
                bundle?.element()
            })
        });
        
        try await write(iq: iq);
    }
        
}

// async-await support
extension JingleModule {

    public func sendMessageInitiation(action: Jingle.MessageInitiationAction, to jid: JID, writeCompleted: ((Result<Void,XMPPError>)->Void)? = nil) {
        Task {
            do {
                writeCompleted?(.success(try await self.sendMessageInitiation(action: action, to: jid)));
            } catch {
                writeCompleted?(.failure(error as? XMPPError ?? .undefined_condition));
            }
        }
    }

    public func initiateSession(to jid: JID, sid: String, contents: [Jingle.Content], bundle: [String]?, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await initiateSession(to: jid, sid: sid, contents: contents, bundle: Jingle.Bundle(bundle))))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

    public func acceptSession(with jid: JID, sid: String, contents: [Jingle.Content], bundle: [String]?, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await acceptSession(with: jid, sid: sid, contents: contents, bundle: Jingle.Bundle(bundle))))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

    public func sessionInfo(with jid: JID, sid: String, actions: [Jingle.SessionInfo], creatorProvider: @escaping (String)->Jingle.Content.Creator) {
        Task {
            try await sessionInfo(with: jid, sid: sid, actions: actions, creatorProvider: creatorProvider)
        }
    }

    public func terminateSession(with jid: JID, sid: String, reason: JingleSessionTerminateReason) {
        Task {
            try await terminateSession(with: jid, sid: sid, reason: reason);
        }
    }

    public func transportInfo(with jid: JID, sid: String, contents: [Jingle.Content]) {
        Task {
            try await transportInfo(with: jid, sid: sid, contents: contents);
        }
    }

    public func contentModify(with jid: JID, sid: String, action: Jingle.ContentAction, contents: [Jingle.Content], bundle: [String]?, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await contentModify(with: jid, sid: sid, action: action, contents: contents, bundle: Jingle.Bundle(bundle))))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

    public func contentModify(with jid: JID, sid: String, action: Jingle.ContentAction, contents: [Jingle.Content], bundle: [String]?) -> Future<Void, XMPPError> {
        return Future({ promise in
            self.contentModify(with: jid, sid: sid, action: action, contents: contents, bundle: bundle, completionHandler: { result in
                promise(result.map({ _ in Void() }));
            })
        });
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

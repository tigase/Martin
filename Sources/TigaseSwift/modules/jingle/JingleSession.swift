//
// JingleSession.swift
//
// TigaseSwift
// Copyright (C) 2021 "Tigase, Inc." <office@tigase.com>
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

open class JingleSession: CustomDebugStringConvertible {
    
    public let account: BareJID;
    public private(set) var jid: JID;
    public let sid: String;
    
    private weak var context: Context?;
    private weak var jingleModule: JingleModule?;
    
    @Published
    public private(set) var state: JingleSessionState = .created;
    
    public let role: Jingle.Content.Creator;
    public private(set) var initiationType: JingleSessionInitiationType;
    
    private var contentCreators: [String:Jingle.Content.Creator] = [:];
    
    open var debugDescription: String {
        return "JingleSessin(sid: \(sid), jid: \(jid), account: \(account), state: \(state)";
    }

    public init(context: Context, jid: JID, sid: String, role: Jingle.Content.Creator, initiationType: JingleSessionInitiationType) {
        self.account = context.userBareJid;
        self.context = context;
        self.jingleModule = context.module(.jingle);
        self.jid = jid;
        self.sid = sid;
        self.role = role;
        self.initiationType = initiationType;
    }
    
    open func initiate(contents: [Jingle.Content], bundle: Jingle.Bundle?) async throws {
        updateCreators(of: contents);
        guard let jingleModule = self.jingleModule else {
            do {
                try await self.terminate(reason: .failedApplication);
            } catch {}
            throw XMPPError.undefined_condition;
        }

        do {
            try await jingleModule.initiateSession(to: self.jid, sid: self.sid, contents: contents, bundle: bundle);
        } catch {
            Task { try await self.terminate() };
            throw error;
        }
    }
    
    open func initiate(descriptions: [Jingle.MessageInitiationAction.Description]) async throws {
        guard let jingleModule = self.jingleModule else {
            do {
                try await self.terminate(reason: .failedApplication);
            } catch {}
            throw XMPPError.undefined_condition;
        }
        
        do {
            try await jingleModule.sendMessageInitiation(action: .propose(id: self.sid, descriptions: descriptions), to: self.jid);
        } catch {
            self.state = .terminated;
            throw error;
        }
    }
    
    public func contentCreator(of name: String) -> Jingle.Content.Creator {
        return contentCreators[name] ?? role;
    }
    
    private func updateCreators(of contents: [Jingle.Content]) {
        for content in contents {
            if contentCreators[content.name] == nil {
                contentCreators[content.name] = content.creator;
            }
        }
    }
    
    open func initiated(contents: [Jingle.Content], bundle: Jingle.Bundle?) {
        updateCreators(of: contents);
        if self.state == .created {
            self.state = .initiating;
        }
    }
    
    open func accept() async throws {
        self.state = .accepted;
        if initiationType == .message {
            try await jingleModule?.sendMessageInitiation(action: .proceed(id: self.sid), to: self.jid);
        }
    }
    
    open func accept(contents: [Jingle.Content], bundle: Jingle.Bundle?) async throws {
        updateCreators(of: contents);
        guard let jingleModule = self.jingleModule else {
            do {
                try await self.terminate(reason: .failedApplication);
            } catch {}
            throw XMPPError.undefined_condition;
        }
        
        do {
            try await jingleModule.acceptSession(with: self.jid, sid: self.sid, contents: contents, bundle: bundle);
        } catch {
            Task { try await self.terminate() };
            throw error;
        }
    }
        
    open func accepted(by jid: JID) {
        self.state = .accepted;
        self.jid = jid;
    }
    
    open func accepted(contents: [Jingle.Content], bundle: Jingle.Bundle?) {
        updateCreators(of: contents);
        self.state = .accepted;
    }
    
    open func sessionInfo(_ actions: [Jingle.SessionInfo]) async throws {
        guard let jingleModule = jingleModule else {
            throw XMPPError.undefined_condition;
        }
        try await jingleModule.sessionInfo(with: jid, sid: sid, actions: actions, creatorProvider: { self.contentCreator(of: $0) });
    }
    
    open func transportInfo(contentName: String, transport: JingleTransport) async throws {
        guard let jingleModule = self.jingleModule else {
            throw XMPPError.undefined_condition;
        }
        
        let creator = contentCreator(of: contentName);
        
        try await jingleModule.transportInfo(with: jid, sid: sid, contents: [Jingle.Content(name: contentName, creator: creator, senders: nil, description: nil, transports: [transport])]);
    }

    open func contentModify(action: Jingle.ContentAction, contents: [Jingle.Content], bundle: Jingle.Bundle?) async throws {
        guard let jingleModule = self.jingleModule else {
            throw XMPPError.undefined_condition;
        }
        
        try await jingleModule.contentModify(with: jid, sid: sid, action: action, contents: contents, bundle: bundle);
    }
    
    open func contentModified(action: Jingle.ContentAction, contents: [Jingle.Content], bundle: Jingle.Bundle?) {
        
    }
    
    open func sessionInfoReceived(info: [Jingle.SessionInfo]) {
        
    }
    
    open func terminate(reason: JingleSessionTerminateReason) async throws {
        let oldState = self.state;
        guard state != .terminated else {
            return;
        }
        self.state = .terminated;
        if let jingleModule = context?.module(.jingle) {
            if initiationType == .iq || oldState == .accepted {
                try await jingleModule.terminateSession(with: jid, sid: sid, reason: reason);
            } else {
                try await jingleModule.sendMessageInitiation(action: .reject(id: sid), to: jid);
            }
        }
    }
    
    open func terminated() {
        self.state = .terminated;
    }
}

// async-await support
//extension JingleSession {
//    
//    open func initiate(contents: [Jingle.Content], bundle: [String]?) -> Future<Void,XMPPError> {
//        updateCreators(of: contents);
//        return Future({ promise in
//            guard let jingleModule = self.jingleModule else {
//                self.terminate(reason: .failedApplication);
//                promise(.failure(.undefined_condition));
//                return;
//            }
//            
//            jingleModule.initiateSession(to: self.jid, sid: self.sid, contents: contents, bundle: bundle, completionHandler: { result in
//                switch result {
//                case .success(_):
//                    break;
//                case .failure(_):
//                    self.terminate();
//                }
//                promise(result);
//            })
//        })
//    }
//    
//    open func initiate(descriptions: [Jingle.MessageInitiationAction.Description]) -> Future<Void,XMPPError> {
//        return Future({ promise in
//            guard let jingleModule = self.jingleModule else {
//                self.terminate(reason: .failedApplication);
//                promise(.failure(.undefined_condition));
//                return;
//            }
//        
//            jingleModule.sendMessageInitiation(action: .propose(id: self.sid, descriptions: descriptions), to: self.jid,    writeCompleted: { result in
//                switch result {
//                case .success(_):
//                    break;
//                case .failure(_):
//                    self.state = .terminated;
//                }
//                promise(result);
//            });
//        });
//    }
//    
//    open func accept(contents: [Jingle.Content], bundle: [String]?) -> Future<Void,XMPPError> {
//        updateCreators(of: contents);
//        return Future({ promise in
//            guard let jingleModule = self.jingleModule else {
//                self.terminate(reason: .failedApplication);
//                promise(.failure(.undefined_condition));
//                return;
//            }
//        
//            jingleModule.acceptSession(with: self.jid, sid: self.sid, contents: contents, bundle: bundle) { (result) in
//                switch result {
//                case .success(_):
//                    self.state = .accepted;
//                case .failure(_):
//                    self.terminate();
//                    break;
//
//                }
//                promise(result);
//            }
//        });
//    }
//    
//    open func sessionInfo(_ actions: [Jingle.SessionInfo]) {
//        jingleModule?.sessionInfo(with: jid, sid: sid, actions: actions, creatorProvider: { self.contentCreator(of: $0) });
//    }
//    
//    open func contentModify(action: Jingle.ContentAction, contents: [Jingle.Content], bundle: [String]?) -> Future<Void, XMPPError> {
//        guard let jingleModule = self.jingleModule else {
//            return Future({ promise in
//                promise(.failure(.undefined_condition));
//            });
//        }
//        
//        return jingleModule.contentModify(with: jid, sid: sid, action: action, contents: contents, bundle: bundle);
//    }
//
//    open func transportInfo(contentName: String, transport: JingleTransport) -> Bool {
//        guard let jingleModule = self.jingleModule else {
//            return false;
//        }
//        
//        let creator = contentCreator(of: contentName);
//        
//        jingleModule.transportInfo(with: jid, sid: sid, contents: [Jingle.Content(name: contentName, creator: creator, senders: nil, description: nil, transports: [transport])]);
//        return true;
//    }

//open func terminate(reason: JingleSessionTerminateReason) {
//    let oldState = self.state;
//    guard state != .terminated else {
//        return;
//    }
//    self.state = .terminated;
//    if let jingleModule = context?.module(.jingle) {
//        if initiationType == .iq || oldState == .accepted {
//            jingleModule.terminateSession(with: jid, sid: sid, reason: reason);
//        } else {
//            jingleModule.sendMessageInitiation(action: .reject(id: sid), to: jid);
//        }
//    }
//}

//}

extension JingleSession {
    public func terminate() async throws {
        try await self.terminate(reason: .success);
    }

}

public enum JingleSessionState {
    // new session
    case created
    // session-initiate sent or received
    case initiating
    // session-accept sent or received
    case accepted
    // session-terminate sent or received
    case terminated
}

public enum JingleSessionInitiationType {
    case iq
    case message
}

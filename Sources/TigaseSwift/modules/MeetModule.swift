//
// MeetModule.swift
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

extension XmppModuleIdentifier {
    public static var meet: XmppModuleIdentifier<MeetModule> {
        return MeetModule.IDENTIFIER;
    }
}

open class MeetModule: XmppModuleBase, XmppStanzaProcessor {
    
    public static let ID = "tigase:meet:0";
    public static let IDENTIFIER = XmppModuleIdentifier<MeetModule>();
    
    open override var context: Context? {
        didSet {
            discoModule = context?.module(.disco);
        }
    }
    
    private var discoModule: DiscoveryModule?;

    public let criteria: Criteria = Criteria.or(.name("iq").add(.xmlns(ID)), .name("message").add(.xmlns(ID)));
    
    public let features: [String] = [];
    
    public let eventsPublisher = PassthroughSubject<MeetEvent,Never>();
    
    public enum MeetEvent {
        case publisherJoined(BareJID, Publisher)
        case publisherLeft(BareJID, Publisher)
        case inivitation(MessageInitiationAction, JID)
        
        public var meetJid: BareJID? {
            switch self {
            case .publisherJoined(let meetJid, _), .publisherLeft(let meetJid, _):
                return meetJid;
            default:
                return nil;
            }
        }
    }
    
    public func process(stanza: Stanza) throws {
        guard let from = stanza.from else {
            throw XMPPError(condition: .bad_request);
        }
        switch stanza {
        case let iq as Iq:
            for action in iq.filterChildren(xmlns: MeetModule.ID) {
                switch action.name {
                case "joined":
                    for publisher in action.filterChildren(name: "publisher").compactMap(Publisher.from(element:)) {
                        eventsPublisher.send(.publisherJoined(from.bareJid, publisher));
                    }
                case "left":
                    for publisher in action.filterChildren(name: "publisher").compactMap(Publisher.from(element:)) {
                        eventsPublisher.send(.publisherLeft(from.bareJid, publisher));
                    }
                default:
                    throw XMPPError(condition: .bad_request);
                }
            }
            write(stanza: iq.makeResult(type: .result));
        case let message as Message:
            guard let action = message.meetMessageInitiationAction else {
                throw XMPPError(condition: .bad_request);
            }
            eventsPublisher.send(.inivitation(action, from));
        default:
            throw XMPPError(condition: .bad_request);
        }
    }
    
    public struct Publisher {
        public let jid: BareJID;
        public let streams: [String];
        
        public static func from(element: Element) -> Publisher? {
            guard element.name == "publisher", let jid = BareJID(element.attribute("jid")) else {
                return nil;
            }
            return .init(jid: jid, streams: element.filterChildren(name: "stream").compactMap({ $0.attribute("mid") }));
        }
    }
    
    open func findMeetComponents() async throws -> [MeetComponent] {
        guard let disco = self.context?.module(.disco) else {
            throw XMPPError(condition: .unexpected_request, message: "No context!")
        }
        
        let components = try await disco.serverComponents().items.map({ $0.jid });
        return await withTaskGroup(of: MeetComponent?.self, body: { group in
            for componentJid in components {
                group.addTask {
                    guard let info = try? await disco.info(for: componentJid), info.features.contains(MeetModule.ID) else {
                        return nil;
                    }
                    
                    return MeetComponent(jid: componentJid, features: info.features)
                }
            }
            
            var result: [MeetComponent] = [];
            for await component in group {
                if let comp = component {
                    result.append(comp);
                }
            }
            
            return result;
        })
    }
    
    open func createMeet(at jid: JID, media: [Media], participants: [BareJID] = []) async throws -> JID {
        let iq = Iq(type: .set, to: jid, {
            Element(name: "create", xmlns: MeetModule.ID, {
                for m in media {
                    Element(name: "media", attributes: ["type": m.rawValue])
                }
                for participant in participants {
                    Element(name: "participant", cdata: participant.description)
                }
            })
        });
        
        let response = try await write(iq: iq);
        guard let id = iq.firstChild(name: "create", xmlns: MeetModule.ID)?.attribute("id") else {
            throw XMPPError(condition: .undefined_condition, stanza: response);
        }
        return JID(BareJID(localPart: id, domain: jid.domain));
    }
    
    open func allow(jids: [BareJID], in meetJid: JID) async throws {
        guard !jids.isEmpty else {
            throw XMPPError(condition: .unexpected_request, message: "List of allowed JIDs is empty!");
        }
        
        let iq = Iq(type: .set, to: meetJid, {
            Element(name: "allow", xmlns: MeetModule.ID, {
                for participant in jids {
                    Element(name: "participant", cdata: participant.description);
                }
            })
        });
        
        try await write(iq: iq);
    }
    
    
    open func deny(jids: [BareJID], in meetJid: JID) async throws {
        guard !jids.isEmpty else {
            throw XMPPError(condition: .unexpected_request, message: "List of allowed JIDs is empty!");
        }
        
        let iq = Iq(type: .set, to: meetJid, {
            Element(name: "deny", xmlns: MeetModule.ID, {
                for participant in jids {
                    Element(name: "participant", cdata: participant.description);
                }
            })
        });
        try await write(iq: iq);
    }
    
    open func destroy(meetJid: JID) async throws {
        let iq = Iq(type: .set, to: meetJid, {
            Element(name: "destroy", xmlns: MeetModule.ID)
        });

        try await write(iq: iq);
    }
    
    open func sendMessageInitiation(action: MessageInitiationAction, to jid: JID) async throws {
        guard let userJid = context?.userBareJid else {
            return;
        }
        switch action {
        case .proceed(let id):
            try await sendMessageInitiation(action: .accept(id: id), to: JID(userJid));
        case .reject(let id):
            if jid.bareJid != userJid {
                try await sendMessageInitiation(action: .reject(id: id), to: JID(userJid));
            }
        default:
            break;
        }

        let response = Message(type: .chat, to: jid);
        response.meetMessageInitiationAction = action;
        try await write(stanza: response);
    }
    
    public enum Media: String {
        case audio
        case video
    }
    
    public struct MeetComponent {
        public let jid: JID;
        public let features: [String];
    }
    
    public enum MessageInitiationAction {
        case propose(id: String, meetJid: JID, media: [Media])
        case proceed(id: String)
        case accept(id: String)
        case retract(id: String)
        case reject(id: String)
        
        public static func from(element actionEl: Element) -> MessageInitiationAction? {
            guard let id = actionEl.attribute("id") else {
                return nil;
            }
            switch actionEl.name {
            case "accept":
                return .accept(id: id);
            case "propose":
                let media = actionEl.filterChildren(name: "media").compactMap({ $0.attribute("type") }).compactMap({ Media(rawValue: $0) });
                guard !media.isEmpty, let meetJidStr = actionEl.attribute("jid") else {
                    return nil;
                }
                return .propose(id: id, meetJid: JID(meetJidStr), media: media);
            case "proceed":
                return .proceed(id: id);
            case "retract":
                return .retract(id: id);
            case "reject":
                return .reject(id: id);
            default:
                return nil;
            }
        }
        
        public var actionName: String {
            switch self {
            case .propose(_, _, _):
                return "propose";
            case .proceed(_):
                return "proceed";
            case .accept(_):
                return "accept";
            case .reject(_):
                return "reject";
            case .retract(_):
                return "retract";
            }
        }
    
        public var id: String {
            switch self {
            case .propose(let id, _, _), .proceed(let id), .accept(let id), .reject(let id), .retract(let id):
                return id;
            }
        }
    }
}

extension Message {
    
    var meetMessageInitiationAction: MeetModule.MessageInitiationAction? {
        get {
            guard let actionEl = element.firstChild(xmlns: MeetModule.ID) else {
                return nil;
            }
            return MeetModule.MessageInitiationAction.from(element: actionEl);
        }
        set {
            element.removeChildren(where: { $0.xmlns == MeetModule.ID });
            if let value = newValue {
                let actionEl = Element(name: value.actionName, xmlns: MeetModule.ID);
                actionEl.attribute("id", newValue: value.id);
                switch value {
                case .propose(_, let meetJid, let media):
                    actionEl.attribute("jid", newValue: meetJid.description);
                    for m in media {
                        actionEl.addChild(Element(name: "media", attributes: ["type": m.rawValue]));
                    }
                default:
                    break;
                }
                element.addChild(actionEl);
            }
        }
    }
    
}

// async-await support
extension MeetModule {
    
    open func findMeetComponent(completionHandler: @escaping (Result<[MeetComponent],XMPPError>) -> Void) {
        Task {
            do {
                completionHandler(.success(try await findMeetComponents()));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? XMPPError(condition: .undefined_condition)));
            }
        }
    }
    
    open func createMeet(at jid: JID, media: [Media], participants: [BareJID] = [], completionHandler: @escaping (Result<JID,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await createMeet(at: jid, media: media, participants: participants)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? XMPPError.undefined_condition))
            }
        }
    }
    
    open func allow(jids: [BareJID], in meetJid: JID, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await allow(jids: jids, in: meetJid)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? XMPPError.undefined_condition))
            }
        }
    }
    
    open func deny(jids: [BareJID], in meetJid: JID, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await deny(jids: jids, in: meetJid)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? XMPPError.undefined_condition))
            }
        }
    }
    
    open func destroy(meetJid: JID, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await destroy(meetJid: meetJid)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? XMPPError.undefined_condition))
            }
        }
    }
    
    open func sendMessageInitiation(action: MessageInitiationAction, to jid: JID, writeCompleted: ((Result<Void,XMPPError>)->Void)? = nil) {
        Task {
            do {
                writeCompleted?(.success(try await sendMessageInitiation(action: action, to: jid)))
            } catch {
                writeCompleted?(.failure(error as? XMPPError ?? XMPPError.undefined_condition))
            }
        }
    }
    
}

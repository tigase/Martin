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

open class MeetModule: XmppModuleBase, XmppModule {
    
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
            throw XMPPError.bad_request(nil);
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
                    throw XMPPError.bad_request(nil);
                }
            }
            write(iq.makeResult(type: .result));
        case let message as Message:
            guard let action = message.meetMessageInitiationAction else {
                throw XMPPError.bad_request(nil);
            }
            eventsPublisher.send(.inivitation(action, from));
        default:
            throw XMPPError.bad_request(nil);
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

    open func findMeetComponent(completionHandler: @escaping (Result<[MeetComponent],XMPPError>) -> Void) {
        guard let context = self.context, let discoModule = self.discoModule else {
            completionHandler(.failure(.remote_server_timeout));
            return;
        }
        let serverJid = JID(context.userBareJid.domain);
        discoModule.getItems(for: serverJid, completionHandler: { result in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error));
            case .success(let items):
                var results: [MeetComponent] = [];
                let group = DispatchGroup();
                group.enter();
                for item in items.items {
                    group.enter();
                    discoModule.getInfo(for: item.jid, completionHandler: { result in
                        switch result {
                        case .failure(_):
                            break;
                        case .success(let info):
                            if info.features.contains(MeetModule.ID) {
                                DispatchQueue.main.async {
                                    results.append(MeetComponent(jid: item.jid, features: info.features));
                                }
                            }
                        }
                        group.leave();
                    })
                }
                group.leave();
                group.notify(queue: DispatchQueue.main, execute: {
                    guard !results.isEmpty else {
                        completionHandler(.failure(.item_not_found));
                        return;
                    }
                    completionHandler(.success(results));
                })
            }
        });
    }
    
    open func createMeet(at jid: JID, media: [Media], participants: [BareJID] = [], completionHandler: @escaping (Result<JID,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = .set;
        iq.to = jid;
        
        let createEl = Element(name: "create", xmlns: MeetModule.ID);
        for m in media {
            createEl.addChild(Element(name: "media", attributes: ["type": m.rawValue]));
        }
        
        for participant in participants {
            createEl.addChild(Element(name: "participant", cdata: participant.description));
        }
        
        iq.addChild(createEl);
        
        write(iq, completionHandler: { result in
            completionHandler(result.flatMap({ iq in
                guard let id = iq.firstChild(name: "create", xmlns: MeetModule.ID)?.attribute("id") else {
                    return .failure(.undefined_condition);
                }
                return .success(JID(BareJID(localPart: id, domain: jid.domain)));
            }));
        });
    }
    
    open func allow(jids: [BareJID], in meetJid: JID, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        guard !jids.isEmpty else {
            completionHandler(.failure(.unexpected_request("List of allowed JIDs is empty!")));
            return;
        }
        
        let iq = Iq();
        iq.type = .set;
        iq.to = meetJid;
        
        let allowEl = Element(name: "allow", xmlns: MeetModule.ID);
        
        for participant in jids {
            allowEl.addChild(Element(name: "participant", cdata: participant.description));
        }
        
        iq.addChild(allowEl);
        
        write(iq, completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        });
    }
        
    open func deny(jids: [BareJID], in meetJid: JID, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        guard !jids.isEmpty else {
            completionHandler(.failure(.unexpected_request("List of denied JIDs is empty!")));
            return;
        }
        
        let iq = Iq();
        iq.type = .set;
        iq.to = meetJid;
        
        let allowEl = Element(name: "deny", xmlns: MeetModule.ID);
        
        for participant in jids {
            allowEl.addChild(Element(name: "participant", cdata: participant.description));
        }
        
        iq.addChild(allowEl);
        
        write(iq, completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        });
    }
    
    open func destroy(meetJid: JID, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = .set;
        iq.to = meetJid;
        
        let destroyEl = Element(name: "destroy", xmlns: MeetModule.ID);

        iq.addChild(destroyEl);

        write(iq, completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        });
    }
    
    open func sendMessageInitiation(action: MessageInitiationAction, to jid: JID, writeCompleted: ((Result<Void,XMPPError>)->Void)? = nil) {
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
        response.meetMessageInitiationAction = action;
        write(response, writeCompleted: writeCompleted);
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

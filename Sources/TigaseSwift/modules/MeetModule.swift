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

    public let criteria: Criteria = Criteria.name("iq").add(Criteria.xmlns(ID));
    
    public let features: [String] = [];
    
    public let eventsPublisher = PassthroughSubject<MeetEvent,Never>();
    
    public enum MeetEvent {
        case publisherJoined(BareJID, Publisher)
        case publisherLeft(BareJID, Publisher)
        
        public var meetJid: BareJID {
            switch self {
            case .publisherJoined(let meetJid, _), .publisherLeft(let meetJid, _):
                return meetJid;
            }
        }
    }
    
    public func process(stanza: Stanza) throws {
        guard let from = stanza.from?.bareJid else {
            throw ErrorCondition.bad_request;
        }
        for action in stanza.getChildren(xmlns: MeetModule.ID) {
            switch action.name {
            case "joined":
                for publisher in action.getChildren(name: "publisher").compactMap(Publisher.from(element:)) {
                    eventsPublisher.send(.publisherJoined(from, publisher));
                }
            case "left":
                for publisher in action.getChildren(name: "publisher").compactMap(Publisher.from(element:)) {
                    eventsPublisher.send(.publisherLeft(from, publisher));
                }
            default:
                throw ErrorCondition.bad_request;
            }
        }
        write(stanza.makeResult(type: .result));
    }
    
    public struct Publisher {
        public let jid: BareJID;
        public let streams: [String];
        
        public static func from(element: Element) -> Publisher? {
            guard element.name == "publisher", let jid = BareJID(element.getAttribute("jid")) else {
                return nil;
            }
            return .init(jid: jid, streams: element.getChildren(name: "stream").compactMap({ $0.getAttribute("mid") }));
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
            createEl.addChild(Element(name: "participant", cdata: participant.stringValue));
        }
        
        iq.addChild(createEl);
        
        write(iq, completionHandler: { result in
            completionHandler(result.flatMap({ iq in
                guard let id = iq.findChild(name: "create", xmlns: MeetModule.ID)?.getAttribute("id") else {
                    return .failure(.undefined_condition);
                }
                return .success(JID(BareJID(localPart: id, domain: jid.domain)));
            }));
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
    
    public enum Media: String {
        case audio
        case video
    }
    
    public struct MeetComponent {
        public let jid: JID;
        public let features: [String];
    }
}

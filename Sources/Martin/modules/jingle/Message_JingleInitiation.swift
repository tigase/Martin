//
// Message_JingleInitiation.swift
//
// TigaseSwift
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
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

extension Message {
    
    public var jingleMessageInitiationAction: Jingle.MessageInitiationAction? {
        get {
            guard let actionEl = element.firstChild(xmlns: "urn:xmpp:jingle-message:0") else {
                return nil;
            }
            return Jingle.MessageInitiationAction.from(element: actionEl);
        }
        set {
            element.removeChildren(where: { $0.xmlns == "urn:xmpp:jingle-message:0" });
            if let value = newValue {
                let actionEl = Element(name: value.actionName, xmlns: "urn:xmpp:jingle-message:0");
                actionEl.attribute("id", newValue: value.id);
                switch value {
                case .propose(_, let descriptions):
                    actionEl.addChildren(descriptions.map({ $0.element() }));
                default:
                    break;
                }
                element.addChild(actionEl);
            }
        }
    }
    
}

extension Jingle {
public enum MessageInitiationAction {
    case propose(id: String, descriptions: [Description])
    case retract(id: String)
    
    case accept(id: String)
    case proceed(id: String)
    case reject(id: String)
    
    public static func from(element actionEl: Element) -> MessageInitiationAction? {
        guard let id = actionEl.attribute("id") else {
            return nil;
        }
        switch actionEl.name {
        case "accept":
            return .accept(id: id);
        case "proceed":
            return .proceed(id: id);
        case "propose":
            let descriptions = actionEl.compactMapChildren(Description.init(element:));
            guard !descriptions.isEmpty else {
                return nil;
            }
            return .propose(id: id, descriptions: descriptions);
        case "retract":
            return .retract(id: id);
        case "reject":
            return .reject(id: id);
        default:
            return nil;
        }
    }
    
    var actionName: String {
        get {
            switch self {
            case .accept(_):
                return "accept";
            case .proceed(_):
                return "proceed";
            case .propose(_, _):
                return "propose";
            case .retract(_):
                return "retract";
            case .reject(_):
                return "reject";
            }
        }
    }
    
    public var id: String {
        switch self {
        case .accept(let id):
            return id;
        case .proceed(let id):
            return id;
        case .propose(let id, _):
            return id;
        case .retract(let id):
            return id;
        case .reject(let id):
            return id;
        }
    }
        
    public class Description {
        public let xmlns: String;
        public let media: String;
        
        public convenience init?(element descEl: Element) {
            guard let xmlns = descEl.xmlns, let media = descEl.attribute("media") else {
                return nil;
            }
            self.init(xmlns: xmlns, media: media);
        }
        
        public init(xmlns: String, media: String) {
            self.xmlns = xmlns;
            self.media = media;
        }

        func element() -> Element {
            return Element(name: "description", attributes: ["xmlns": xmlns, "media": media]);
        }
    }
}
}

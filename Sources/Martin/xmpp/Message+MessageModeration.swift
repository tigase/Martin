//
// Message+MessageModeration.swift
//
// TigaseSwift
// Copyright (C) 2016 "Tigase, Inc." <office@tigase.com>
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
    
    public struct Moderation {
        
        public enum Retraction {
            // message with id was moderated by
            case retract(stanzaId: String)
            // this message was retracted by moderator
            case retracted(retractionTimestmap: Date)
        }

        public let moderator: JID;
        public let retraction: Retraction;
        public let reason: String?;
        
        public init(retraction: Retraction, by moderator: JID, reason: String?) {
            self.moderator = moderator;
            self.retraction = retraction;
            self.reason = reason;
        }
        
    }
    
    
    public var moderated: Moderation? {
        guard let applyTo = firstChild(name: "apply-to", xmlns: "urn:xmpp:fasten:0"), let stanzaId = applyTo.attribute("id"), let moderated = applyTo.firstChild(name: "moderated", xmlns: "urn:xmpp:message-moderate:0"), let moderatedBy = JID(moderated.attribute("by")), moderated.firstChild(name: "retract", xmlns: "urn:xmpp:message-retract:0") != nil && from?.resource == nil else {

            guard let moderated = firstChild(name: "moderated", xmlns: "urn:xmpp:message-moderate:0"), let moderatedBy = JID(moderated.attribute("by")), let retracted = moderated.firstChild(name: "retracted", xmlns: "urn:xmpp:message-retract:0"), let stamp = TimestampHelper.parse(timestamp: retracted.attribute("stamp")) else {
                return nil;
            }
            return .init(retraction: .retracted(retractionTimestmap: stamp), by: moderatedBy, reason: moderated.firstChild(name: "reason")?.value);
        }
     
        return .init(retraction: .retract(stanzaId: stanzaId), by: moderatedBy, reason: moderated.firstChild(name: "reason")?.value);
    }
        
}

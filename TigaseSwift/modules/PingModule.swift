//
// PingModule.swift
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

public class PingModule: AbstractIQModule, ContextAware {
  
    private static let PING_XMLNS = "urn:xmpp:ping";
    
    public static let ID = PING_XMLNS;
    
    public let id = ID;
    
    public var context: Context!;
    
    public let criteria = Criteria.name("iq").add(Criteria.name("ping", xmlns: PING_XMLNS));
    
    public let features = [PING_XMLNS];
    
    public init() {
        
    }
    
    public func ping(jid: JID, stanza: (Stanza?)->Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = jid;
        iq.addChild(Element(name: "ping", xmlns: PingModule.PING_XMLNS));
        
        context.writer?.write(iq);
    }
    
    public func processGet(stanza: Stanza) throws {
        let result = stanza.makeResult(StanzaType.result);
        context.writer?.write(result);
    }
    
    public func processSet(stanza: Stanza) throws {
        throw ErrorCondition.not_allowed;
    }
}
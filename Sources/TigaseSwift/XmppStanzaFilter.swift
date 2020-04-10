//
// XmppStanzaFilter.swift
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

/**
 Protocol implemented by `XmppModule` which requires to process and filter 
 stanzas before other modules will process it.
 */
public protocol XmppStanzaFilter: class {
    
    /**
     Filters incoming packet and returns true if packet should not be processed any more
     
     - parameter stanza: Incoming stanza
     
     - returns: false - to keep processing or true to stop processing
     */
    func processIncoming(stanza:Stanza) -> Bool;
    
    /**
     Filters outgoing stanza by processing it
     */
    func processOutgoing(stanza:Stanza);
}

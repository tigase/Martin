//
// Message+Mix.swift
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
    
    /// Returns information about MIX (nickname, sender jid, etc.)
    open var mix:Mix? {
        if let mixEl = element.findChild(name: "mix", xmlns: MixModule.CORE_XMLNS) {
            return Mix(element: mixEl);
        }
        return nil;
    }

    open class Mix {
        public let nickname: String?;
        public let jid: BareJID?;
        
        public init(nickname: String?, jid: BareJID?) {
            self.nickname = nickname;
            self.jid = jid;
        }
        
        public convenience init(element: Element) {
            self.init(nickname: element.findChild(name: "nick")?.value, jid: BareJID(element.findChild(name: "jid")?.value));
        }
    }
    
}

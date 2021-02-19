//
// Logger+XMPP.swift
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
import TigaseLogging

extension LogMessageInterpolation {
    
    /**
        Method adds supoprt for logging Context as a bare JID or domain if bare JID is not set
     */
    public mutating func appendInterpolation(_ supplier: @autoclosure @escaping ()->Context, privacy: LogPrivacy = .auto(mask: .hash)) {
        append(supplier: { supplier().userBareJid.stringValue }, privacy: privacy);
    }

    /**
        Method adds supoprt for logging BareJID? (uses privacy .auto: mask: .hash) by default
     */
    public mutating func appendInterpolation(_ supplier: @autoclosure @escaping ()->BareJID?, privacy: LogPrivacy = .auto(mask: .hash)) {
        append(supplier: { supplier()?.stringValue ?? "--" }, privacy: privacy);
    }

    /**
        Method adds supoprt for logging JID? (uses privacy .auto: mask: .hash) by default
     */
    public mutating func appendInterpolation(_ supplier: @autoclosure @escaping ()->JID?, privacy: LogPrivacy = .auto(mask: .hash)) {
        append(supplier: { supplier()?.stringValue ?? "--" }, privacy: privacy);
    }

}

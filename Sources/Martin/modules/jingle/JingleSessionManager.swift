//
// JingleSessionManager.swift
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

public protocol JingleSessionManager {

    func sessionInitiated(for context: Context, with jid: JID, sid: String, contents: [Jingle.Content], bundle: Jingle.Bundle?) throws

    func sessionAccepted(for context: Context, with jid: JID, sid: String, contents: [Jingle.Content], bundle: Jingle.Bundle?) throws
    
    func sessionTerminated(for context: Context, with jid: JID, sid: String) throws
    
    func transportInfo(for context: Context, with jid: JID, sid: String, contents: [Jingle.Content]) throws
    
    func messageInitiation(for context: Context, from jid: JID, action: Jingle.MessageInitiationAction) throws
    
    func contentModified(for context: Context, with jid: JID, sid: String, action: Jingle.ContentAction, contents: [Jingle.Content], bundle: Jingle.Bundle?) throws
    
    func sessionInfo(for context: Context, with jid: JID, sid: String, info: [Jingle.SessionInfo]) throws
}

extension JingleSessionManager {
    
    func sessionInfo(for context: Context, with jid: JID, sid: String, info: [Jingle.SessionInfo]) throws {
        // nothing to do..
    }
    
}

//
// ConnectionConfiguration.swift
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

public class ConnectionConfiguration {
    
    var sessionObject:SessionObject!;
    
    init(_ sessionObject:SessionObject) {
        self.sessionObject = sessionObject;
    }
    
    public func setDomain(domain: String?) {
        self.sessionObject.setUserProperty(SessionObject.DOMAIN_NAME, value: domain);
    }
    
    public func setUserJID(jid:BareJID?) {
        self.sessionObject.setUserProperty(SessionObject.USER_BARE_JID, value: jid);
        setDomain(nil);
    }
    
    public func setUserPassword(password:String?) {
        self.sessionObject.setUserProperty(SessionObject.PASSWORD, value: password);
    }

    public func setServerHost(serverHost: String?) {
        self.sessionObject.setUserProperty(SocketConnector.SERVER_HOST, value: serverHost);
    }
    
}
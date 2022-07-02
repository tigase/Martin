//
// SoftwareVersionModule.swift
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

extension XmppModuleIdentifier {
    public static var softwareVersion: XmppModuleIdentifier<SoftwareVersionModule> {
        return SoftwareVersionModule.IDENTIFIER;
    }
}

/**
 Module provides support for [XEP-0092: Software Version]
 
 [XEP-0092: Software Version]: https://xmpp.org/extensions/xep-0092.html
 */
open class SoftwareVersionModule: XmppModuleBase, AbstractIQModule {
    
    public static let DEFAULT_NAME_VAL = "Tigase based software";
        
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "softwareVersion";
    public static let IDENTIFIER = XmppModuleIdentifier<SoftwareVersionModule>();
    
    public let criteria = Criteria.name("iq").add(Criteria.name("query", xmlns: "jabber:iq:version"));
    
    public let features = [ "jabber:iq:version" ];

    public let version: SoftwareVersion;
    
    public init(version: SoftwareVersion = SoftwareVersion(name: "Tigase based software", version: "0.0.0", os: nil)) {
        self.version = version;
    }
    
    public class SoftwareVersion {
        public let name: String;
        public let version: String;
        public let os: String?;
        
        public init(name: String, version: String, os: String?) {
            self.name = name;
            self.version = version;
            self.os = os;
        }
    }
    
    /**
     Retrieve version of software used by recipient
     - parameter for: address for which we want to retrieve software version
     */
    open func checkSoftwareVersion(for jid:JID) async throws -> SoftwareVersion {
        let iq = Iq(type: .get, to: jid, {
            Element(name:"query", xmlns:"jabber:iq:version")
        });
        
        let response = try await write(iq: iq);
        guard let query = response.firstChild(name: "query", xmlns: "jabber:iq:version"), let name = query.firstChild(name: "name")?.value, let version = query.firstChild(name: "version")?.value else {
            throw XMPPError(condition: .undefined_condition, stanza: response);
        }
        let os = query.firstChild(name: "os")?.value;
        return SoftwareVersion(name: name, version: version, os: os);
    }
    
    /**
     Method processes incoming stanzas
     - parameter stanza: stanza to process
     */
    open func processGet(stanza: Stanza) throws {
        let result = stanza.makeResult(type: StanzaType.result);
        
        let query = Element(name: "query", xmlns: "jabber:iq:version");
        result.addChild(query);
        
        query.addChild(Element(name: "name", cdata: version.name));
        query.addChild(Element(name: "version", cdata: version.version));
        if let os = version.os {
            query.addChild(Element(name: "os", cdata: os));
        }
        
        write(stanza: result);
    }
    
    open func processSet(stanza: Stanza) throws {
        throw XMPPError(condition: .not_allowed);
    }
}

// async-await support
extension SoftwareVersionModule {
    open func checkSoftwareVersion(for jid: JID, completionHandler: @escaping (Result<SoftwareVersion,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await checkSoftwareVersion(for: jid)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

}

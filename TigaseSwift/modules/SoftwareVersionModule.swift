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

/**
 Module provides support for [XEP-0092: Software Version]
 
 [XEP-0092: Software Version]: https://xmpp.org/extensions/xep-0092.html
 */
public class SoftwareVersionModule: AbstractIQModule, ContextAware {
    
    public static let DEFAULT_NAME_VAL = "Tigase based software";
    
    /**
     Property under which name of software is stored in `SessionObject`
     */
    public static let NAME_KEY = "softwareVersionName";
    /**
     Property under which name of operation system is stored in `SessionObject`
     */
    public static let OS_KEY = "softwareVersionOS";
    /**
     Property under which version of software is stored in `SessionObject`
     */
    public static let VERSION_KEY = "softwareVersionVersion";
    
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "softwareVersion";
    
    public let id = ID;
    
    public var context:Context!;
    
    public let criteria = Criteria.name("iq").add(Criteria.name("query", xmlns: "jabber:iq:version"));
    
    public let features = [ "jabber:iq:version" ];

    public init() {
        
    }
    
    /**
     Retrieve version of software used by recipient
     - parameter jid: address for which we want to retrieve software version
     - parameter callback: called on response or failure
     */
    public func checkSoftwareVersion(jid:JID, callback:(Stanza?)->Void) {
        var iq = Iq();
        iq.to = jid;
        iq.type = StanzaType.get;
        iq.addChild(Element(name:"query", xmlns:"jabber:iq:version"));

        context.writer?.write(iq, callback:callback);
    }
    
    /**
     Retrieve version of software used by recipient
     - parameter jid: address for which we want to retrieve software version
     - parameter onResult: called on successful response
     - parameter onError: called failure or request timeout
     */
    public func checkSoftwareVersion(jid:JID, onResult:(name:String?, version:String?, os:String?)->Void, onError:(errorCondition:ErrorCondition?)->Void) {
        checkSoftwareVersion(jid) { (stanza) in
            var type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                let query = stanza?.findChild("query", xmlns: "jabber:iq:version");
                let name = query?.findChild("name")?.value;
                let version = query?.findChild("version")?.value;
                let os = query?.findChild("os")?.value;
                onResult(name: name, version: version, os: os);
            default:
                var errorCondition = stanza?.errorCondition;
                onError(errorCondition: errorCondition);
            }
        }
    }
    
    /**
     Method processes incoming stanzas
     - parameter stanza: stanza to process
     */
    public func processGet(stanza: Stanza) throws {
        var result = stanza.makeResult(StanzaType.result);
        
        var query = Element(name: "query", xmlns: "jabber:iq:version");
        result.addChild(query);
        
        let name = context.sessionObject.getProperty(SoftwareVersionModule.NAME_KEY, defValue: SoftwareVersionModule.DEFAULT_NAME_VAL);
        query.addChild(Element(name: "name", cdata: name));
        let version = context.sessionObject.getProperty(SoftwareVersionModule.VERSION_KEY, defValue: "0.0.0");
        query.addChild(Element(name: "version", cdata: version));
        if let os:String = context.sessionObject.getProperty(SoftwareVersionModule.OS_KEY) {
            query.addChild(Element(name: "os", cdata: os));
        }
        
        context.writer?.write(result);
    }
    
    public func processSet(stanza: Stanza) throws {
        throw ErrorCondition.not_allowed;
    }
}
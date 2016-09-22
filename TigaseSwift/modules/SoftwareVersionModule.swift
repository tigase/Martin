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
open class SoftwareVersionModule: AbstractIQModule, ContextAware {
    
    open static let DEFAULT_NAME_VAL = "Tigase based software";
    
    /**
     Property under which name of software is stored in `SessionObject`
     */
    open static let NAME_KEY = "softwareVersionName";
    /**
     Property under which name of operation system is stored in `SessionObject`
     */
    open static let OS_KEY = "softwareVersionOS";
    /**
     Property under which version of software is stored in `SessionObject`
     */
    open static let VERSION_KEY = "softwareVersionVersion";
    
    /// ID of module for lookup in `XmppModulesManager`
    open static let ID = "softwareVersion";
    
    open let id = ID;
    
    open var context:Context!;
    
    open let criteria = Criteria.name("iq").add(Criteria.name("query", xmlns: "jabber:iq:version"));
    
    open let features = [ "jabber:iq:version" ];

    public init() {
        
    }
    
    /**
     Retrieve version of software used by recipient
     - parameter for: address for which we want to retrieve software version
     - parameter callback: called on response or failure
     */
    open func checkSoftwareVersion(for jid:JID, callback: @escaping (Stanza?)->Void) {
        let iq = Iq();
        iq.to = jid;
        iq.type = StanzaType.get;
        iq.addChild(Element(name:"query", xmlns:"jabber:iq:version"));

        context.writer?.write(iq, callback: callback);
    }
    
    /**
     Retrieve version of software used by recipient
     - parameter for: address for which we want to retrieve software version
     - parameter onResult: called on successful response
     - parameter onError: called failure or request timeout
     */
    open func checkSoftwareVersion(for jid:JID, onResult: @escaping (_ name:String?, _ version:String?, _ os:String?)->Void, onError: @escaping (_ errorCondition:ErrorCondition?)->Void) {
        checkSoftwareVersion(for: jid) { (stanza) in
            let type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                let query = stanza?.findChild(name: "query", xmlns: "jabber:iq:version");
                let name = query?.findChild(name: "name")?.value;
                let version = query?.findChild(name: "version")?.value;
                let os = query?.findChild(name: "os")?.value;
                onResult(name, version, os);
            default:
                let errorCondition = stanza?.errorCondition;
                onError(errorCondition);
            }
        }
    }
    
    /**
     Method processes incoming stanzas
     - parameter stanza: stanza to process
     */
    open func processGet(stanza: Stanza) throws {
        let result = stanza.makeResult(type: StanzaType.result);
        
        let query = Element(name: "query", xmlns: "jabber:iq:version");
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
    
    open func processSet(stanza: Stanza) throws {
        throw ErrorCondition.not_allowed;
    }
}

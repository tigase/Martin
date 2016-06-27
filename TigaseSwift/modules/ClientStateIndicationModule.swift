//
// ClientStateIndicationModule.swift
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
 Module provides support for [XEP-0352: Client State Inidication] feature
 
 [XEP-0352: Client State Inidication]:https://xmpp.org/extensions/xep-0352.html
 */
public class ClientStateIndicationModule: XmppModule, ContextAware {
    
    /// Client State Indication XMLNS
    public static let CSI_XMLNS = "urn:xmpp:csi:0";
    /// ID of module to lookup for in `XmppModulesManager`
    public static let ID = CSI_XMLNS;
    
    public let id = CSI_XMLNS;
    
    public let criteria = Criteria.empty();
    
    public let features = [String]();
    
    public var context:Context!;
    
    /// Available optimization modes on server
    public var available: Bool {
        get {
            return StreamFeaturesModule.getStreamFeatures(context.sessionObject)!.findChild("csi", xmlns: ClientStateIndicationModule.CSI_XMLNS) != nil;
        }
    }
    
    public init() {
    }
    
    public func process(elem: Stanza) throws {
        throw ErrorCondition.feature_not_implemented;
    }
    
    /**
     Informs server that client is in active state
     */
    public func active() {
        setState(true);
    }
    
    /**
     Informs server that client is in inactive state
     */
    public func inactive() {
        setState(false);
    }
    
    /**
     Set state of client
     - paramater active: pass true if client is in active state
     */
    public func setState(state: Bool) -> Bool {
        if (self.available) {
            let stanza = Stanza(name: state ? "active" : "inactive");
            stanza.element.xmlns = ClientStateIndicationModule.CSI_XMLNS;
            context.writer?.write(stanza);
            return true;
        }
        return false;
    }
    
}

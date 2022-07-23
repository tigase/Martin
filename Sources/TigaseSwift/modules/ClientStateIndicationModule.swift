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

extension XmppModuleIdentifier {
    public static var csi: XmppModuleIdentifier<ClientStateIndicationModule> {
        return ClientStateIndicationModule.IDENTIFIER;
    }
}

extension StreamFeatures.StreamFeature {
    public static let csi = StreamFeatures.StreamFeature(name: "csi", xmlns: ClientStateIndicationModule.CSI_XMLNS);
}

/**
 Module provides support for [XEP-0352: Client State Inidication] feature
 
 [XEP-0352: Client State Inidication]:https://xmpp.org/extensions/xep-0352.html
 */
open class ClientStateIndicationModule: XmppModuleBase, XmppModule, Resetable {
    
    /// Client State Indication XMLNS
    public static let CSI_XMLNS = "urn:xmpp:csi:0";
    /// ID of module to lookup for in `XmppModulesManager`
    public static let ID = CSI_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<ClientStateIndicationModule>();
    
    public let features = [String]();
        
    open private(set) var state: Bool = false;
    
    open override var context: Context? {
        didSet {
            store(context?.module(.streamFeatures).$streamFeatures.map({ $0.contains(.csi) }).assign(to: \.available, on: self));
        }
    }
    
    /// Available optimization modes on server
    open private(set) var available: Bool = false;
    
    public override init() {
    }
        
    open func reset(scopes: Set<ResetableScope>) {
        if scopes.contains(.session) {
            state = false;
        }
    }
    
    /**
     Informs server that client is in active state
     */
    open func active() {
        _ = setState(true);
    }
    
    /**
     Informs server that client is in inactive state
     */
    open func inactive() {
        _ = setState(false);
    }
    
    /**
     Set state of client
     - paramater active: pass true if client is in active state
     */
    open func setState(_ state: Bool) -> Bool {
        guard state != state else {
            return false;
        }
        if (self.available) {
            self.state = state;
            let stanza = Stanza(name: state ? "active" : "inactive");
            stanza.element.xmlns = ClientStateIndicationModule.CSI_XMLNS;
            write(stanza: stanza);
            return true;
        }
        return false;
    }
    
}

// async-await support
extension ClientStateIndicationModule {
    
    public enum ClientState: String {
        case active
        case inactive
        
        var value: Bool {
            switch self {
            case .active:
                return true;
            case .inactive:
                return false;
            }
        }
    }
    
    open func setState(_ state: ClientState) async throws -> Bool {
        guard self.available else {
            throw XMPPError(condition: .feature_not_implemented);
        }
        guard state != state else {
            return false;
        }
        self.state = state.value;
        let stanza = Stanza(name: state.rawValue);
        stanza.element.xmlns = ClientStateIndicationModule.CSI_XMLNS;
        try await write(stanza: stanza);
        return true;
    }
    
}

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

/**
 Module provides support for [XEP-0352: Client State Inidication] feature
 
 [XEP-0352: Client State Inidication]:https://xmpp.org/extensions/xep-0352.html
 */
open class ClientStateIndicationModule: XmppModule, ContextAware, EventHandler {
    
    /// Client State Indication XMLNS
    public static let CSI_XMLNS = "urn:xmpp:csi:0";
    /// ID of module to lookup for in `XmppModulesManager`
    public static let ID = CSI_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<ClientStateIndicationModule>();
    
    public let criteria = Criteria.empty();
    
    public let features = [String]();
    
    open var context:Context! {
        didSet {
            if context != nil {
                context.eventBus.register(handler: self, for: [StreamManagementModule.FailedEvent.TYPE, SocketConnector.DisconnectedEvent.TYPE]);
            } else if oldValue != nil {
                oldValue.eventBus.unregister(handler: self, for: [StreamManagementModule.FailedEvent.TYPE, SocketConnector.DisconnectedEvent.TYPE]);
            }
        }
    }
    
    fileprivate var _state: Bool = true;
    open var state: Bool {
        return _state;
    }
    
    /// Available optimization modes on server
    open var available: Bool {
        get {
            return StreamFeaturesModule.getStreamFeatures(context.sessionObject)!.findChild(name: "csi", xmlns: ClientStateIndicationModule.CSI_XMLNS) != nil;
        }
    }
    
    public init() {
    }
    
    public func handle(event: Event) {
        switch event {
        case let e as SocketConnector.DisconnectedEvent:
            if e.clean {
                _state = false;
            }
        case _ as StreamManagementModule.FailedEvent:
            _state = false;
        default:
            break;
        }
    }
    
    open func process(stanza: Stanza) throws {
        throw ErrorCondition.feature_not_implemented;
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
        guard _state != state else {
            return false;
        }
        if (self.available) {
            _state = state;
            let stanza = Stanza(name: state ? "active" : "inactive");
            stanza.element.xmlns = ClientStateIndicationModule.CSI_XMLNS;
            context.writer?.write(stanza);
            return true;
        }
        return false;
    }
    
}

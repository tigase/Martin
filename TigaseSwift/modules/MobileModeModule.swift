//
// MobileModeModule.swift
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
 Module provides support for Tigase Mobile Optimizations feature
 */
open class MobileModeModule: XmppModule, ContextAware, EventHandler {
    
    /// Base part of namespace used by Mobile Optimizations
    open static let MM_XMLNS = "http://tigase.org/protocol/mobile";
    /// ID of module to lookup for in `XmppModulesManager`
    open static let ID = MM_XMLNS;
    
    open let id = MM_XMLNS;
    
    open let criteria = Criteria.empty();
    
    open let features = [String]();
    
    open var context:Context! {
        didSet {
            if context != nil {
                context.eventBus.register(handler: self, for: [StreamManagementModule.FailedEvent.TYPE, SocketConnector.DisconnectedEvent.TYPE]);
            } else if oldValue != nil {
                oldValue.eventBus.unregister(handler: self, for: [StreamManagementModule.FailedEvent.TYPE, SocketConnector.DisconnectedEvent.TYPE]);
            }
        }
    }
    
    fileprivate var _activeMode: Mode? = nil;
    open var activeMode: Mode? {
        return _activeMode;
    }
    
    /// Available optimization modes on server
    open var availableModes:[Mode] {
        get {
            return (StreamFeaturesModule.getStreamFeatures(context.sessionObject)!.mapChildren(transform: {(f)-> Mode in
                return Mode(rawValue: f.xmlns!)!
                }, filter: { (f) -> Bool in
                    return f.name == "mobile" && f.xmlns != nil && Mode(rawValue: f.xmlns!) != nil;
            }));
        }
    }
    
    public init() {
    }
    
    public func handle(event: Event) {
        switch event {
        case let e as SocketConnector.DisconnectedEvent:
            if e.clean {
                _activeMode = nil;
            }
        case _ as StreamManagementModule.FailedEvent:
            _activeMode = nil;
        default:
            break;
        }
    }
    
    open func process(stanza: Stanza) throws {
        throw ErrorCondition.feature_not_implemented;
    }
    
    /**
     Enable optimization mode
     - paramater mode: mode to use
     */
    open func enable(mode: Mode? = nil) {
        _ = setState(true, mode: mode);
    }
    
    /**
     Disable optimization mode
     - paramater mode: mode to disable
     */
    open func disable(mode: Mode? = nil) {
        _ = setState(false, mode: mode);
    }
    
    /**
     Enable/disable optimization mode
     - paramater mode: mode to use
     */
    open func setState(_ state: Bool, mode: Mode? = nil) -> Bool {
        if mode == nil {
            let possibleModes = availableModes;
            for m in Mode.allValues {
                if possibleModes.contains(m) {
                    return setState(state, mode: m);
                }
            }
            return false;
        }
        if availableModes.contains(mode!) && (activeMode == nil || activeMode! == mode!) {
            _activeMode = mode;
            let iq = Iq();
            iq.type = StanzaType.set;
            let mobile = Element(name: "mobile", xmlns: mode!.rawValue);
            mobile.setAttribute("enable", value: state ? "true" : "false");
            iq.addChild(mobile);
            context.writer?.write(iq);
            return true;
        }
        return false;
    }
    
    /**
     Supported modes/versions
     */
    public enum Mode: String {
        case V1 = "http://tigase.org/protocol/mobile#v1";
        case V2 = "http://tigase.org/protocol/mobile#v2";
        case V3 = "http://tigase.org/protocol/mobile#v3";
        
        public static let allValues = [ V3, V2, V1 ];
    }
}

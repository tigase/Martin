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
@available(*, deprecated, message: "This custom extension implementation module should be replaced by use of ClientStateIndicationModule")
open class MobileModeModule: XmppModuleBase, XmppModule, Resetable {
    
    /// Base part of namespace used by Mobile Optimizations
    public static let MM_XMLNS = "http://tigase.org/protocol/mobile";
    /// ID of module to lookup for in `XmppModulesManager`
    public static let ID = MM_XMLNS;
    
    public let id = MM_XMLNS;
        
    public let features = [String]();
        
    open private(set) var activeMode: Mode?;
    
    /// Available optimization modes on server
    open private(set) var availableModes:[Mode] = [];
    
    open override var context: Context? {
        didSet {
            store(
                context?.module(.streamFeatures).$streamFeatures.map({ $0.element?.compactMapChildren(Mode.from(element:)) ?? [] }).assign(to: \.availableModes, on: self));
        }
    }
    
    public override init() {
    }
    
    open func reset(scopes: Set<ResetableScope>) {
        if scopes.contains(.session) {
            activeMode = nil;
        }
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
            activeMode = mode;
            let iq = Iq(type: .set);
            let mobile = Element(name: "mobile", xmlns: mode!.rawValue);
            mobile.attribute("enable", newValue: state ? "true" : "false");
            iq.addChild(mobile);
            write(stanza: iq);
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
    
        public static func from(element: Element) -> Mode? {
            guard let xmlns = element.xmlns else {
                return nil;
            }
            
            return Mode(rawValue: xmlns);
        }
    }
}

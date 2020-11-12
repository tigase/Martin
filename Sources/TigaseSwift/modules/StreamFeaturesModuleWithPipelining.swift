//
// StreamFeaturesModuleWithPipelining
//
// TigaseSwift
// Copyright (C) 2018 "Tigase, Inc." <office@tigase.com>
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

open class StreamFeaturesModuleWithPipelining: StreamFeaturesModule, EventHandler {
    
    open var cache: StreamFeaturesModuleWithPipeliningCacheProtocol?;
    
    fileprivate var newCachedFeatures = [Element]();
    
    open private(set) var active: Bool = false;
    open var enabled: Bool = false;
    
    override open weak var context: Context? {
        willSet {
            context?.eventBus.unregister(handler: self, for: [SocketSessionLogic.ErrorEvent.TYPE, SocketConnector.DisconnectedEvent.TYPE, SessionEstablishmentModule.SessionEstablishmentSuccessEvent.TYPE, AuthModule.AuthFailedEvent.TYPE]);
        }
        didSet {
            context?.eventBus.register(handler: self, for: [SocketSessionLogic.ErrorEvent.TYPE, SocketConnector.DisconnectedEvent.TYPE, SessionEstablishmentModule.SessionEstablishmentSuccessEvent.TYPE, AuthModule.AuthFailedEvent.TYPE]);
        }
    }
    
    fileprivate var counter = 0;
    
    public init(cache: StreamFeaturesModuleWithPipeliningCacheProtocol?, enabled: Bool = false) {
        self.cache = cache;
        self.enabled = enabled;
        super.init();
    }
    
    override open func process(stanza: Stanza) throws {
        if enabled {
            newCachedFeatures.append(stanza.element);
        }
        if !active {
            try super.process(stanza: stanza);
        }
    }
    
    func connectionRestarted() {
        counter = 0;
        newCachedFeatures.removeAll();
    }
    
    func streamStarted() {
        if enabled, let context = context, let cached = cache?.getFeatures(for: context, embeddedStreamNo: counter) {
            active = true;
            setStreamFeatures(cached);
        } else {
            active = false;
        }
        counter = counter + 1;
    }
 
    public func handle(event: Event) {
        switch event {
        case let e as SessionEstablishmentModule.SessionEstablishmentSuccessEvent:
            let pipeliningSupported = newCachedFeatures.count > 0 && newCachedFeatures.count == newCachedFeatures.filter({ features in
                return features.findChild(name: "pipelining", xmlns: "urn:xmpp:features:pipelining") != nil;
            }).count;
            cache?.set(for: e.context, features: pipeliningSupported ? newCachedFeatures : nil);
            newCachedFeatures.removeAll();
        case let e as SocketSessionLogic.ErrorEvent:
            connectionRestarted();
            cache?.set(for: e.context, features: nil);
        case is SocketConnector.DisconnectedEvent:
            connectionRestarted();
        case let e as AuthModule.AuthFailedEvent:
            connectionRestarted();
            cache?.set(for: e.context, features: nil);
        default:
            break;
        }
    }

}

public protocol StreamFeaturesModuleWithPipeliningCacheProtocol {
    
    func getFeatures(for: Context, embeddedStreamNo: Int) -> Element?;
    
    func set(for: Context, features: [Element]?);
    
}

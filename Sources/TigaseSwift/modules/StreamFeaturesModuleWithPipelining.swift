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
import Combine

open class StreamFeaturesModuleWithPipelining: StreamFeaturesModule {
    
    open var cache: StreamFeaturesModuleWithPipeliningCacheProtocol?;
    
    fileprivate var newCachedFeatures = [Element]();
    
    open private(set) var active: Bool = false;
    open var enabled: Bool = false;
    
    private var cancellable: Cancellable?;
    
    override open weak var context: Context? {
        willSet {
            cancellable?.cancel();
        }
        didSet {
            cancellable = context?.module(.auth).$state.filter({ $0.isError }).sink(receiveValue: { [weak self] _ in
                self?.authFailed();
            });
        }
    }
    
    fileprivate var counter = 0;
    
    public init(cache: StreamFeaturesModuleWithPipeliningCacheProtocol?, enabled: Bool = false) {
        self.cache = cache;
        self.enabled = enabled;
        super.init();
    }
    
    deinit {
        cancellable?.cancel();
    }
    
    public override func reset(scopes: Set<ResetableScope>) {
        super.reset(scopes: scopes);
        if scopes.contains(.stream) {
            connectionRestarted();
        }
    }
    
    override open func process(stanza: Stanza) throws {
        if enabled {
            newCachedFeatures.append(stanza.element);
        }
        if !active {
            try super.process(stanza: stanza);
        }
    }
    
    private func authFailed() {
        connectionRestarted();
        if let context = self.context {
            cache?.set(for: context, features: nil);
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
    
    open override func stateChanged(newState: SocketConnector.State) {
        guard let context = self.context else {
            return;
        }
        
        switch newState {
        case .connected:
            let pipeliningSupported = newCachedFeatures.count > 0 && newCachedFeatures.count == newCachedFeatures.filter({ features in
                return features.findChild(name: "pipelining", xmlns: "urn:xmpp:features:pipelining") != nil;
            }).count;
            cache?.set(for: context, features: pipeliningSupported ? newCachedFeatures : nil);
            newCachedFeatures.removeAll();
        case .disconnected(let reason):
            if case .streamError(_) = reason {
                self.connectionRestarted();
                self.cache?.set(for: context, features: nil);
            }
        default:
            break;
        }
    }
 

}

public protocol StreamFeaturesModuleWithPipeliningCacheProtocol {
    
    func getFeatures(for: Context, embeddedStreamNo: Int) -> Element?;
    
    func set(for: Context, features: [Element]?);
    
}

//
// Reachability.swift
//
// TigaseSwift
// Copyright (C) 2017 "Tigase, Inc." <office@tigase.com>
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
import SystemConfiguration

open class Reachability {
    
    open static let CONNECTIVITY_CHANGED = Notification.Name("messengerConnectivityChanged");

    fileprivate var previousFlags: SCNetworkReachabilityFlags?;
    fileprivate let reachability: SCNetworkReachability;
    
    open var flags: SCNetworkReachabilityFlags {
        var flags = SCNetworkReachabilityFlags();
        if SCNetworkReachabilityGetFlags(reachability, &flags) {
            return flags;
        } else {
            return SCNetworkReachabilityFlags();
        }
    }
    
    open var isReachable: Bool {
        return isConnectedToNetwork();
    }
    
    public convenience init() {
        var zeroAddress = sockaddr();
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size);
        zeroAddress.sa_family = sa_family_t(AF_INET);
        let reachability = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress)!;
        self.init(reachability: reachability);
    }
    
    public convenience init(hostname: String) {
        let reachability = SCNetworkReachabilityCreateWithName(nil, hostname)!;
        self.init(reachability: reachability);
    }

    public init(reachability: SCNetworkReachability) {
        self.reachability = reachability;
        var context = SCNetworkReachabilityContext();
        context.info = UnsafeMutableRawPointer(Unmanaged<Reachability>.passUnretained(self).toOpaque());
        SCNetworkReachabilitySetCallback(reachability, { (reachability, flags, info) in
            Reachability.reachabilityCallback(reachability: reachability, flags: flags, info: info);
        }, &context);
        SCNetworkReachabilityScheduleWithRunLoop(self.reachability, RunLoop.current.getCFRunLoop(), RunLoopMode.defaultRunLoopMode as CFString);
        
        reachabilityChanged();
    }
    
    fileprivate func reachabilityChanged() {
        guard previousFlags != flags else {
            return;
        }
        NotificationCenter.default.post(name: Reachability.CONNECTIVITY_CHANGED, object: self);
        previousFlags = flags;
    }
    
    open func isConnectedToNetwork() -> Bool {
        return isConnectedToNetwork(flags);
    }
    
    open func isConnectedToNetwork(_ flags:SCNetworkReachabilityFlags) -> Bool {
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0;
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0;
        return isReachable && !needsConnection;
    }
    
    fileprivate static func reachabilityCallback(reachability:SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) {
        
        guard let info = info else { return }
        
        let reachability = Unmanaged<Reachability>.fromOpaque(info).takeUnretainedValue()
        reachability.reachabilityChanged()
    }
    
}

//
// UnfairLock.swift
//
// TigaseSwift
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
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
import os

open class UnfairLock<State>: @unchecked Sendable {
    
    private let lockFn: () -> Void;
    private let unlockFn: () -> Void;
    private var state: State;
    
    public init(state: State) {
        self.state = state;
        (lockFn, unlockFn) = createUnfairLock(initialState: state);
    }
    
    public func with<R>(_ body: (inout State) -> R) -> R {
        lockFn();
        defer {
            unlockFn();
        }
        return body(&state);
    }

    public func with<R>(_ body: (inout State) throws -> R) rethrows -> R {
        lockFn();
        defer {
            unlockFn();
        }
        return try body(&state);
    }

}

extension UnfairLock where State == Void {
    
    public convenience init() {
        self.init(state: ())
    }

    public func lock() {
        lockFn()
    }
    
    public func unlock() {
        unlockFn();
    }
    
    public func with<T>(_ body: () -> T) -> T {
        lock();
        defer {
            unlock();
        }
        return body();
    }
    
    public func with<T>(_ body: () throws -> T) rethrows -> T {
        lock();
        defer {
            unlock();
        }
        return try body();
    }

}



private func createUnfairLock<State>(initialState: State) -> (()->Void,()->Void) {
    if #available(iOS 16.0, macOS 13.0, *) {
        let lock = OSAllocatedUnfairLock();
        return ( lock.lock, lock.unlock )
    } else {
        var lock = os_unfair_lock();
        return ({ os_unfair_lock_lock(&lock) }, { os_unfair_lock_unlock(&lock) });
    }
}

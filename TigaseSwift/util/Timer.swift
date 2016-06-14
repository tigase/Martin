//
// Timer.swift
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
 Implementation of timer for easier use. It is based on NSTimer/
 */
public class Timer: NSObject {
    
    /// Interval set for this timer
    public let timeout: NSTimeInterval;
    private var timer: NSTimer?
    /// Callback execute when timer is fired
    public var callback: (Void ->Void)?
    /// True if timer is repeating execution many times
    public let repeats:Bool;
    
    /**
     Creates instance of Timer
     - parameter delayInSeconds: delay after which callback should be executed
     - parameter repeats: true if timer should be fired many times
     - parameter callback: executed when timer is fired
     */
    public init(delayInSeconds: NSTimeInterval, repeats: Bool, callback: Void->Void) {
        self.timeout = delayInSeconds;
        self.callback = callback;
        self.repeats = repeats;
        super.init();
        self.timer = NSTimer.scheduledTimerWithTimeInterval(delayInSeconds, target: self, selector: #selector(Timer.execute), userInfo: nil, repeats: repeats);
    }
    
    /**
     Method fire by NSTimer internally
     */
    public func execute() {
        callback?();
        if !repeats {
            cancel();
        }
    }
    
    /**
     Methods cancels timer
     */
    public func cancel() {
        callback = nil;
        timer?.invalidate()
        timer = nil;
    }
}
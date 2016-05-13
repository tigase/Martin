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

public class Timer: NSObject {
    
    private var timer: NSTimer?
    private var callback: (Void ->Void)?
    private var repeats:Bool;
    
    public init(delayInSeconds: NSTimeInterval, repeats: Bool, callback: Void->Void) {
        self.callback = callback;
        self.repeats = repeats;
        super.init();
        self.timer = NSTimer.scheduledTimerWithTimeInterval(delayInSeconds, target: self, selector: #selector(Timer.execute), userInfo: nil, repeats: repeats);
    }
    
    func execute() {
        callback?();
        if !repeats {
            cancel();
        }
    }
    
    public func cancel() {
        callback = nil;
        timer?.invalidate()
        timer = nil;
    }
}
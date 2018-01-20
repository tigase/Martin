//
// PacketWriter.swift
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
 Class defined to act as a protocol for classes extending it
 
 Needs to be a class due to default values for parameters.
 */

open class PacketWriter {
    
    /**
     Write packet to stream
     - parameter stanza: stanza to write
     */
    open func write(_ stanza: Stanza) {
        
    }
    
    /**
     Write packet to stream
     - parameter stanza: stanza to write
     - parameter timeout: timeout to wait for response
     - parameter callback: called when response is received or request timed out
     */
    open func write(_ stanza: Stanza, timeout: TimeInterval = 30, callback: ((Stanza?)->Void)?) {
    }
    
    /**
     Write packet to stream
     - parameter stanza: stanza to write
     - parameter timeout: timeout to wait for response
     - parameter onSuccess: called when successful response is received
     - parameter onError: called when failure response is received or request timed out
     */
    open func write(_ stanza: Stanza, timeout: TimeInterval = 30, onSuccess: ((Stanza)->Void)?, onError: ((Stanza,ErrorCondition?)->Void)?, onTimeout: (()->Void)?) {
    }
    
    /**
     Write packet to stream
     - parameter stanza: stanza to write
     - parameter timeout: timeout to wait for response
     - parameter callback: methods of this class are called when response is received or request timed out
     */
    open func write(_ stanza: Stanza, timeout: TimeInterval = 30, callback:AsyncCallback) {
    
    }
    
    open func execAfterWrite(handler: @escaping () -> Void) {
        
    }
}


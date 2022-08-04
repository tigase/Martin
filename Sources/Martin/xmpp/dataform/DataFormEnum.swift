//
// DataFormEnum.swift
//
// TigaseSwift
// Copyright (C) 2022 "Tigase, Inc." <office@tigase.com>
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

public protocol DataFormEnumProtocol {
    
}

public protocol DataFormEnum: RawRepresentable, LosslessStringConvertible, DataFormEnumProtocol where RawValue == String {

}

extension DataFormEnum {
    
    public var description: String {
        return rawValue;
    }
    
    public init?(_ description: String) {
        self.init(rawValue: description);
    }
}

extension DataForm {
    
    public enum IntegerOrMax: LosslessStringConvertible, Equatable, Sendable {
        case value(Int)
        case max
        
        
        
        public static func < (lhs: IntegerOrMax, rhs: Int) -> Bool {
            switch lhs {
            case .value(let lval):
                return lval < rhs;
            case .max:
                return false;
            }
        }
        
        public static func < (lhs: Int, rhs: IntegerOrMax) -> Bool {
            switch rhs {
            case .value(let rval):
                return lhs < rval;
            case .max:
                return true;
            }
        }
        
        public static func == (lhs: IntegerOrMax, rhs: IntegerOrMax) -> Bool {
            switch lhs {
            case .max:
                switch rhs {
                case .max:
                    return true;
                case .value(_):
                    return false;
                }
            case .value(let lval):
                switch rhs {
                case .max:
                    return true;
                case .value(let rval):
                    return lval == rval;
                }
            }
        }
        
        public var description: String {
            get {
                switch self {
                case .max:
                    return "max"
                case .value(let val):
                    return val.description;
                }
            }
        }
        
        public init?(_ description: String) {
            if description == "max" {
                self = .max;
            } else if let val = Int(description) {
                self = .value(val)
            } else {
                return nil;
            }
        }
        
    }
    
}

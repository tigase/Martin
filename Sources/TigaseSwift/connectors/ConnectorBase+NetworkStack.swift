//
// ConnectorBase+NetworkStack.swift
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

extension ConnectorBase {
    
    public final class NetworkStack: NetworkDelegate {
        private var processors: [NetworkProcessor] = [];
        
        public weak var delegate: NetworkDelegate?;
        
        init() {
        }
        
        public func reset() {
            self.processors.removeAll();
        }
        
        public func addProcessor(_ processor: NetworkProcessor) {
            guard let delegate = self.delegate else {
                return;
            }
            if let previous = self.processors.last {
                processor.readDelegate = delegate;
                previous.readDelegate = processor;
                processor.writeDelegate = previous
            } else {
                processor.readDelegate = delegate;
                processor.writeDelegate = delegate;
            }
            processors.append(processor);
        }
        
        public func write(data: Data, completion: WriteCompletion) {
            if let processor = processors.last {
                processor.write(data: data, completion: completion);
            } else {
                delegate?.write(data: data, completion: completion);
            }
        }
        
        public func read(data: Data) {
            if let processor = processors.first {
                processor.read(data: data);
            } else {
                delegate?.read(data: data);
            }
        }
    }

    open class NetworkProcessor: NetworkDelegate {
        
        fileprivate weak var readDelegate: NetworkReadDelegate?;
        fileprivate weak var writeDelegate: NetworkWriteDelegate?;

        public init() {
            
        }
        
        open func read(data: Data) {
            readDelegate?.read(data: data);
        }
        
        open func write(data: Data, completion: WriteCompletion) {
            writeDelegate?.write(data: data, completion: completion);
        }
        
    }

}

public protocol NetworkDelegate: NetworkReadDelegate, NetworkWriteDelegate {
    
    
}

public protocol NetworkReadDelegate: class {

    func read(data: Data);
    
}

public protocol NetworkWriteDelegate: class {
    
    func write(data: Data, completion: WriteCompletion);
    
}

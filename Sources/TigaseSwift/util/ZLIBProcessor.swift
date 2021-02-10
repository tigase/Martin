//
// ZLIBProcessor.swift
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

open class ZLIBProcessor: ConnectorBase.NetworkProcessor {
 
    private let zlib = Zlib(compressionLevel: .default, flush: .sync);
    
    public override init() {
        super.init();
    }
    
    open override func read(data: Data) {
        let decompressed = zlib.decompress(data: data);
        super.read(data: decompressed);
    }
    
    open override func write(data: Data, completion: WriteCompletion) {
        let compressed = zlib.compress(data: data);
        super.write(data: compressed, completion: completion);
    }
    
}

public struct ZLIBNetworkProtocolProvider: NetworkProcessorProvider {
    
    public let providedFeatures: [ConnectorFeature] = [.ZLIB];
    
    public init() {
        
    }
    
    public func supply() -> ConnectorBase.NetworkProcessor {
        return ZLIBProcessor();
    }
    
}



//
// SaslChannelBinding.swift
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

extension StreamFeatures.StreamFeature {
    
    public static let saslChannelBinding = StreamFeatures.StreamFeature(name: "sasl-channel-binding", xmlns: "urn:xmpp:sasl-cb:0");
    
}

extension StreamFeatures {
    
    public var saslChannelBinding: [ChannelBinding] {
        guard let bindings = get(.saslChannelBinding) else {
            return [];
        }
        return ChannelBinding.parse(element: bindings)
    }
        
}

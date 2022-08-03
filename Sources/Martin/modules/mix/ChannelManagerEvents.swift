//
// File.swift
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

struct ChannelManagerEvents {
    
    open class ChannelCreatedEvent: AbstractEvent {

        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ChannelCreatedEvent();

        public let channel: ChannelProtocol!;

        private init() {
            channel = nil;
            super.init(type: "MixChannelManagerChannelCreatedEvent")
        }

        public init(context: Context, channel: ChannelProtocol) {
            self.channel = channel;
            super.init(type: "MixChannelManagerChannelCreatedEvent", context: context)
        }
    }

    open class ChannelClosedEvent: AbstractEvent {

        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ChannelClosedEvent();

        public let channel: ChannelProtocol!;

        private init() {
            channel = nil;
            super.init(type: "MixChannelManagerChannelClosedEvent")
        }

        public init(context: Context, channel: ChannelProtocol) {
            self.channel = channel;
            super.init(type: "MixChannelManagerChannelClosedEvent", context: context)
        }
    }

    open class ChannelUpdatedEvent: AbstractEvent {

        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ChannelUpdatedEvent();

        public let channel: ChannelProtocol!;

        private init() {
            channel = nil;
            super.init(type: "MixChannelManagerChannelUpdatedEvent")
        }

        public init(context: Context, channel: ChannelProtocol) {
            self.channel = channel;
            super.init(type: "MixChannelManagerChannelUpdatedEvent", context: context);
        }
    }
}

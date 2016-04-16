//
// StreamFeaturesModule.swift
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

public class StreamFeaturesModule: XmppModule, ContextAware {

    public static let STREAM_FEATURES_KEY = "stream:features";
    
    public let id = "stream:features";
    public let criteria = Criteria.name("features", xmlns: "http://etherx.jabber.org/streams");
    public let features = [String]();
    
    public var context: Context!;
    
    public static func getStringFeatures(sessionObject:SessionObject) -> Element? {
        return sessionObject.getProperty(STREAM_FEATURES_KEY);
    }
    
    
    public init() {
        
    }
    
    public func process(stanza:Stanza) throws {
        context.sessionObject.setProperty("stream:features", value: stanza.element);
        context.eventBus.fire(StreamFeaturesReceivedEvent(context:context, element: stanza.element));
    }

}

public class StreamFeaturesReceivedEvent: Event {
    
    public let type = "StreamFeaturesReceivedEvent";
    
    public static let TYPE = StreamFeaturesReceivedEvent();
    
    public let context:Context!;
    public let featuresElement:Element!;
    
    init() {
        context = nil;
        featuresElement = nil;
    }
    
    public init(context:Context, element:Element) {
        self.context = context;
        self.featuresElement = element;
    }
    
}
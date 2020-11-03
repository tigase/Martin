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

extension XmppModuleIdentifier {
    public static var streamFeatures: XmppModuleIdentifier<StreamFeaturesModule> {
        return StreamFeaturesModule.IDENTIFIER;
    }
}

/**
 Module provides support for XMPP [stream features]
 
 [stream features]: http://xmpp.org/rfcs/rfc6120.html#streams-negotiation-features
 */
open class StreamFeaturesModule: XmppModule, ContextAware, Resetable {

    public static let ID = "stream:features";
    public static let STREAM_FEATURES_KEY = "stream:features";
    public static let IDENTIFIER = XmppModuleIdentifier<StreamFeaturesModule>();
    
    public let criteria = Criteria.name("features", xmlns: "http://etherx.jabber.org/streams");
    public let features = [String]();
    
    open var context: Context!;

    open private(set) var streamFeatures: Element?;
    
    /**
     Retrieves stream features which were recevied from server
     - parameter sessionObject: instance of `SessionObject` to retrieve cached stream features element
     - returns: element with stream features
     */
    public static func getStreamFeatures(_ sessionObject:SessionObject) -> Element? {
        return sessionObject.getProperty(STREAM_FEATURES_KEY);
    }
    
    
    public init() {
        
    }
    
    /**
     Processes received stream features and fires event
     - parameter stanza: stanza to process
     */
    open func process(stanza:Stanza) throws {
        setStreamFeatures(stanza.element);
    }

    open func fireEvent(streamFeatures element: Element) {
        context.eventBus.fire(StreamFeaturesReceivedEvent(context:context, element: element));
    }
    
    func setStreamFeatures(_ element: Element) {
        self.streamFeatures = element;
        fireEvent(streamFeatures: element);
    }
    
    public func reset(scope: ResetableScope) {
        streamFeatures = nil;
    }
}

/// Event fired when stream features are received
open class StreamFeaturesReceivedEvent: Event {
    
    /// Identifier of event which should be used during registration of `EventHandler`
    public static let TYPE = StreamFeaturesReceivedEvent();
    
    public let type = "StreamFeaturesReceivedEvent";
    /// Context of XMPP connection which received this event
    public let context:Context!;
    /// Element with stream features
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

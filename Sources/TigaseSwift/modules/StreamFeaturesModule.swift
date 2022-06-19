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
open class StreamFeaturesModule: XmppModuleBaseSessionStateAware, XmppModule, Resetable {

    public static let ID = "stream:features";
    public static let STREAM_FEATURES_KEY = "stream:features";
    public static let IDENTIFIER = XmppModuleIdentifier<StreamFeaturesModule>();
    
    public let criteria = Criteria.name("features", xmlns: "http://etherx.jabber.org/streams");
    public let features = [String]();
    
    @Published
    open private(set) var streamFeatures: StreamFeatures = .none;
    
    public override init() {
        
    }
    
    /**
     Processes received stream features and fires event
     - parameter stanza: stanza to process
     */
    open func process(stanza:Stanza) throws {
        setStreamFeatures(stanza.element);
    }
    
    func setStreamFeatures(_ element: Element) {
        self.streamFeatures = StreamFeatures(element: element);
    }
    
    public func reset(scopes: Set<ResetableScope>) {
        if scopes.contains(.stream) {
            streamFeatures = .none;
        }
    }
}

public struct StreamFeatures {
    
    public static let none = StreamFeatures(element: nil);
    
    public let element: Element?;
 
    public var isNone: Bool {
        return element == nil;
    }
    
    private init(element: Element?) {
        self.element = element;
    }
    
    public init(element: Element) {
        self.element = element;
    }
    
    public func contains(_ feature: StreamFeature) -> Bool {
        guard let elem = self.element else {
            return false;
        }
        return feature.check(in: elem);
    }
    
    public struct StreamFeature {
        public struct Node {
            public let name: String;
            public let xmlns: String?;
            public let value: String?;
        }
        
        public let path: [Node];
        
        public init(_ path: Node...) {
            self.path = path;
        }
                
        public init(name: String, xmlns: String) {
            self.init(.init(name: name, xmlns: xmlns, value: nil));
        }

        public func check(in element: Element) -> Bool {
            var elem = element;
            for node in path {
                guard let subelem = elem.firstChild(name: node.name, xmlns: node.xmlns) else {
                    return false;
                }
                if node.value != nil {
                    guard subelem.value == node.value else {
                        return false;
                    }
                }
                elem = subelem;
            }
            return true;
        }
        
    }
    
}

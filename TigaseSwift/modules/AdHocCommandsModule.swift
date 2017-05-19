//
//  AdHocCommandsModule.swift
//  TigaseSwift
//
//  Created by Andrzej Wójcik on 08.01.2017.
//  Copyright © 2017 Tigase, Inc. All rights reserved.
//

import Foundation

open class AdHocCommandsModule: XmppModule, ContextAware {
    
    open static let COMMANDS_XMLNS = "http://jabber.org/protocol/commands";
    
    open static let ID = COMMANDS_XMLNS;
    
    open let id = ID;
    
    open let criteria = Criteria.empty();
    
    open var context: Context!;
    
    open let features = [String]();
    
    public init() {
    }
    
    open func process(stanza: Stanza) throws {
        throw ErrorCondition.feature_not_implemented;
    }
    
    open func execute(on to: JID?, command node: String, action: Action?, data: JabberDataElement?, onSuccess: @escaping (Stanza, JabberDataElement?)->Void, onError: @escaping (ErrorCondition?)->Void) {
        let iq = Iq();
        iq.type = .set;
        iq.to = to;
        
        let command = Element(name: "command", xmlns: AdHocCommandsModule.COMMANDS_XMLNS);
        command.setAttribute("node", value: node);
        
        if data != nil {
            command.addChild(data!.submitableElement(type: XDataType.submit));
        }
        
        iq.addChild(command);
        
        context.writer?.write(iq) { (stanza: Stanza?) in
            var errorCondition:ErrorCondition?;
            if let type = stanza?.type {
                switch type {
                case .result:
                    onSuccess(stanza!, JabberDataElement(from: stanza!.findChild(name: "command", xmlns: AdHocCommandsModule.COMMANDS_XMLNS)?.findChild(name: "x", xmlns: "jabber:x:data")));
                    return;
                default:
                    if let name = stanza!.element.findChild(name: "error")?.firstChild()?.name {
                        errorCondition = ErrorCondition(rawValue: name);
                    }
                }
            }
            onError(errorCondition);
        }
    }
    
    public enum Action: String {
        case cancel
        case complete
        case execute
        case next
        case prev
    }
}

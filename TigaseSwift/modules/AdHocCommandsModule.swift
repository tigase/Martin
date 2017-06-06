//
// AdHocCommandsModule.swift
//
// TigaseSwift
// Copyright (C) 2017 "Tigase, Inc." <office@tigase.com>
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

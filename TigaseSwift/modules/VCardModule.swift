//
// VCardModule.swift
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

/**
 Module provides support for [XEP-0054: vcard-temp]
 
 [XEP-0054: vcard-temp]: http://xmpp.org/extensions/xep-0054.html
 */
public class VCardModule: XmppModule, ContextAware {

    /// Namespace used by vcard-temp feature
    private static let VCARD_XMLNS = "vcard-temp";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = VCARD_XMLNS;
    
    public let id = VCARD_XMLNS;
    
    public let criteria = Criteria.empty();
    
    public let features = [VCARD_XMLNS];
    
    public var context: Context!
    
    public init() {
        
    }
    
    public func process(elem: Stanza) throws {
        throw ErrorCondition.unexpected_request;
    }
    
    /**
     Publish vcard
     - parameter vcard: vcard to publish
     - parameter callback: called on result or failure
     */
    public func publishVCard(vcard: VCard, callback: ((Stanza?) -> Void)? = nil) {
        var iq = Iq();
        iq.type = StanzaType.set;
        iq.addChild(vcard.element);
        
        context.writer?.write(iq, callback: callback);
    }
    
    /**
     Publish vcard
     - parameter vcard: vcard to publish
     - parameter onSuccess: called after successful publication
     - parameter onError: called on failure or timeout
     */
    public func publishVCard(vcard: VCard, onSuccess: (()->Void)?, onError: ((errorCondition: ErrorCondition?)->Void)?) {
        publishVCard(vcard) { (stanza) in
            var type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                onSuccess?();
            default:
                var errorCondition = stanza?.errorCondition;
                onError?(errorCondition: errorCondition);
            }
        }
    }
    
    /**
     Retrieve vcard for JID
     - parameter jid: JID for which vcard should be retrieved
     - parameter callback: called with result
     */
    public func retrieveVCard(jid: JID? = nil, callback: (Stanza?) -> Void) {
        var iq = Iq();
        iq.type = StanzaType.get;
        iq.to = jid;
        iq.addChild(Element(name:"vCard", xmlns: VCardModule.VCARD_XMLNS));
        
        context.writer?.write(iq, callback: callback);
    }
    
    /**
     Retrieve vcard for JID
     - parameter jid: JID for which vcard should be retrieved
     - parameter onSuccess: called retrieved vcard
     - parameter onError: called on failure or timeout
     */
    public func retrieveVCard(jid: JID? = nil, onSuccess: (vcard: VCard)->Void, onError: (errorCondition: ErrorCondition?)->Void) {
        retrieveVCard(jid) { (stanza) in
            var type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                if let vcardEl = stanza?.findChild("vCard", xmlns: VCardModule.VCARD_XMLNS) {
                    var vcard = VCard(element: vcardEl)!;
                    onSuccess(vcard: vcard);
                }
            default:
                var errorCondition = stanza?.errorCondition;
                onError(errorCondition: errorCondition);
            }
        }
    }

    /**
     Wrapper class for vcard element for easier access to
     values within vcard element.
     */
    public class VCard: StringValue {
        
        var element: Element!;
        
        public var stringValue: String {
            return element.stringValue;
        }
        
        public var bday: String? {
            get {
                return getElementValue("BDAY")
            }
            set {
                setElementValue("BDAY", value: newValue);
            }
        }
        
        public var fn: String? {
            get {
                return getElementValue("FN");
            }
            set {
                setElementValue("FN", value: newValue);
            }
        }
        
        public var familyName: String? {
            get {
                return getElementValue("N", "FAMILY");
            }
            set {
                setElementValue("N", "FAMILY", value: newValue);
            }
        }
        
        public var givenName: String? {
            get {
                return getElementValue("N", "GIVEN");
            }
            set {
                setElementValue("N", "GIVEN", value: newValue);
            }
        }
        
        public var middleName: String? {
            get {
                return getElementValue("N", "MIDDLE");
            }
            set {
                setElementValue("N", "MIDDLE", value: newValue);
            }
        }
        
        public var nickname: String? {
            get {
                return getElementValue("NICKNAME");
            }
            set {
                setElementValue("NICKNAME", value: newValue);
            }
        }
        
        public var url: String? {
            get {
                return getElementValue("URL");
            }
            set {
                setElementValue("URL", value: newValue);
            }
        }

        public var orgName: String? {
            get {
                return getElementValue("ORG", "ORGNAME");
            }
            set {
                setElementValue("ORG", "ORGNAME", value: newValue);
            }
        }
        
        public var orgUnit: String? {
            get {
                return getElementValue("ORG", "ORGUNIT");
            }
            set {
                setElementValue("ORG", "ORGUNIT", value: newValue);
            }
        }

        public var title: String? {
            get {
                return getElementValue("TITLE");
            }
            set {
                setElementValue("TITLE", value: newValue);
            }
        }
        
        public var role: String? {
            get {
                return getElementValue("ROLE");
            }
            set {
                setElementValue("ROLE", value: newValue);
            }
        }
        
        public var jabberId: String? {
            get {
                return getElementValue("JABBERID");
            }
            set {
                setElementValue("JABBERID", value: newValue);
            }
        }
        
        public var desc: String? {
            get {
                return getElementValue("DESC");
            }
            set {
                setElementValue("DESC", value: newValue);
            }
        }
        
        public var photoType: String? {
            get {
                return getElementValue("PHOTO", "TYPE");
            }
            set {
                setElementValue("PHOTO", "TYPE", value: newValue);
            }
        }

        public var photoVal: String? {
            get {
                return getElementValue("PHOTO", "BINVAL")?.stringByReplacingOccurrencesOfString("\n", withString: "");
            }
            set {
                setElementValue("PHOTO", "BINVAL", value: newValue?.stringByReplacingOccurrencesOfString("\n", withString: ""));
            }
        }
        
        public var photoValBinary:NSData? {
            get {
                let data = photoVal;
                guard data != nil else {
                    return nil;
                }
                return NSData(base64EncodedString: data!, options: NSDataBase64DecodingOptions(rawValue: 0));
            }
            set {
                photoVal = newValue?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
            }
        }
        
        public var emails: [Email] {
            get {
                var result = [Email]();
                element.forEachChild("EMAIL") { (el) in
                    if let email = Email(element: el) {
                        result.append(email);
                    }
                }
                return result;
            }
            set {
                let oldValue = element.getChildren("EMAIL");
                oldValue.forEach { (el) in
                    element.removeChild(el);
                }
                for email in newValue {
                    element.addChild(email.element);
                }
            }
        }

        public var addresses: [Address] {
            get {
                var result = [Address]();
                element.forEachChild("ADR") { (el) in
                    if let address = Address(element: el) {
                        result.append(address);
                    }
                }
                return result;
            }
            set {
                let oldValue = element.getChildren("ADR");
                oldValue.forEach { (el) in
                    element.removeChild(el);
                }
                for address in newValue {
                    element.addChild(address.element);
                }
            }
        }
        
        public var telephones: [Telephone] {
            get {
                var result = [Telephone]();
                element.forEachChild("TEL") { (el) in
                    if let telephone = Telephone(element: el) {
                        result.append(telephone);
                    }
                }
                return result;
            }
            set {
                let oldValue = element.getChildren("TEL");
                oldValue.forEach { (el) in
                    element.removeChild(el);
                }
                for telephone in newValue {
                    element.addChild(telephone.element);
                }
            }
        }
        
        public init() {
            self.element = Element(name: "vCard", xmlns: VCardModule.VCARD_XMLNS);
        }
        
        public init?(element: Element) {
            guard element.name == "vCard" && element.xmlns == VCardModule.VCARD_XMLNS else {
                return nil;
            }
            self.element = element;
        }
        
        public func getElementValue(path: String...) -> String? {
            var elem = element;
            for name in path {
                elem = elem?.findChild(name);
            }
            return elem?.value;
        }
        
        public func setElementValue(path:String..., value:String?) {
            var tmp:[Element]! = value == nil ? [Element]() : nil;
            var i=0;
            var parent:Element? = nil;
            var elem = element;
            while elem != nil && i<path.count {
                var name = path[i];
                parent = elem;
                elem = elem?.findChild(name);
                if elem == nil && value != nil {
                    elem = Element(name: name);
                    parent?.addChild(elem!);
                }
                if elem != nil && value == nil {
                    tmp.append(elem!);
                }
                i = i+1;
            }
            
            if value == nil {
                tmp.insert(element, atIndex: 0);
                for i in (tmp.count-1)...1 {
                    guard !tmp[i].hasChildren else {
                        return;
                    }
                    tmp[i-1].removeChild(tmp[i]);
                }
            } else {
                elem.value = value;
            }
        }
        
        public func setPhoto(data: NSData?, type: String?) {
            photoValBinary = data;
            photoType = type;
        }
        
        public enum Type: String {
            case WORK
            case HOME
            
            public static let allValues = [ HOME, WORK ];
        }
        
        public class Email: TypeAware {
            
            public var address: String? {
                get {
                    return getElementValue("USERID") ;
                }
                set  {
                    setElementValue("USERID", value: newValue);
                }
            }
            
            public override init?(element: Element = Element(name: "EMAIL")) {
                guard element.name == "EMAIL" else {
                    return nil;
                }
                
                super.init(element: element);
            }
            
        }
        
        public class Address: TypeAware {
            
            public var street: String? {
                get {
                    return getElementValue("STREET");
                }
                set {
                    setElementValue("STREET", value: newValue);
                }
            }

            public var locality: String? {
                get {
                    return getElementValue("LOCALITY");
                }
                set {
                    setElementValue("LOCALITY", value: newValue);
                }
            }

            public var region: String? {
                get {
                    return getElementValue("REGION");
                }
                set {
                    setElementValue("REGION", value: newValue);
                }
            }

            public var postalCode: String? {
                get {
                    return getElementValue("PCODE");
                }
                set {
                    setElementValue("PCODE", value: newValue);
                }
            }

            public var country: String? {
                get {
                    return getElementValue("CTRY");
                }
                set {
                    setElementValue("CTRY", value: newValue);
                }
            }

            
            public override init?(element: Element = Element(name: "ADR")) {
                guard element.name == "ADR" else {
                    return nil;
                }
                
                super.init(element: element);
            }
            
            public func isEmpty() -> Bool {
                var empty = true;
                element.getChildren().forEach({ (el) in
                    empty = empty && (el.value == nil);
                })
                return empty;
            }
        }
        
        public class Telephone: TypeAware {
            
            public enum Kind: String {
                case VOICE
                case FAX
                case MSG
                
                public static let allValues = [ VOICE, FAX, MSG ];
            }
            
            public var kind: [Kind] {
                get {
                    var result = [Kind]();
                    for kind in Kind.allValues {
                        if element.findChild(kind.rawValue) != nil {
                            result.append(kind);
                        }
                    }
                    return result;
                }
                set {
                    for kind in Kind.allValues {
                        if let el = element.findChild(kind.rawValue) {
                            element.removeChild(el);
                        }
                    }
                    for kind in newValue {
                        element.addChild(Element(name: kind.rawValue));
                    }
                }
            }
            
            public var number: String? {
                get {
                    return getElementValue("NUMBER");
                }
                set {
                    setElementValue("NUMBER", value: newValue);
                }
            }
            
            public override init?(element: Element = Element(name: "TEL")) {
                guard element.name == "TEL" else {
                    return nil;
                }
                
                super.init(element: element);
            }
        }
        
        public class TypeAware {
            private let element: Element;
            
            public init?(element: Element) {
                self.element = element;
            }
            
            public var types: [Type] {
                get {
                    var types = [Type]();
                    for type in Type.allValues {
                        if element.findChild(type.rawValue) != nil {
                            types.append(type);
                        }
                    }
                    return types;
                }
                set {
                    for type in Type.allValues {
                        if let el = element.findChild(type.rawValue) {
                            element.removeChild(el);
                        }
                    }
                    for type in newValue {
                        element.addChild(Element(name: type.rawValue));
                    }
                }
            }
            
            func getElementValue(name: String) -> String? {
                return element.findChild(name)?.value;
            }
            
            func setElementValue(name: String, value: String?) {
                var el = element.findChild(name);
                if  value == nil {
                    if el != nil {
                        element.removeChild(el!);
                    }
                    return;
                }
                if el == nil {
                    el = Element(name: name);
                    element.addChild(el!);
                }
                el?.value = value;
            }
        }
    }
}

extension Presence {
    
    /// Hash of photo embedded in vcard-temp
    public var vcardTempPhoto:String? {
        get {
            return self.findChild("x", xmlns: "vcard-temp:x:update")?.findChild("photo")?.value;
        }
        set {
            var x = self.findChild("x", xmlns: "vcard-temp:x:update");
            var photo = x?.findChild("photo");
            if newValue == nil {
                if photo != nil {
                    x!.removeChild(photo!);
                }
                if x != nil {
                    self.removeChild(x!);
                }
            } else {
                if x == nil {
                    x = Element(name: "x", xmlns: "vcard-temp:x:update");
                    self.addChild(x!);
                }
                if photo == nil {
                    photo = Element(name: "photo");
                    x!.addChild(photo!);
                }
                photo!.value = newValue!;
            }
        }
    }
    
}
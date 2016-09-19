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
open class VCardModule: XmppModule, ContextAware {

    /// Namespace used by vcard-temp feature
    fileprivate static let VCARD_XMLNS = "vcard-temp";
    /// ID of module for lookup in `XmppModulesManager`
    open static let ID = VCARD_XMLNS;
    
    open let id = VCARD_XMLNS;
    
    open let criteria = Criteria.empty();
    
    open let features = [VCARD_XMLNS];
    
    open var context: Context!
    
    public init() {
        
    }
    
    open func process(_ elem: Stanza) throws {
        throw ErrorCondition.unexpected_request;
    }
    
    /**
     Publish vcard
     - parameter vcard: vcard to publish
     - parameter callback: called on result or failure
     */
    open func publishVCard(_ vcard: VCard, callback: ((Stanza?) -> Void)? = nil) {
        let iq = Iq();
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
    open func publishVCard(_ vcard: VCard, onSuccess: (()->Void)?, onError: ((_ errorCondition: ErrorCondition?)->Void)?) {
        publishVCard(vcard) { (stanza) in
            let type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                onSuccess?();
            default:
                let errorCondition = stanza?.errorCondition;
                onError?(errorCondition);
            }
        }
    }
    
    /**
     Retrieve vcard for JID
     - parameter jid: JID for which vcard should be retrieved
     - parameter callback: called with result
     */
    open func retrieveVCard(_ jid: JID? = nil, callback: @escaping (Stanza?) -> Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = jid;
        iq.addChild(Element(name:"vCard", xmlns: VCardModule.VCARD_XMLNS));
        
        context.writer?.write(iq, timeout: 10, callback: callback);
    }
    
    /**
     Retrieve vcard for JID
     - parameter jid: JID for which vcard should be retrieved
     - parameter onSuccess: called retrieved vcard
     - parameter onError: called on failure or timeout
     */
    open func retrieveVCard(_ jid: JID? = nil, onSuccess: @escaping (_ vcard: VCard)->Void, onError: @escaping (_ errorCondition: ErrorCondition?)->Void) {
        retrieveVCard(jid) { (stanza) in
            let type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                if let vcardEl = stanza?.findChild("vCard", xmlns: VCardModule.VCARD_XMLNS) {
                    let vcard = VCard(element: vcardEl)!;
                    onSuccess(vcard);
                }
            default:
                let errorCondition = stanza?.errorCondition;
                onError(errorCondition);
            }
        }
    }

    /**
     Wrapper class for vcard element for easier access to
     values within vcard element.
     */
    open class VCard: StringValue {
        
        var element: Element!;
        
        open var stringValue: String {
            return element.stringValue;
        }
        
        open var bday: String? {
            get {
                return getElementValue("BDAY")
            }
            set {
                setElementValue("BDAY", value: newValue);
            }
        }
        
        open var fn: String? {
            get {
                return getElementValue("FN");
            }
            set {
                setElementValue("FN", value: newValue);
            }
        }
        
        open var familyName: String? {
            get {
                return getElementValue("N", "FAMILY");
            }
            set {
                setElementValue("N", "FAMILY", value: newValue);
            }
        }
        
        open var givenName: String? {
            get {
                return getElementValue("N", "GIVEN");
            }
            set {
                setElementValue("N", "GIVEN", value: newValue);
            }
        }
        
        open var middleName: String? {
            get {
                return getElementValue("N", "MIDDLE");
            }
            set {
                setElementValue("N", "MIDDLE", value: newValue);
            }
        }
        
        open var nickname: String? {
            get {
                return getElementValue("NICKNAME");
            }
            set {
                setElementValue("NICKNAME", value: newValue);
            }
        }
        
        open var url: String? {
            get {
                return getElementValue("URL");
            }
            set {
                setElementValue("URL", value: newValue);
            }
        }

        open var orgName: String? {
            get {
                return getElementValue("ORG", "ORGNAME");
            }
            set {
                setElementValue("ORG", "ORGNAME", value: newValue);
            }
        }
        
        open var orgUnit: String? {
            get {
                return getElementValue("ORG", "ORGUNIT");
            }
            set {
                setElementValue("ORG", "ORGUNIT", value: newValue);
            }
        }

        open var title: String? {
            get {
                return getElementValue("TITLE");
            }
            set {
                setElementValue("TITLE", value: newValue);
            }
        }
        
        open var role: String? {
            get {
                return getElementValue("ROLE");
            }
            set {
                setElementValue("ROLE", value: newValue);
            }
        }
        
        open var jabberId: String? {
            get {
                return getElementValue("JABBERID");
            }
            set {
                setElementValue("JABBERID", value: newValue);
            }
        }
        
        open var desc: String? {
            get {
                return getElementValue("DESC");
            }
            set {
                setElementValue("DESC", value: newValue);
            }
        }
        
        open var photoType: String? {
            get {
                return getElementValue("PHOTO", "TYPE");
            }
            set {
                setElementValue("PHOTO", "TYPE", value: newValue);
            }
        }

        open var photoVal: String? {
            get {
                return getElementValue("PHOTO", "BINVAL")?.replacingOccurrences(of: "\n", with: "");
            }
            set {
                setElementValue("PHOTO", "BINVAL", value: newValue?.replacingOccurrences(of: "\n", with: ""));
            }
        }
        
        open var photoValBinary:Data? {
            get {
                let data = photoVal;
                guard data != nil else {
                    return nil;
                }
                return Data(base64Encoded: data!, options: NSData.Base64DecodingOptions(rawValue: 0));
            }
            set {
                photoVal = newValue?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
            }
        }
        
        open var emails: [Email] {
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

        open var addresses: [Address] {
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
        
        open var telephones: [Telephone] {
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
        
        open func getElementValue(_ path: String...) -> String? {
            var elem = element;
            for name in path {
                elem = elem?.findChild(name);
            }
            return elem?.value;
        }
        
        open func setElementValue(_ path:String..., value:String?) {
            var tmp:[Element]! = value == nil ? [Element]() : nil;
            var i=0;
            var parent:Element? = nil;
            var elem = element;
            while elem != nil && i<path.count {
                let name = path[i];
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
                tmp.insert(element, at: 0);
                for i in (tmp.count-1)...1 {
                    guard !tmp[i].hasChildren else {
                        return;
                    }
                    tmp[i-1].removeChild(tmp[i]);
                }
            } else {
                elem?.value = value;
            }
        }
        
        open func setPhoto(_ data: Data?, type: String?) {
            photoValBinary = data;
            photoType = type;
        }
        
        public enum EntryType: String {
            case WORK
            case HOME
            
            public static let allValues = [ HOME, WORK ];
        }
        
        open class Email: TypeAware {
            
            open var address: String? {
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
        
        open class Address: TypeAware {
            
            open var street: String? {
                get {
                    return getElementValue("STREET");
                }
                set {
                    setElementValue("STREET", value: newValue);
                }
            }

            open var locality: String? {
                get {
                    return getElementValue("LOCALITY");
                }
                set {
                    setElementValue("LOCALITY", value: newValue);
                }
            }

            open var region: String? {
                get {
                    return getElementValue("REGION");
                }
                set {
                    setElementValue("REGION", value: newValue);
                }
            }

            open var postalCode: String? {
                get {
                    return getElementValue("PCODE");
                }
                set {
                    setElementValue("PCODE", value: newValue);
                }
            }

            open var country: String? {
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
            
            open func isEmpty() -> Bool {
                var empty = true;
                element.getChildren().forEach({ (el) in
                    empty = empty && (el.value == nil);
                })
                return empty;
            }
        }
        
        open class Telephone: TypeAware {
            
            public enum Kind: String {
                case VOICE
                case FAX
                case MSG
                
                public static let allValues = [ VOICE, FAX, MSG ];
            }
            
            open var kind: [Kind] {
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
            
            open var number: String? {
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
        
        open class TypeAware {
            fileprivate let element: Element;
            
            public init?(element: Element) {
                self.element = element;
            }
            
            open var types: [EntryType] {
                get {
                    var types = [EntryType]();
                    for type in EntryType.allValues {
                        if element.findChild(type.rawValue) != nil {
                            types.append(type);
                        }
                    }
                    return types;
                }
                set {
                    for type in EntryType.allValues {
                        if let el = element.findChild(type.rawValue) {
                            element.removeChild(el);
                        }
                    }
                    for type in newValue {
                        element.addChild(Element(name: type.rawValue));
                    }
                }
            }
            
            func getElementValue(_ name: String) -> String? {
                return element.findChild(name)?.value;
            }
            
            func setElementValue(_ name: String, value: String?) {
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

//
// VCardTempModule.swift
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
open class VCardTempModule: XmppModule, ContextAware, VCardModuleProtocol {

    /// Namespace used by vcard-temp feature
    fileprivate static let VCARD_XMLNS = "vcard-temp";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = VCARD_XMLNS;
    
    public let id = VCARD_XMLNS;
    
    public let criteria = Criteria.empty();
    
    public let features = [VCARD_XMLNS];
    
    open var context: Context!
    
    public init() {
        
    }
    
    open func process(stanza: Stanza) throws {
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
        iq.addChild(vcard.toVCardTemp());
        
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
     - parameter from: JID for which vcard should be retrieved
     - parameter callback: called with result
     */
    open func retrieveVCard(from jid: JID? = nil, callback: @escaping (Stanza?) -> Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = jid;
        iq.addChild(Element(name:"vCard", xmlns: VCardTempModule.VCARD_XMLNS));
        
        context.writer?.write(iq, timeout: 10, callback: callback);
    }
    
    /**
     Retrieve vcard for JID
     - parameter jid: JID for which vcard should be retrieved
     - parameter onSuccess: called retrieved vcard
     - parameter onError: called on failure or timeout
     */
    open func retrieveVCard(from jid: JID? = nil, onSuccess: @escaping (_ vcard: VCard)->Void, onError: @escaping (_ errorCondition: ErrorCondition?)->Void) {
        retrieveVCard(from: jid) { (stanza) in
            let type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                if let vcardEl = stanza?.findChild(name: "vCard", xmlns: VCardTempModule.VCARD_XMLNS) {
                    let vcard = VCard(vcardTemp: vcardEl)!;
                    onSuccess(vcard);
                }
            default:
                let errorCondition = stanza?.errorCondition;
                onError(errorCondition);
            }
        }
    }

}

extension VCard {
    
    public convenience init?(vcardTemp: Element?) {
        guard vcardTemp != nil && vcardTemp!.name == "vCard" && vcardTemp!.xmlns == "vcard-temp" else {
            return nil;
        }
        self.init();
        
        self.bday = vcardTemp!.findChild(name: "BDAY")?.value;
        self.fn = vcardTemp!.findChild(name: "FN")?.value;
        
        if let n = vcardTemp!.findChild(name: "N") {
            self.surname = n.findChild(name: "FAMILY")?.value;
            self.givenName = n.findChild(name: "GIVEN")?.value;
            if let middleName = n.findChild(name: "MIDDLE")?.value {
                self.additionalName.append(middleName);
            }
            self.namePrefixes = n.mapChildren(transform: {(el) in
                return el.value;
            }, filter: {(el) -> Bool in
                return el.name == "PREFIX" && el.value != nil;
            });
            self.nameSuffixes = n.mapChildren(transform: {(el) in
                return el.value;
            }, filter: {(el) -> Bool in
                return el.name == "SUFFIX" && el.value != nil;
            });
        }
        
        self.nicknames = vcardTemp!.mapChildren(transform: {(el) in
            return el.value!;
        }, filter: { (el) -> Bool in
            return el.name == "NICKNAME" && el.value != nil;
        });
        
        self.title = vcardTemp!.findChild(name: "TITLE")?.value;
        self.role = vcardTemp!.findChild(name: "ROLE")?.value;
        self.note = vcardTemp!.findChild(name: "DESC")?.value;
        
        self.addresses = vcardTemp!.mapChildren(transform: {(el)->Address in
            let addr = Address();
            if el.findChild(name: "WORK") != nil {
                addr.types.append(.work);
            }
            if el.findChild(name: "HOME") != nil {
                addr.types.append(.home);
            }
            
            addr.street = el.findChild(name: "STREET")?.value;
            addr.locality = el.findChild(name: "LOCALITY")?.value;
            addr.postalCode = el.findChild(name: "PCODE")?.value;
            addr.country = el.findChild(name: "CTRY")?.value;
            addr.region = el.findChild(name: "REGION")?.value;
            return addr;
        }, filter: {(el)->Bool in
            return el.name == "ADR";
        });
        
        vcardTemp!.forEachChild(name: "EMAIL") { (el) in
            if let address = el.findChild(name: "USERID")?.value {
                let email = Email(address: address);
                if el.findChild(name: "WORK") != nil {
                    email.types.append(.work);
                }
                if el.findChild(name: "HOME") != nil {
                    email.types.append(.home);
                }
                
                self.emails.append(email);
            }
        }
        
        self.impps = vcardTemp!.mapChildren(transform: {(el)->IMPP in
            return IMPP(uri: "xmpp:\(el.value!)");
        }, filter: { (el) -> Bool in
            return el.name == "JABBERID" && el.value != nil;
        });
        
        vcardTemp!.forEachChild(name: "ORG") { (el) in
            if let orgname = el.findChild(name: "ORGNAME")?.value {
                self.organizations.append(Organization(name: orgname));
            }
        }
        
        vcardTemp!.forEachChild(name: "PHOTO") { (el) in
            if let type = el.findChild(name: "TYPE")?.value, let binval = el.findChild(name: "BINVAL")?.value {
                self.photos.append(Photo(type: type, binval: binval));
            }
            if let extval = el.findChild(name: "EXTVAL")?.value {
                self.photos.append(Photo(uri: extval));
            }
        }
        
        vcardTemp!.forEachChild(name: "TEL") { (el) in
            if let number = el.findChild(name: "NUMBER")?.value {
                let phone = Telephone(number: number);
                if el.findChild(name: "WORK") != nil {
                    phone.types.append(.work);
                }
                if el.findChild(name: "HOME") != nil {
                    phone.types.append(.home);
                }
                if el.findChild(name: "FAX") != nil {
                    phone.kinds.append(.fax);
                }
                if el.findChild(name: "MGS") != nil {
                    phone.kinds.append(.msg);
                }
                if el.findChild(name: "VOICE") != nil {
                    phone.kinds.append(.voice);
                }
                if el.findChild(name: "CELL") != nil {
                    phone.kinds.append(.cell);
                }
                self.telephones.append(phone);
            }
        }
    }
    
    open func toVCardTemp() -> Element {
        let vcardTemp = Element(name: "vCard", xmlns: "vcard-temp");
        
        if bday != nil {
            vcardTemp.addChild(Element(name: "BDAY", cdata: bday));
        }
        if fn != nil {
            vcardTemp.addChild(Element(name: "FN", cdata: fn));
        }
        if surname != nil || givenName != nil || !additionalName.isEmpty || !namePrefixes.isEmpty || !nameSuffixes.isEmpty {
            let n = Element(name: "N");
            if surname != nil {
                n.addChild(Element(name: "FAMILY", cdata: surname));
            }
            if givenName != nil {
                n.addChild(Element(name: "GIVEN", cdata: givenName));
            }
            if !additionalName.isEmpty {
                n.addChild(Element(name: "MIDDLE", cdata: additionalName[0]));
            }
            n.addChildren(namePrefixes.map({(prefix) in return Element(name: "PREFIX", cdata: prefix); }));
            n.addChildren(nameSuffixes.map({(suffix) in return Element(name: "SUFFIX", cdata: suffix); }));
            vcardTemp.addChild(n);
        }
        vcardTemp.addChildren(nicknames.filter({(it) in return !it.isEmpty}).map({(nick) in return Element(name: "NICKNAME", cdata: nick); }));
        if title != nil {
            vcardTemp.addChild(Element(name: "TITLE", cdata: title));
        }
        if role != nil {
            vcardTemp.addChild(Element(name: "ROLE", cdata: role));
        }
        if note != nil {
            vcardTemp.addChild(Element(name: "DESC", cdata: note));
        }
        vcardTemp.addChildren(addresses.filter({(it) in return !it.isEmpty}).map({(addr) in
            let adr = Element(name: "ADR");
            VCard.vcardTempTypesToElement(elem: adr, types: addr.types);
            if addr.street != nil {
                adr.addChild(Element(name: "STREET", cdata: addr.street));
            }
            if addr.locality != nil {
                adr.addChild(Element(name: "LOCALITY", cdata: addr.locality));
            }
            if addr.postalCode != nil {
                adr.addChild(Element(name: "PCODE", cdata: addr.postalCode));
            }
            if addr.region != nil {
                adr.addChild(Element(name: "REGION", cdata: addr.region));
            }
            if addr.country != nil {
                adr.addChild(Element(name: "CTRY", cdata: addr.country));
            }
            return adr;
        }));
        vcardTemp.addChildren(emails.filter({(it) in return !it.isEmpty}).map({(email) in
            let el = Element(name: "EMAIL");
            VCard.vcardTempTypesToElement(elem: el, types: email.types);
            el.addChild(Element(name: "USERID", cdata: email.address));
            return el;
        }));
        vcardTemp.addChildren(impps.filter({(it) in return !it.isEmpty}).filter({(impp)->Bool in
            return impp.uri!.hasPrefix("xmpp:");
        }).map({(impp) in
            let jabberid = impp.uri!.suffix(from: impp.uri!.index(impp.uri!.startIndex, offsetBy: 5));
            return Element(name: "JABBERID", cdata: String(jabberid));
        }));
        vcardTemp.addChildren(organizations.filter({(it) in return !it.isEmpty}).map({(org) in
            let el = Element(name: "ORG");
            el.addChild(Element(name: "ORGNAME", cdata: org.name));
            return el;
        }));
        vcardTemp.addChildren(photos.filter({(it) in return !it.isEmpty}).filter({(photo) in
            return (photo.binval != nil && photo.type != nil) || (photo.uri != nil);
        }).map({(photo) in
            let el = Element(name: "PHOTO");
            if photo.type != nil {
                el.addChild(Element(name: "TYPE", cdata: photo.type));
                el.addChild(Element(name: "BINVAL", cdata: photo.binval));
            }
            if photo.uri != nil {
                el.addChild(Element(name: "EXTVAL", cdata: photo.uri));
            }
            return el;
        }));
        vcardTemp.addChildren(telephones.filter({(it) in return !it.isEmpty}).map({(tel) in
            let el = Element(name: "TEL");
            VCard.vcardTempTypesToElement(elem: el, types: tel.types);
            for kind in tel.kinds {
                switch kind {
                case .cell:
                    el.addChild(Element(name: "CELL"));
                case .fax:
                    el.addChild(Element(name: "FAX"));
                case .msg:
                    el.addChild(Element(name: "MSG"));
                case .voice:
                    el.addChild(Element(name: "VOICE"));
                }
            }
            el.addChild(Element(name: "NUMBER", cdata: tel.number));
            return el;
        }));
        
        return vcardTemp;
    }
    
    fileprivate static func vcardTempTypesToElement(elem: Element, types: [EntryType]) {
        for type in types {
            switch type {
            case .home:
                elem.addChild(Element(name: "HOME"));
            case .work:
                elem.addChild(Element(name: "WORK"));
            }
        }
    }
}

extension Presence {
    
    /// Hash of photo embedded in vcard-temp
    public var vcardTempPhoto:String? {
        get {
            return self.findChild(name: "x", xmlns: "vcard-temp:x:update")?.findChild(name: "photo")?.value;
        }
        set {
            var x = self.findChild(name: "x", xmlns: "vcard-temp:x:update");
            var photo = x?.findChild(name: "photo");
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

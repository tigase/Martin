//
// VCard4Module.swift
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

/**
 Module provides support for [XEP-0054: vcard-temp]
 
 [XEP-0292: vCard4 Over XMPP]: http://xmpp.org/extensions/xep-0292.html
 */
open class VCard4Module: XmppModule, ContextAware, VCardModuleProtocol {
    
    /// Namespace used by vcard-temp feature
    fileprivate static let VCARD_XMLNS = "urn:ietf:params:xml:ns:vcard-4.0";
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
        iq.addChild(vcard.toVCard4());
        
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
        iq.addChild(Element(name:"vcard", xmlns: VCard4Module.VCARD_XMLNS));
        
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
                if let vcardEl = stanza?.findChild(name: "vcard", xmlns: VCard4Module.VCARD_XMLNS) {
                    let vcard = VCard(vcard4: vcardEl)!;
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
    
    public convenience init?(vcard4: Element?) {
        guard vcard4 != nil && vcard4!.name == "vcard" && vcard4!.xmlns == "urn:ietf:params:xml:ns:vcard-4.0" else {
            return nil;
        }
        self.init();
        
        self.bday = vcard4!.findChild(name: "bday")?.findChild(name: "date")?.value;
        self.fn = vcard4!.findChild(name: "fn")?.findChild(name: "text")?.value;
        if let n = vcard4!.findChild(name: "n") {
            self.surname = n.findChild(name: "surname")?.value;
            self.givenName = n.findChild(name: "given")?.value;
            self.additionalName = n.mapChildren(transform: {(el) in
                return el.value!;
            }, filter: {(el)->Bool in
                return el.name == "additional" && el.value != nil;
            });
            self.namePrefixes = n.mapChildren(transform: {(el) in
                return el.value!;
            }, filter: {(el)->Bool in
                return el.name == "prefix" && el.value != nil;
            });
            self.nameSuffixes = n.mapChildren(transform: {(el) in
                return el.value!;
            }, filter: {(el)->Bool in
                return el.name == "suffix" && el.value != nil;
            });
        }
        vcard4!.forEachChild(name: "nickname") { (el) in
            if let nick = el.findChild(name: "text")?.value {
                self.nicknames.append(nick);
            }
        }
        self.title = vcard4!.findChild(name: "title")?.findChild(name: "text")?.value;
        self.role = vcard4!.findChild(name: "role")?.findChild(name: "text")?.value;
        self.note = vcard4!.findChild(name: "note")?.findChild(name: "text")?.value;
        
        self.addresses = vcard4!.mapChildren(transform: {(el)->Address in
            let addr = Address();
            addr.ext = el.findChild(name: "ext")?.value;
            addr.country = el.findChild(name: "country")?.value;
            addr.locality = el.findChild(name: "locality")?.value;
            addr.postalCode = el.findChild(name: "code")?.value;
            addr.region = el.findChild(name: "region")?.value;
            addr.street = el.findChild(name: "street")?.value;
            VCard.convertVCard4ParamtersToTypes(el: el, entry: addr);
            return addr;
        }, filter: {(el)->Bool in
            return el.name == "adr"
        });
        
        vcard4!.forEachChild(name: "email") { (el) in
            if let address = el.findChild(name: "text")?.value {
                let email = Email(address: address);
                VCard.convertVCard4ParamtersToTypes(el: el, entry: email);
                self.emails.append(email);
            }
        }
        
        vcard4!.forEachChild(name: "impp") { (el) in
            if let uri = el.findChild(name: "uri")?.value {
                let impp = IMPP(uri: uri);
                VCard.convertVCard4ParamtersToTypes(el: el, entry: impp);
                self.impps.append(impp);
            }
        }
        
        vcard4!.forEachChild(name: "org") { (el) in
            if let name = el.findChild(name: "text")?.value {
                let org = Organization(name: name);
                VCard.convertVCard4ParamtersToTypes(el: el, entry: org);
                self.organizations.append(org);
            }
        }
        
        vcard4!.forEachChild(name: "photo") { (el) in
            if let uri = el.findChild(name: "uri")?.value {
                let photo = Photo(uri: uri);
                VCard.convertVCard4ParamtersToTypes(el: el, entry: photo);
                self.photos.append(photo);
            }
        }
        
        vcard4!.forEachChild(name: "tel") { (el) in
            if let uri = el.findChild(name: "uri")?.value {
                let tel = Telephone(uri: uri);
                VCard.convertVCard4ParamtersToTypes(el: el, entry: tel);
                self.telephones.append(tel);
            }
        }
    }
    
    open func toVCard4() -> Element {
        let vcard = Element(name: "vcard", xmlns: "urn:ietf:params:xml:ns:vcard-4.0");
        
        if bday != nil {
            vcard.addChild(Element(name: "bday", children: [Element(name:"date", cdata: bday)]));
        }
        if fn != nil {
            vcard.addChild(Element(name: "fn", children: [Element(name:"text", cdata: fn)]));
        }
        if surname != nil || givenName != nil || !additionalName.isEmpty || !namePrefixes.isEmpty || !nameSuffixes.isEmpty {
            let n = Element(name: "n");
            if surname != nil {
                n.addChild(Element(name: "surname", cdata: surname));
            }
            if givenName != nil {
                n.addChild(Element(name: "given", cdata: givenName));
            }
            n.addChildren(additionalName.map({(it) in return Element(name: "additional", cdata: it); }));
            n.addChildren(namePrefixes.map({(it) in return Element(name: "prefix", cdata: it); }));
            n.addChildren(nameSuffixes.map({(it) in return Element(name: "suffix", cdata: it); }));
            vcard.addChild(n);
        }
        vcard.addChildren(nicknames.filter({(it) in return !it.isEmpty}).map({(it) in return Element(name: "nickname", children: [Element(name: "text", cdata: it)]); }));
        if title != nil {
            vcard.addChild(Element(name: "title", children: [Element(name: "text", cdata: title)]));
        }
        if role != nil {
            vcard.addChild(Element(name: "role", children: [Element(name: "text", cdata: role)]));
        }
        if note != nil {
            vcard.addChild(Element(name: "note", children: [Element(name: "text", cdata: note)]));
        }
     
        vcard.addChildren(addresses.filter({(it) in return !it.isEmpty}).map({(addr) in
            let el = Element(name: "adr");
            if addr.ext != nil {
                el.addChild(Element(name: "ext", cdata: addr.ext));
            }
            if addr.street != nil {
                el.addChild(Element(name: "street", cdata: addr.street));
            }
            if addr.locality != nil {
                el.addChild(Element(name: "locality", cdata: addr.locality));
            }
            if addr.region != nil {
                el.addChild(Element(name: "region", cdata: addr.region));
            }
            if addr.postalCode != nil {
                el.addChild(Element(name: "code", cdata: addr.postalCode));
            }
            if addr.country != nil {
                el.addChild(Element(name: "country", cdata: addr.country));
            }
            VCard.convertTypesToVCard4Parameters(el: el, entry: addr);
            return el;
        }));
        
        vcard.addChildren(emails.filter({(it) in return !it.isEmpty}).map({(it) in
            let el = Element(name: "email", children: [Element(name: "text", cdata: it.address)]);
            VCard.convertTypesToVCard4Parameters(el: el, entry: it);
            return el;
        }));
        
        vcard.addChildren(impps.filter({(it) in return !it.isEmpty}).map({(it) in
            let el = Element(name: "impp", children: [Element(name: "uri", cdata: it.uri)]);
            VCard.convertTypesToVCard4Parameters(el: el, entry: it);
            return el;
        }));
        
        vcard.addChildren(organizations.filter({(it) in return !it.isEmpty}).map({(it) in
            let el = Element(name: "org", children: [Element(name: "text", cdata: it.name)]);
            VCard.convertTypesToVCard4Parameters(el: el, entry: it);
            return el;
        }));
        
        vcard.addChildren(photos.filter({(it) in return !it.isEmpty}).map({(it) in
            let uri = it.uri ?? "data:\(it.type!);base64,\(it.binval!)";
            let el = Element(name: "photo", children: [Element(name: "uri", cdata: uri)]);
            VCard.convertTypesToVCard4Parameters(el: el, entry: it);
            return el;
        }));
        
        vcard.addChildren(telephones.filter({(it) in return !it.isEmpty}).map({(it) in
            let el = Element(name: "tel", children: [Element(name: "uri", cdata: it.uri)]);
            VCard.convertTypesToVCard4Parameters(el: el, entry: it);
            return el;
        }));
        
        return vcard;
    }
    
    fileprivate static func convertVCard4ParamtersToTypes(el: Element, entry: VCardEntryItemTypeAware) {
        el.findChild(name: "parameters")?.forEachChild(name: "type") { (type) in
            if let val = type.findChild(name: "text")?.value {
                if val == "work" {
                    entry.types.append(.work);
                }
                if val == "home" {
                    entry.types.append(.home);
                }
            }
        }
    }
    
    fileprivate static func convertTypesToVCard4Parameters(el: Element, entry: VCardEntryItemTypeAware) {
        var params = el.findChild(name: "parameters");
        if params == nil {
            params = Element(name: "parameters");
            el.addChild(params!);
        }
        
        params?.addChildren(entry.types.map({(it) in
            var name: String? = nil;
            switch it {
            case .home:
                name = "home";
            case .work:
                name = "work";
            }
            return Element(name: "type", children: [Element(name: "text", cdata: name)]);
        }));
    }
    
}

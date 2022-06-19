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

extension XmppModuleIdentifier {
    public static var vcard4: XmppModuleIdentifier<VCard4Module> {
        return VCard4Module.IDENTIFIER;
    }
}

/**
 Module provides support for [XEP-0054: vcard-temp]
 
 [XEP-0292: vCard4 Over XMPP]: http://xmpp.org/extensions/xep-0292.html
 */
open class VCard4Module: XmppModuleBase, XmppModule, VCardModuleProtocol {
    
    /// Namespace used by vcard-temp feature
    fileprivate static let VCARD_XMLNS = "urn:ietf:params:xml:ns:vcard-4.0";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = VCARD_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<VCard4Module>();
    
    public let criteria = Criteria.empty();
    
    public let features = [VCARD_XMLNS];
    
    public override init() {
        
    }
    
    open func process(stanza: Stanza) throws {
        throw XMPPError.feature_not_implemented;
    }
    
    /**
     Publish vcard
     - parameter vcard: vcard to publish
     - parameter callback: called on result or failure
     */
    open func publishVCard<Failure: Error>(_ vcard: VCard, to jid: BareJID?, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: ((Result<Iq,Failure>) -> Void)? = nil) {
        let iq = Iq();
        if jid != nil {
            iq.to = JID(jid!);
        }
        iq.type = StanzaType.set;
        iq.addChild(vcard.toVCard4());
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    /**
     Publish vcard
     - parameter vcard: vcard to publish
     - parameter completionHandler: called after publication result is received
     */
    open func publishVCard(_ vcard: VCard, to jid: BareJID?, completionHandler: ((Result<Void,XMPPError>)->Void)?) {
        publishVCard(vcard, to: jid, errorDecoder: XMPPError.from(stanza:), completionHandler: { result in
            completionHandler?(result.map { _ in Void() });
        });
    }
    
    /**
     Retrieve vcard for JID
     - parameter from: JID for which vcard should be retrieved
     - parameter callback: called with result
     */
    open func retrieveVCard<Failure: Error>(from jid: JID? = nil, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>) -> Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = jid;
        iq.addChild(Element(name:"vcard", xmlns: VCard4Module.VCARD_XMLNS));
        
        write(iq, timeout: 10, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    /**
     Retrieve vcard for JID
     - parameter jid: JID for which vcard should be retrieved
     - parameter completionHandler: called  vcard retrieval result is received
     */
    open func retrieveVCard(from jid: JID? = nil, completionHandler: @escaping (Result<VCard,XMPPError>)->Void) {
        retrieveVCard(from: jid, errorDecoder: XMPPError.from(stanza:), completionHandler: { result in
            completionHandler(result.map({ response in
                if let vcardEl = response.firstChild(name: "vcard", xmlns: VCard4Module.VCARD_XMLNS), let vcard = VCard(vcard4: vcardEl) {
                    return vcard;
                } else {
                    return VCard();
                }
            }))
        });
    }
    
}

extension VCard {
    
    public convenience init?(vcard4 el: Element?) {
        guard let vcard4 = el, vcard4.name == "vcard" && vcard4.xmlns == "urn:ietf:params:xml:ns:vcard-4.0" else {
            return nil;
        }
        self.init();
        
        self.bday = vcard4.firstChild(name: "bday")?.firstChild(name: "date")?.value;
        self.fn = vcard4.firstChild(name: "fn")?.firstChild(name: "text")?.value;
        if let n = vcard4.firstChild(name: "n") {
            self.surname = n.firstChild(name: "surname")?.value;
            self.givenName = n.firstChild(name: "given")?.value;
            self.additionalName = n.filterChildren(name: "additional").compactMap({ $0.value });
            self.namePrefixes = n.filterChildren(name: "prefix").compactMap({ $0.value });
            self.nameSuffixes = n.filterChildren(name: "suffix").compactMap({ $0.value });
        }
        self.nicknames = vcard4.filterChildren(name: "nickname").compactMap({ el -> String? in el.firstChild(name: "text")?.value });
        self.title = vcard4.firstChild(name: "title")?.firstChild(name: "text")?.value;
        self.role = vcard4.firstChild(name: "role")?.firstChild(name: "text")?.value;
        self.note = vcard4.firstChild(name: "note")?.firstChild(name: "text")?.value;
        
        self.addresses = vcard4.filterChildren(name: "adr").map({ el -> Address in
            let addr = Address();
            addr.ext = el.firstChild(name: "ext")?.value;
            addr.country = el.firstChild(name: "country")?.value;
            addr.locality = el.firstChild(name: "locality")?.value;
            addr.postalCode = el.firstChild(name: "code")?.value;
            addr.region = el.firstChild(name: "region")?.value;
            addr.street = el.firstChild(name: "street")?.value;
            addr.types = VCard.convertVCard4ParamtersToTypes(el: el);
            return addr;
        });
        
        self.emails = vcard4.filterChildren(name: "email").compactMap({ el -> Email? in
            guard let address = el.firstChild(name: "text")?.value else {
                return nil;
            }
            let email = Email(address: address);
            email.types = VCard.convertVCard4ParamtersToTypes(el: el);
            return email;
        })
        
        self.impps = vcard4.filterChildren(name: "impp").compactMap({ el -> IMPP? in
            guard let uri = el.firstChild(name: "uri")?.value else {
                return nil;
            }
            let impp = IMPP(uri: uri);
            impp.types = VCard.convertVCard4ParamtersToTypes(el: el);
            return impp;
        })
        
        self.organizations = vcard4.filterChildren(name: "org").compactMap({ el -> Organization? in
            guard let name = el.firstChild(name: "text")?.value else {
                return nil;
            }
            let org = Organization(name: name);
            org.types = VCard.convertVCard4ParamtersToTypes(el: el);
            return org;
        })
        
        self.photos = vcard4.filterChildren(name: "photo").compactMap({ el -> Photo? in
            guard let uri = el.firstChild(name: "uri")?.value?.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "") else {
                return nil;
            }
            let photo = Photo(uri: uri);
            photo.types = VCard.convertVCard4ParamtersToTypes(el: el);
            return photo;
        })
        
        self.telephones = vcard4.filterChildren(name: "tel").compactMap({ el -> Telephone? in
            guard let uri = el.firstChild(name: "uri")?.value else {
                return nil;
            }
            let tel = Telephone(uri: uri);
            tel.types = VCard.convertVCard4ParamtersToTypes(el: el);
            return tel;
        })
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
    
    fileprivate static func convertVCard4ParamtersToTypes(el: Element) -> [VCard.EntryType] {
        return el.firstChild(name: "parameters")?.filterChildren(name: "type").compactMap({ type in
            guard let val = type.firstChild(name: "text")?.value else {
                return nil;
            }
            switch val {
            case "work":
                return .work;
            case "home":
                return .home;
            default:
                return nil;
            }
        }) ?? [];
    }
    
    fileprivate static func convertTypesToVCard4Parameters(el: Element, entry: VCardEntryItemTypeAware) {
        var params = el.firstChild(name: "parameters");
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

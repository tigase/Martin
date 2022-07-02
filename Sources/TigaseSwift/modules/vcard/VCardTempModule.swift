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

extension XmppModuleIdentifier {
    public static var vcardTemp: XmppModuleIdentifier<VCardTempModule> {
        return VCardTempModule.IDENTIFIER;
    }
}

/**
 Module provides support for [XEP-0054: vcard-temp]
 
 [XEP-0054: vcard-temp]: http://xmpp.org/extensions/xep-0054.html
 */
open class VCardTempModule: XmppModuleBase, XmppModule, VCardModuleProtocol {

    /// Namespace used by vcard-temp feature
    fileprivate static let VCARD_XMLNS = "vcard-temp";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = VCARD_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<VCardTempModule>();
    
    public let criteria = Criteria.empty();
    
    public let features = [VCARD_XMLNS];
    
    public override init() {
        
    }
    
    open func process(stanza: Stanza) throws {
        throw XMPPError(condition: .feature_not_implemented);
    }
        
    /**
     Publish vcard
     - parameter vcard: vcard to publish
     - parameter to:where to publish vcard
     */
    public func publish(vcard: VCard, to jid: BareJID?) async throws {
        let iq = Iq(type: .set, to: jid?.jid(), {
            vcard.toVCardTemp()
        });
        try await write(iq: iq)
    }
    
    /**
     Retrieve vcard for JID
     - parameter from: JID for which vcard should be retrieved
     */
    open func retrieveVCard(from jid: JID?) async throws -> VCard {
        let iq = Iq(type: .get, to: jid, {
            Element(name:"vCard", xmlns: VCardTempModule.VCARD_XMLNS)
        });

        let response = try await write(iq: iq);
        if let vcardEl = response.firstChild(name: "vCard", xmlns: VCardTempModule.VCARD_XMLNS), let vcard = VCard(vcardTemp: vcardEl) {
            return vcard;
        } else {
            return VCard();
        }
    }

}

extension VCard {
    
    public convenience init?(vcardTemp el: Element?) {
        guard let vcardTemp = el, vcardTemp.name == "vCard" && vcardTemp.xmlns == "vcard-temp" else {
            return nil;
        }
        self.init();
        
        self.bday = vcardTemp.firstChild(name: "BDAY")?.value;
        self.fn = vcardTemp.firstChild(name: "FN")?.value;
        
        if let n = vcardTemp.firstChild(name: "N") {
            self.surname = n.firstChild(name: "FAMILY")?.value;
            self.givenName = n.firstChild(name: "GIVEN")?.value;
            if let middleName = n.firstChild(name: "MIDDLE")?.value {
                self.additionalName.append(middleName);
            }
            self.namePrefixes = n.filterChildren(name: "PREFIX").compactMap({ $0.value });
            self.nameSuffixes = n.filterChildren(name: "SUFFIX").compactMap({ $0.value });
        }
        
        self.nicknames = vcardTemp.filterChildren(name: "NICKNAME").compactMap({ $0.value });
        
        self.title = vcardTemp.firstChild(name: "TITLE")?.value;
        self.role = vcardTemp.firstChild(name: "ROLE")?.value;
        self.note = vcardTemp.firstChild(name: "DESC")?.value;
        
        self.addresses = vcardTemp.filterChildren(name: "ADR").map({ el -> Address in
            let addr = Address();
            if el.hasChild(name: "WORK") {
                addr.types.append(.work);
            }
            if el.hasChild(name: "HOME") {
                addr.types.append(.home);
            }
            addr.street = el.firstChild(name: "STREET")?.value;
            addr.locality = el.firstChild(name: "LOCALITY")?.value;
            addr.postalCode = el.firstChild(name: "PCODE")?.value;
            addr.country = el.firstChild(name: "CTRY")?.value;
            addr.region = el.firstChild(name: "REGION")?.value;
            return addr;
        });
        
        self.emails = vcardTemp.filterChildren(name: "EMAIL").compactMap({ el -> Email? in
            guard let address = el.firstChild(name: "USERID")?.value else {
                return nil;
            }
            let email = Email(address: address);
            if el.hasChild(name: "WORK") {
                email.types.append(.work);
            }
            if el.hasChild(name: "HOME") {
                email.types.append(.home);
            }
            return email;
        })
        
        self.impps = vcardTemp.filterChildren(name: "JABBERID").compactMap({ el -> IMPP? in
            guard let val = el.value else {
                return nil;
            }
            return IMPP(uri: "xmpp:\(val)");
        });
        
        self.organizations = vcardTemp.filterChildren(name: "ORG").compactMap({ el -> Organization? in
            guard let orgname = el.firstChild(name: "ORGNAME")?.value else {
                return nil;
            }
            return Organization(name: orgname);
        })
        
        self.photos = vcardTemp.filterChildren(name: "PHOTO").compactMap({ el -> Photo? in
            if let binval = el.firstChild(name: "BINVAL")?.value?.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "") {
                return Photo(type: el.firstChild(name: "TYPE")?.value, binval: binval);
            }
            if let extval = el.firstChild(name: "EXTVAL")?.value?.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "") {
                return Photo(uri: extval);
            }
            return nil;
        });
        
        self.telephones = vcardTemp.filterChildren(name: "TEL").compactMap({ el -> Telephone? in
            guard let number = el.firstChild(name: "NUMBER")?.value else {
                return nil;
            }
            let phone = Telephone(number: number);
            if el.hasChild(name: "WORK") {
                phone.types.append(.work);
            }
            if el.hasChild(name: "HOME") {
                phone.types.append(.home);
            }
            if el.hasChild(name: "FAX") {
                phone.kinds.append(.fax);
            }
            if el.hasChild(name: "MGS") {
                phone.kinds.append(.msg);
            }
            if el.hasChild(name: "VOICE") {
                phone.kinds.append(.voice);
            }
            if el.hasChild(name: "CELL") {
                phone.kinds.append(.cell);
            }
            return phone;
        })
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
    
    private static let sha1Regex = try! NSRegularExpression(pattern: "[a-fA-F0-9]{40}");
    /// Hash of photo embedded in vcard-temp
    public var vcardTempPhoto:String? {
        get {
            guard let photoId = self.firstChild(name: "x", xmlns: "vcard-temp:x:update")?.firstChild(name: "photo")?.value else {
                return nil;
            }
            guard Presence.sha1Regex.numberOfMatches(in: photoId, options: [], range: NSRange(location: 0, length: photoId.count)) == 1 else {
                return nil;
            }
            return photoId;
        }
        set {
            var x = self.firstChild(name: "x", xmlns: "vcard-temp:x:update");
            var photo = x?.firstChild(name: "photo");
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

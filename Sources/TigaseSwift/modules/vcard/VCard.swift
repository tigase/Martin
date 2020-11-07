//
// VCard.swift
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

open class VCard {
    
    open var bday: String?;
    
    open var fn: String?;
    
    open var surname: String?;
    
    open var givenName: String?;
    
    open var additionalName: [String] = [];

    open var namePrefixes: [String] = [];
    
    open var nameSuffixes: [String] = [];
    
    open var nicknames: [String] = [];
    
    open var title: String?;
    
    open var role: String?;
    
    open var note: String?;
    
    open var addresses: [Address] = [];
    
    open var emails: [Email] = [];
    
    open var impps: [IMPP] = [];
    
    open var organizations: [Organization] = [];

    open var photos: [Photo] = [];
    
    open var telephones: [Telephone] = [];

    public init() {
        
    }
    
    public enum EntryType {
        case home
        case work
        
        public static let allValues: [EntryType] = [.home, .work];
    }
    
    open class VCardEntryItemTypeAware {
        
        open var types: [EntryType];
        
        public init(types: [EntryType]) {
            self.types = types;
        }
        
    }
    
    open class Address: VCardEntryItemTypeAware, VCardEntryProtocol {
        
        open var ext: String?;
        open var street: String?;
        open var locality: String?;
        open var region: String?;
        open var postalCode: String?;
        open var country: String?;

        open var isEmpty: Bool {
            return (ext?.isEmpty ?? true) && (street?.isEmpty ?? true) && (locality?.isEmpty ?? true) && (region?.isEmpty ?? true) && (postalCode?.isEmpty ?? true) && (country?.isEmpty ?? true);
        }

        public override init(types: [EntryType]=[]) {
            super.init(types: types);
        }
        
    }

    open class Email: VCardEntryItemTypeAware, VCardEntryProtocol {
        
        open var address: String?;
        open var isEmpty: Bool {
            return address?.isEmpty ?? true;
        }
        
        public init(address: String?, types: [EntryType] = []) {
            self.address = address;
            super.init(types: types);
        }
        
    }
    
    open class IMPP: VCardEntryItemTypeAware, VCardEntryProtocol {
        
        open var uri: String?;
        open var isEmpty: Bool {
            return uri?.isEmpty ?? true;
        }
        
        public init(uri: String?, types: [EntryType] = []) {
            self.uri = uri;
            super.init(types: types);
        }
        
    }
    
    open class Organization: VCardEntryItemTypeAware {
        
        open var name: String?;
        open var isEmpty: Bool {
            return name?.isEmpty ?? true;
        }
        
        public init(name: String?, types: [EntryType] = []) {
            self.name = name;
            super.init(types: types);
        }
        
    }
    
    open class Photo: VCardEntryItemTypeAware, VCardEntryProtocol {
        
        open var uri: String?;
        open var type: String?;
        open var binval: String?;
        open var isEmpty: Bool {
            return (uri?.isEmpty ?? true) && ((type?.isEmpty ?? true) || (binval?.isEmpty ?? true));
        }
        
        public init(uri: String? = nil, type: String? = nil, binval: String? = nil, types: [EntryType] = []) {
            self.uri = uri;
            self.type = type;
            self.binval = binval;
            super.init(types: types);
        }
    }
    
    open class Telephone: VCardEntryItemTypeAware, VCardEntryProtocol {
        
        open var number: String? {
            get {
                if uri == nil {
                    return nil;
                } else {
                    return uri!.hasPrefix("tel:") ? String(uri!.suffix(from: uri!.index(uri!.startIndex, offsetBy: 4))) : uri
                }
            }
            set {
                if newValue == nil {
                    uri = nil;
                } else {
                    uri = "tel:\(newValue!)"
                }
            }
        }
        open var uri: String?;
        open var kinds: [Kind];
        open var isEmpty: Bool {
            return uri?.isEmpty ?? true;
        }
        
        convenience public init(number: String, kinds: [Kind] = [], types: [EntryType] = []) {
            self.init(uri: "tel:\(number)", kinds: kinds, types: types);
        }
        
        public init(uri: String?, kinds: [Kind] = [], types: [EntryType] = []) {
            self.kinds = kinds;
            self.uri = uri;
            super.init(types: types);
        }
        
        public enum Kind {
            case fax
            case msg
            case voice
            case cell
        }
    }
}

public protocol VCardEntryProtocol {
    
    var isEmpty: Bool { get };
    
}


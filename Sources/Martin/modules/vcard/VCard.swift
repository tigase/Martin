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

protocol VCardEntryItemTypeAware {
    var types: [VCard.EntryType] { get set }
}

public struct VCard: Sendable {
    
    public var bday: String?;
    
    public var fn: String?;
    
    public var surname: String?;
    
    public var givenName: String?;
    
    public var additionalName: [String] = [];

    public var namePrefixes: [String] = [];
    
    public var nameSuffixes: [String] = [];
    
    public var nicknames: [String] = [];
    
    public var title: String?;
    
    public var role: String?;
    
    public var note: String?;
    
    public var addresses: [Address] = [];
    
    public var emails: [Email] = [];
    
    public var impps: [IMPP] = [];
    
    public var organizations: [Organization] = [];

    public var photos: [Photo] = [];
    
    public var telephones: [Telephone] = [];

    public init() {
        
    }
    
    public enum EntryType : Sendable {
        case home
        case work
        
        public static let allValues: [EntryType] = [.home, .work];
    }
        
    public final class Address: VCardEntryItemTypeAware, VCardEntryProtocol, @unchecked Sendable {
        
        public var types: [EntryType];
        public var ext: String?;
        public var street: String?;
        public var locality: String?;
        public var region: String?;
        public var postalCode: String?;
        public var country: String?;

        public var isEmpty: Bool {
            return (ext?.isEmpty ?? true) && (street?.isEmpty ?? true) && (locality?.isEmpty ?? true) && (region?.isEmpty ?? true) && (postalCode?.isEmpty ?? true) && (country?.isEmpty ?? true);
        }

        public init(types: [EntryType]=[]) {
            self.types = types;
        }
        
    }

    public final class Email: VCardEntryItemTypeAware, VCardEntryProtocol, @unchecked Sendable {
        
        public var types: [EntryType];
        public var address: String?;
        public var isEmpty: Bool {
            return address?.isEmpty ?? true;
        }
        
        public init(address: String?, types: [EntryType] = []) {
            self.address = address;
            self.types = types;
        }
        
    }
    
    public final class IMPP: VCardEntryItemTypeAware, VCardEntryProtocol, @unchecked Sendable {
        
        public var types: [EntryType];
        public var uri: String?;
        public var isEmpty: Bool {
            return uri?.isEmpty ?? true;
        }
        
        public init(uri: String?, types: [EntryType] = []) {
            self.uri = uri;
            self.types = types;
        }
        
    }
    
    public final class Organization: VCardEntryItemTypeAware, @unchecked Sendable {
        
        public var types: [EntryType];
        public var name: String?;
        public var isEmpty: Bool {
            return name?.isEmpty ?? true;
        }
        
        public init(name: String?, types: [EntryType] = []) {
            self.name = name;
            self.types = types;
        }
        
    }
    
    public final class Photo: VCardEntryItemTypeAware, VCardEntryProtocol, @unchecked Sendable {
        
        public var types: [EntryType];
        public var uri: String?;
        public var type: String?;
        public var binval: String?;
        public var isEmpty: Bool {
            return (uri?.isEmpty ?? true) && ((type?.isEmpty ?? true) || (binval?.isEmpty ?? true));
        }
        
        public init(uri: String? = nil, type: String? = nil, binval: String? = nil, types: [EntryType] = []) {
            self.uri = uri;
            self.type = type;
            self.binval = binval;
            self.types = types;
        }
    }
    
    public final class Telephone: VCardEntryItemTypeAware, VCardEntryProtocol, @unchecked Sendable {
        
        public var types: [EntryType];
        public var number: String? {
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
        public var uri: String?;
        public var kinds: [Kind];
        public var isEmpty: Bool {
            return uri?.isEmpty ?? true;
        }
        
        public convenience init(number: String, kinds: [Kind] = [], types: [EntryType] = []) {
            self.init(uri: "tel:\(number)", kinds: kinds, types: types);
        }
        
        public init(uri: String?, kinds: [Kind] = [], types: [EntryType] = []) {
            self.kinds = kinds;
            self.uri = uri;
            self.types = types;
        }
        
        public enum Kind: Sendable {
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


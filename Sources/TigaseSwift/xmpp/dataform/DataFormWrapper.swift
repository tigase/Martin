//
// DataFormWrapper.swift
//
// TigaseSwift
// Copyright (C) 2022 "Tigase, Inc." <office@tigase.com>
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


open class DataFormWrapper: DataFormProtocol {
    
    @propertyWrapper
    public struct Field<Value> {

        public static subscript<T: DataFormWrapper>(
            _enclosingInstance instance: T,
            wrapped wrappedKeyPath: ReferenceWritableKeyPath<T,Value?>,
            storage storageKeyPath: ReferenceWritableKeyPath<T,Self>
        ) -> Value? {
            get {
                let key = instance[keyPath: storageKeyPath].fieldKey;
                switch Value.self {
                case is [JID].Type:
                    return instance.form.value(for: key, type: [JID].self) as? Value;
                case is [String].Type:
                    return instance.form.value(for: key, type: [String].self) as? Value;
                case is JID.Type:
                    return instance.form.value(for: key, type: JID.self) as? Value;
                case is Bool.Type:
                    return instance.form.value(for: key, type: Bool.self) as? Value;
                case is String.Type:
                    return instance.form.value(for: key, type: String.self) as? Value;
                case is Date.Type:
                    return TimestampHelper.parse(timestamp: instance.form.value(for: key, type: String.self)) as? Value;
                case let valueType as LosslessStringConvertible.Type:
                    guard let value = instance.form.value(for: key, type: String.self) else {
                        return nil;
                    }
                    return valueType.init(value) as? Value;
                default:
                    fatalError();
                }
            }
            set {
                let key = instance[keyPath: storageKeyPath].fieldKey;
                let type = instance[keyPath: storageKeyPath].type;
                switch Value.self {
                case is [JID].Type:
                    instance.form.add(field: .JIDMulti(var: key, values: (newValue as? [JID]) ?? []));
                case is [String].Type:
                    if let type = type {
                        switch type {
                        case .listMulti:
                            instance.form.add(field: .ListMulti(var: key, values: (newValue as? [String]) ?? []));
                        case .textMulti:
                            instance.form.add(field: .TextMulti(var: key, values: (newValue as? [String]) ?? []));
                        case .jidMulti:
                            instance.form.add(field: .JIDMulti(var: key, values: (newValue as? [String])?.compactMap({ JID($0) }) ?? []))
                        default:
                            fatalError();
                        }
                    } else {
                        instance.form.add(field: .TextMulti(var: key, values: (newValue as? [String]) ?? []));
                    }
                case is JID.Type:
                    instance.form.add(field: .JIDSingle(var: key, value: newValue as? JID));
                case is Bool.Type:
                    instance.form.add(field: .Boolean(var: key, value: (newValue as? Bool) ?? false));
                case is Date.Type:
                    let date = newValue as? Date;
                    instance.form.add(field: .TextSingle(var: key, value: date != nil ? TimestampHelper.format(date: date!) : nil ))
                case is LosslessStringConvertible.Type:
                    if let type = type {
                        switch type {
                        case .boolean:
                            instance.form.add(field: .Boolean(var: key, value: Bool((newValue as? LosslessStringConvertible)?.description ?? "") ?? false))
                        case .fixed:
                            instance.form.add(field: .Fixed(var: key, value: (newValue as? LosslessStringConvertible)?.description));
                        case .hidden:
                            instance.form.add(field: .Hidden(var: key, value: (newValue as? LosslessStringConvertible)?.description));
                        case .textPrivate:
                            instance.form.add(field: .TextPrivate(var: key, value: (newValue as? LosslessStringConvertible)?.description))
                        case .textSingle:
                            instance.form.add(field: .TextSingle(var: key, value: (newValue as? LosslessStringConvertible)?.description))
                        case .listSingle:
                            instance.form.add(field: .ListSingle(var: key, value: (newValue as? LosslessStringConvertible)?.description))
                        default:
                            fatalError();
                        }
                    } else {
                        if Value.self is DataFormEnumProtocol.Type {
                            instance.form.add(field: .ListSingle(var: key, value: (newValue as? LosslessStringConvertible)?.description));
                        } else {
                            instance.form.add(field: .TextSingle(var: key, value: (newValue as? LosslessStringConvertible)?.description));
                        }
                    }
                default:
                    fatalError();
                }
            }
        }
        
        public var wrappedValue: Value? {
            get { fatalError() }
            set { fatalError() }
        }
        
        private let fieldKey: String;
        private let type: DataForm.Field.FieldType?;
        
        public init(_ fieldKey: String, type: DataForm.Field.FieldType? = nil) {
            self.fieldKey = fieldKey;
            self.type = type;
        }
    }
    
    public let form: DataForm;
    public var fields: [DataForm.Field] {
        return form.fields;
    }
    
    @Field("FORM_TYPE", type: .hidden)
    public var FORM_TYPE: String?;
        
    public init(form: DataForm? = nil) {
        self.form = form ?? DataForm(type: .form);
    }
    
    open func hasField(for key: String) -> Bool {
        return self.form.hasField(for: key);
    }
    
    open func field(for key: String) -> DataForm.Field? {
        return self.form.field(for: key);
    }
    
    open func field<F: DataForm.Field>(for key: String) -> F? {
        return self.form.field(for: key);
    }
    
    open func fieldType(_ key: String) -> DataForm.Field.FieldType? {
        return self.form.fieldType(for: key);
    }

    open func add(field: DataForm.Field) {
        self.form.add(field: field);
    }
    
    open func remove(field: DataForm.Field) {
        self.form.remove(field: field);
    }
    
    open func value<V: LosslessStringConvertible>(for key: String, type: V.Type) -> V? {
        return self.form.value(for: key, type: type);
    }
    
    open func value(for key: String, type: [String].Type) -> [String]? {
        return self.form.value(for: key, type: type);
    }
    
    open func value(for key: String, type: [JID].Type) -> [JID]? {
        return self.form.value(for: key, type: type);
    }
    
    open func element(type: DataForm.FormType, onlyModified: Bool) -> Element {
        return self.form.element(type: type, onlyModified: onlyModified);
    }
}

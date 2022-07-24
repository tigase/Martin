//
// MAMQueryForm.swift
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

open class MAMQueryForm: DataFormWrapper, Sendable {
    
    @Field("with")
    public var with: JID?;
    @Field("start")
    public var start: Date?;
    @Field("end")
    public var end: Date?;
    @Field("before-id")
    public var beforeId: String?;
    @Field("after-id")
    public var afterId: String?;
    @Field("ids")
    public var ids: [String]?;
    
    public init(version: MessageArchiveManagementModule.Version, with jid: JID? = nil, start: Date? = nil, end: Date? = nil, beforeId: String? = nil, afterId: String? = nil) {
        super.init(form: nil);
        FORM_TYPE = version.rawValue;
        if let jid = jid {
            with = jid;
        }
        if let start = start {
            self.start = start;
        }
        if let end = end {
            self.end = end;
        }
        if let beforeId = beforeId {
            self.beforeId = beforeId;
        }
        if let afterId = afterId {
            self.afterId = afterId;
        }
    }
    
    public init(version: MessageArchiveManagementModule.Version, with jid: JID? = nil, start: Date? = nil, end: Date? = nil, ids: [String]) {
        super.init(form: nil);
        FORM_TYPE = version.rawValue;
        if let jid = jid {
            with = jid;
        }
        if let start = start {
            self.start = start;
        }
        if let end = end {
            self.end = end;
        }
        self.ids = ids;
    }
    
    public override init(form: DataForm? = nil) {
        super.init(form: form);
    }
}

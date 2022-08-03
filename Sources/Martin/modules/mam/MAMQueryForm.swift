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

open class MAMQueryForm: DataFormWrapper {
    
    @Field("with")
    public var with: JID?;
    @Field("start")
    public var start: String?;
    @Field("end")
    public var end: String?;
    
    public init(version: MessageArchiveManagementModule.Version) {
        super.init(form: nil);
        FORM_TYPE = version.rawValue;
    }
    
    public override init(form: DataForm? = nil) {
        super.init(form: form);
    }
}

extension MessageArchiveManagementModule {
    
    open func queryItems(version: Version? = nil, componentJid: JID? = nil, node: String? = nil, query: MAMQueryForm, queryId: String, rsm: RSM.Query? = nil, completionHandler: @escaping (Result<QueryResult,XMPPError>)->Void)
    {
        guard let version = version ?? self.availableVersions.first else {
            completionHandler(.failure(.feature_not_implemented))
            return;
        }

        queryItems(version: version, componentJid: componentJid, node: node, query: query.element(type: .submit, onlyModified: true), queryId: queryId, rsm: rsm, errorDecoder: XMPPError.from(stanza:), completionHandler: { result in
            completionHandler(result.flatMap { response in
                guard let fin = response.findChild(name: "fin", xmlns: version.rawValue) else {
                    return .failure(.undefined_condition);
                }
                
                let rsmResult = RSM.Result(from: fin.findChild(name: "set", xmlns: "http://jabber.org/protocol/rsm"));
    
                let complete = ("true" == fin.getAttribute("complete")) || MessageArchiveManagementModule.isComplete(rsm: rsmResult);
                return .success(QueryResult(queryId: queryId, complete: complete, rsm: rsmResult));
            })
        });
    }
    
    open func retrieveForm(version: Version? = nil, componentJid: JID? = nil, resultHandler: @escaping (Result<MAMQueryForm,XMPPError>)->Void) {
        guard let version = version ?? availableVersions.first else {
            resultHandler(.failure(.feature_not_implemented));
            return;
        }
        retieveForm(version: version, componentJid: componentJid, errorDecoder: XMPPError.from(stanza: ), completionHandler: { result in
            resultHandler(result.flatMap { stanza in
                guard let query = stanza.findChild(name: "query", xmlns: version.rawValue), let x = query.findChild(name: "x", xmlns: "jabber:x:data"), let form = DataForm(element: x) else {
                    return .failure(.undefined_condition);
                }
                return .success(MAMQueryForm(form: form));
            })
        });
    }
}

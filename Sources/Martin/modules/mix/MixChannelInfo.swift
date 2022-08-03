//
// MixChannelInfo.swift
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

open class MixChannelInfo: DataFormWrapper {
    
    @Field("Name")
    public var name: String?;
    @Field("Description")
    public var description: String?
    @Field("Contact")
    public var contact: [JID]?;
    
    public convenience init?(element: Element) {
        guard let form = DataForm(element: element) else {
            return nil;
        }
        self.init(form: form);
    }
    
    public override init(form: DataForm? = nil) {
        super.init(form: form);
    }
    
    public init(channelInfo: ChannelInfo) {
        super.init(form: nil);
        FORM_TYPE = MixModule.CORE_XMLNS;
        name = channelInfo.name;
        description = channelInfo.description;
        contact = channelInfo.contact;
    }
    
    open func channelInfo() -> ChannelInfo {
        return .init(name: name, description: description, contact: contact ?? []);
    }
}

extension MixModule {
    
    open func publishInfo(for channelJid: BareJID, info: MixChannelInfo, completionHandler: ((Result<Void,XMPPError>)->Void)?) {
        pubsubModule.publishItem(at: channelJid, to: "urn:xmpp:mix:nodes:info", payload: info.element(type: .form, onlyModified: false), completionHandler: { response in
            switch response {
            case .success(_):
                completionHandler?(.success(Void()));
            case .failure(let error):
                completionHandler?(.failure(error.error));
            }
        });
    }

    open func retrieveInfo(for channelJid: BareJID, resultHandler: @escaping (Result<MixChannelInfo,XMPPError>)->Void) {
        pubsubModule.retrieveItems(from: channelJid, for: "urn:xmpp:mix:nodes:info", completionHandler: { result in
            switch result {
            case .success(let items):
                guard let item = items.items.sorted(by: { (i1, i2) in return i1.id > i2.id }).first else {
                    resultHandler(.failure(.item_not_found));
                    return;
                }
                guard let context = self.context, let payload = item.payload, let info = MixChannelInfo(element: payload) else {
                    resultHandler(.failure(.undefined_condition));
                    return;
                }
                if let channel = self.channelManager.channel(for: context, with: channelJid) {
                    channel.update(info: info.channelInfo());
                }
                resultHandler(.success(info));
            case .failure(let pubsubError):
                resultHandler(.failure(pubsubError.error));
            }
        });
    }
}

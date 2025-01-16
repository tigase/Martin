//
// AbstractPEPModule.swift
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

open class AbstractPEPModule: XmppModuleBase {
    
    open private(set) var pubsubModule: PubSubModule! {
        didSet {
            pubsubModule?.itemsEvents.sink(receiveValue: { [weak self] notification in
                self?.onItemNotification(notification: notification);
            }).store(in: self);
        }
    }

    @Published
    open var isPepAvailable: Bool = false;
    
    open override weak var context: Context? {
        didSet {
            pubsubModule = context?.module(.pubsub);
            context?.module(.disco).$accountDiscoResult.sink(receiveValue: { [weak self] result in
                self?.isPepAvailable = result.identities.contains(where: { $0.category == "pubsub" && $0.type == "pep" });
            }).store(in: self);
        }
    }
    
    open func onItemNotification(notification: PubSubModule.ItemNotification) {
        
    }
}

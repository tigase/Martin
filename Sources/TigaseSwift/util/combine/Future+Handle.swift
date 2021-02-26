//
// Future+Handle.swift
//
// TigaseSwift
// Copyright (C) 2021 "Tigase, Inc." <office@tigase.com>
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
import Combine

extension Future {
    
    public func handle(_ fn: @escaping (Result<Output,Failure>)->Void) {
        var cancellable: AnyCancellable?;
        cancellable = self.sink(receiveCompletion: { completion in
            switch completion {
            case .finished:
                break;
            case .failure(let err):
                fn(.failure(err));
            }
            cancellable?.cancel();
        }, receiveValue: { result in
            fn(.success(result));
            cancellable?.cancel();
        });
    }
    
}

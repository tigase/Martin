//
// Sequence+Extensions.swift
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

extension Sequence {
    
    public func mapReduce<T>(_ transform: (Element) -> [T]) -> [T] {
        var values = [T]();
        for element in self {
            values.append(contentsOf: transform(element));
        }
        return values;
    }

    public func asyncMap<T>(_ transform: (Element) async -> T) async -> [T] {
        var values = [T]();
        for element in self {
            await values.append(transform(element));
        }
        return values;
    }

    public func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values = [T]();
        for element in self {
            try await values.append(transform(element));
        }
        return values;
    }

    public func asyncMapReduce<T>(_ transform: (Element) async throws -> [T]) async rethrows -> [T] {
        var values = [T]();
        for element in self {
            try await values.append(contentsOf: transform(element));
        }
        return values;
    }

    public func concurrentMap<T>(_ transform: @escaping (Element) async throws -> T) async throws -> [T] {
        let tasks = map({ element in
            Task {
                try await transform(element);
            }
        });
        
        return try await tasks.asyncMap({ try await $0.value });
    }
    
    public func concurrentMap<T>(_ transform: @escaping (Element) async -> T) async -> [T] {
        let tasks = map({ element in
            Task {
                await transform(element);
            }
        });
        
        return await tasks.asyncMap({ await $0.value });
    }

    public func concurrentMapReduce<T>(_ transform: @escaping (Element) async throws -> [T]) async throws -> [T] {
        let tasks = map({ element in
            Task {
                try await transform(element);
            }
        });
        
        return try await tasks.asyncMapReduce({ try await $0.value });
    }

    public func concurrentMapReduce<T>(_ transform: @escaping (Element) async -> [T]) async -> [T] {
        let tasks = map({ element in
            Task {
                await transform(element);
            }
        });
        
        return await tasks.asyncMapReduce({ await $0.value });
    }

    public func concurrentForEach(_ body: @escaping (Element) async -> Void) async {
        let tasks = map({ element in
            Task {
                await body(element);
            }
        })
        
        for task in tasks {
            await task.value;
        }
    }
}

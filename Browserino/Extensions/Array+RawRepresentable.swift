//
//  Array+RawRepresentable.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import Foundation

#if compiler(>=6.0)
extension Array: @retroactive RawRepresentable where Element: Codable {}
#else
extension Array: RawRepresentable where Element: Codable {}
#endif

extension Array where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

#if compiler(>=6.0)
extension Dictionary: @retroactive RawRepresentable where Key == String, Value: Codable {}
#else
extension Dictionary: RawRepresentable where Key == String, Value: Codable {}
#endif

extension Dictionary where Key == String, Value: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode(Self.self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return result
    }
}

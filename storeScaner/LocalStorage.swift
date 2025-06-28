//
//  LocalStorage.swift
//  storeScaner
//
//  Created by Jacek Kałużny on 18/06/2025.
//


import Foundation

struct LocalStorage {
    static func save<T: Codable>(_ object: T, to filename: String) {
        let url = getURL(for: filename)
        do {
            let data = try JSONEncoder().encode(object)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save \(filename): \(error)")
        }
    }

    static func load<T: Codable>(_ type: T.Type, from filename: String) -> T? {
        let url = getURL(for: filename)
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Failed to load \(filename): \(error)")
            return nil
        }
    }

    private static func getURL(for filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }
}

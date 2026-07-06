//
//  ImportError.swift
//  storeScaner
//
//  Created by Jacek Kałużny on 24/09/2025.
//


import Foundation

enum ImportError: Error {
    case invalidFormat
    case unsupportedFile
    case decodingFailed
}

struct InventoryImporter {
    static func importProductUpdatesCSV(data: Data, delimiter: String = ",") throws -> [ProductUpdate] {
        guard let csv = String(data: data, encoding: .utf8) else {
            print("file Not Loaded")
            throw ImportError.unsupportedFile
        }
        print("file Loaded (\(csv.count))")
        let normalized = csv.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n").map(String.init)
//        let lines = csv.split(separator: "\n").map(String.init)
        print("file lines count is \(lines.count)")

        return lines.dropFirst().compactMap { line in
            
            print("_________")
            let fields = line.split(separator: Character(delimiter)).map { $0.trimmingCharacters(in: .whitespaces) }
            print("🔹 Parsed line into \(fields.count) fields: \(fields)")

            guard fields.count >= 5 else { return nil }

            let itemID = fields[0]
            let delta = Int(fields[1]) ?? 0
            let price = Double(fields[2]) ?? 0
            let currency = fields[3]
            let timestamp = Date().timeIntervalSince1970
            let origin = fields[5]

            return ProductUpdate(
                productItemID: itemID,
                delta: delta,
                price: price,
                currency: currency,
                timestamp: timestamp,
                originPeerID: origin
            )
        }
    }


    static func importFromJSON(data: Data) throws -> (products: [ProductType], updates: [ProductUpdate], inventory: [InventoryItem]) {
        let decoder = JSONDecoder()

        // First try full sync payload
        if let payload = try? decoder.decode(SyncMetaPayload.self, from: data) {
            return ([], payload.productUpdates, []) // no productTypes or inventory
        }

        // Try arrays
        if let inventory = try? decoder.decode([InventoryItem].self, from: data) {
            return ([], [], inventory)
        }

        if let products = try? decoder.decode([ProductType].self, from: data) {
            return (products, [], [])
        }

        if let updates = try? decoder.decode([ProductUpdate].self, from: data) {
            return ([], updates, [])
        }

        throw ImportError.invalidFormat
    }
    static func importProductUpdates(data: Data) throws -> [ProductUpdate] {
        let decoder = JSONDecoder()
        guard let updates = try? decoder.decode([ProductUpdate].self, from: data) else {
            throw ImportError.decodingFailed
        }
        return updates
    }
}

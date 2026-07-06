//
//  ExportFormat.swift
//  storeScaner
//
//  Created by Jacek Kałużny on 24/09/2025.
//


import Foundation
import SwiftUI
struct EnrichedInventoryItem: Codable {
    let productItemID: String
    let productName: String
    let category: String
    let gender: String?
    let size: String?
    let color: String?
    let count: Int
    let lastUpdateTimestamp: TimeInterval
}

enum ExportFormat {
    case json, csv
}

struct FileExporter {
    static func exportProductUpdatesBackup(_ updates: [ProductUpdate]) -> URL? {
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "product_updates_backup_\(timestamp).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            let data = try JSONEncoder().encode(updates)
            try data.write(to: url)
            return url
        } catch {
            print("❌ Backup export failed: \(error)")
            return nil
        }
    }
    static func exportProductUpdates(_ updates: [ProductUpdate]) -> URL? {
        let fileName = "product_updates_export.json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            let data = try JSONEncoder().encode(updates)
            try data.write(to: url)
            print("✅ Exported product updates to: \(url.path)")
            return url
        } catch {
            print("❌ Failed to export updates: \(error)")
            return nil
        }
    }
    static func exportInventory(_ items: [InventoryItem], productTypes: [ProductType], as format: ExportFormat) -> URL? {
        let enriched: [EnrichedInventoryItem] = items.map { item in
            // Extract prefix to match ProductType
            let prefix = item.productItemID.split(separator: "_").first.map(String.init) ?? item.productItemID
            let product = productTypes.first(where: { $0.productID == prefix })

            // Try to extract gender, size, color from ID (optional)
            let idParts = Array(item.productItemID.split(separator: "_").dropFirst())
            let gender = idParts.indices.contains(0) ? String(idParts[0]) : nil
            let size   = idParts.indices.contains(1) ? String(idParts[1]) : nil
            let color  = idParts.indices.contains(2) ? String(idParts[2]) : nil


            return EnrichedInventoryItem(
                productItemID: item.productItemID,
                productName: product?.name ?? "(unknown)",
                category: product?.category ?? "(unknown)",
                gender: gender,
                size: size,
                color: color,
                count: item.count,
                lastUpdateTimestamp: item.lastUpdateTimestamp
            )
        }

        let fileName = "inventory_export.\(format == .json ? "json" : "csv")"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        switch format {
        case .json:
            do {
                let data = try JSONEncoder().encode(enriched)
                try data.write(to: url)
                print("✅ JSON written to: \(url.path)")
                return url
            } catch {
                print("❌ JSON export error: \(error)")
                return nil
            }

        case .csv:
            var csv = "productItemID,productName,category,gender,size,color,count,lastUpdateTimestamp\n"
            for entry in enriched {
                csv += "\(entry.productItemID),\"\(entry.productName)\",\(entry.category),\(entry.gender ?? ""),\(entry.size ?? ""),\(entry.color ?? ""),\(entry.count),\(entry.lastUpdateTimestamp)\n"
            }
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                print("✅ CSV written to: \(url.path)")
                return url
            } catch {
                print("❌ CSV export error: \(error)")
                return nil
            }
        }
    }
    
        static func exportProductUpdatesAsCSV(_ updates: [ProductUpdate]) -> URL? {
            let fileName = "product_updates.csv"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            var csv = "productItemID,delta,price,currency,timestamp,originPeerID\n"
            for update in updates {
                csv += "\"\(update.productItemID)\",\(update.delta),\(update.price),\(update.currency),\(update.timestamp),\(update.originPeerID)\n"
            }

            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                return url
            } catch {
                print("❌ CSV export failed: \(error)")
                return nil
            }
        }
    
}
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

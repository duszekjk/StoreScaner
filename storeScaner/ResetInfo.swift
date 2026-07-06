//
//  ResetInfo.swift
//  storeScaner
//
//  Created by Jacek Kałużny on 26/09/2025.
//
import Foundation
import MultipeerConnectivity
import SwiftUI
import CryptoKit

struct ResetInfo: Codable {
    let type: String
    let resetTimestamp: TimeInterval
    let origin: String
}
extension MPConnectionManager {
    func resetAllData(withUpdates updates: [ProductUpdate]) {
        let now = Date().timeIntervalSince1970
        self.resetTimestamp = now

        let filtered = updates.filter { $0.timestamp >= now }
        self.productUpdates = filtered
        self.seenUpdateKeys = Set(filtered.map(\.uniqueKey))

        recalculateInventory()

        sendResetBroadcast(timestamp: now)
        sendCurrentState()

        logEvent("🧨 Reset applied @ \(now), kept \(filtered.count) updates")
    }

    func sendResetBroadcast(timestamp: TimeInterval) {
        let payload = ResetInfo(type: "reset", resetTimestamp: timestamp, origin: self.myPeerId.displayName)
        if let data = try? JSONEncoder().encode(payload) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
            logEvent("📡 Sent reset broadcast @ \(timestamp)")
        }
    }

    func recalculateInventory() {
        self.inventory = []
        for update in self.productUpdates {
            if let resetTimestamp
            {
                print("\(update.timestamp) > \(resetTimestamp) (\(update.timestamp - resetTimestamp)")
            }
            if let i = self.inventory.firstIndex(where: { $0.productItemID == update.productItemID }) {
                self.inventory[i].count += update.delta
                self.inventory[i].lastUpdateTimestamp = max(self.inventory[i].lastUpdateTimestamp, update.timestamp)
            } else {
                self.inventory.append(InventoryItem(
                    productItemID: update.productItemID,
                    count: update.delta,
                    lastUpdateTimestamp: update.timestamp
                ))
            }
        }
    }
}

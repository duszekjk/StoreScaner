//
//  Sync.swift
//  storeScaner
//
//  Created by Jacek Kałużny on 29/06/2025.
// 219478jfaskkahfueh828ue82u1ye2189eu2eu9182ye8ehfafh9832fygui78778hwaof6d57didid5i55d56dilhhlpza
import Foundation
import MultipeerConnectivity
import SwiftUI
import CryptoKit
import Network

extension MPConnectionManager {
    private var syncToken: String { "219478jfaskkahfueh828ue82u1ye2189eu2eu9182ye8ehfafh9832fygui78778hwaof6d57didid5i55d56dilhhlpza" }



    func syncWithServerIfGoodConnection() {
        // 1. Skip if failed recently
        if let lastFail = lastFailedInternetSync, Date().timeIntervalSince(lastFail) < 900 {
            logEvent("⏱ Skipping internet sync (last attempt failed <15min ago)")
            return
        }

        // 2. Monitor connection
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            monitor.cancel()

            guard path.status == .satisfied else {
                self.logEvent("📡 No internet")
                return
            }

            // Accept good WiFi or cellular
            if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.cellular) {
                self.performServerSync()
            } else {
                self.logEvent("🚫 Skipping sync (not a usable interface)")
            }
        }
        monitor.start(queue: DispatchQueue(label: "InternetCheck"))
    }

    private func performServerSync() {
        let downloadURL = URL(string: "https://www.duszekjk.com/paradiso/api/download/")!
        var downloadRequest = URLRequest(url: downloadURL)
        downloadRequest.httpMethod = "GET"
        downloadRequest.setValue("Bearer \(syncToken)", forHTTPHeaderField: "Authorization")
        downloadRequest.timeoutInterval = 15

        URLSession.shared.dataTask(with: downloadRequest) { data, _, error in
            if let error = error as? URLError, error.code == .timedOut {
                self.logEvent("🕒 Server sync timed out")
                self.lastFailedInternetSync = Date()
                return
            }

            guard let data = data, error == nil else {
                self.logEvent("❌ Download error: \(error?.localizedDescription ?? "Unknown")")
                return
            }

            DispatchQueue.main.async {
                self.logEvent("☁️ Downloaded state from server")
                self.mergeServerState(data)

                // Now upload
                self.uploadMergedStateToServer()
            }
        }.resume()
    }

    private func uploadMergedStateToServer() {
        let uploadURL = URL(string: "https://www.duszekjk.com/paradisoapp/api/upload/")!
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(syncToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let payload = SyncMetaPayload(
            deviceID: myPeerId.displayName,
            payloadHash: computePayloadHash(),
            productTypeHashes: productTypeHashes(),
            productUpdates: productUpdates
        )

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            logEvent("❌ Failed to encode sync payload")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let http = response as? HTTPURLResponse {
                self.logEvent("📡 Upload HTTP status: \(http.statusCode)")
            }

            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                self.logEvent("📡 Upload response: \(responseString)")
            }

            if let error = error {
                self.logEvent("❌ Upload error: \(error.localizedDescription)")
            } else {
                self.logEvent("☁️ Upload request completed")
            }
        }.resume()
    }


    private func mergeServerState(_ data: Data) {
        guard let server = try? JSONDecoder().decode(SyncMetaPayload.self, from: data) else {
            logEvent("❌ Merge failed (decode error)")
            return
        }

        // Merge updates
        let knownUpdates = Set(productUpdates.map(\.uniqueKey))
        for update in server.productUpdates where !knownUpdates.contains(update.uniqueKey) {
            if(update.timestamp > resetTimestamp ?? 0)
            {
                seenUpdateKeys.insert(update.uniqueKey)
                productUpdates.append(update)
                
                if let idx = inventory.firstIndex(where: { $0.productItemID == update.productItemID }) {
                    inventory[idx].count += update.delta
                    inventory[idx].lastUpdateTimestamp = max(inventory[idx].lastUpdateTimestamp, update.timestamp)
                } else {
                    print("inventory.append(0 2uruqjkd[2Q0")
                    if(update.timestamp > resetTimestamp ?? 0)
                    {
                        inventory.append(InventoryItem(
                            productItemID: update.productItemID,
                            count: update.delta,
                            lastUpdateTimestamp: update.timestamp
                        ))
                    }
                }
            }
        }

        // Compare hashes, request missing productTypes
        let localHashes = self.productTypeHashes()
        let serverHashes = server.productTypeHashes
        let missing: [String]
        if serverHashes.isEmpty {
            // 🆕 serwer nie zna niczego – wyślij wszystko
            
            missing = productTypes.map { $0.productID }
        } else {
            missing = serverHashes.filter { pid, remoteHash in
                localHashes[pid] != remoteHash
            }.map(\.key)
        }
        if !missing.isEmpty {
            let request = ProductTypeRequestPayload(type: "requestProductTypes", productIDs: missing)
            if let data = try? JSONEncoder().encode(request) {
                self.sendServerRequest(data)
                self.logEvent("🌐 Requested \(missing.count) ProductTypes from server")
            }
        } else {
            self.logEvent("🌐 ProductTypes already up to date")
        }

    }
    func sendProductTypesToServer(_ types: [ProductType]) {
        var request = URLRequest(url: URL(string: "https://www.duszekjk.com/paradiso/api/receive_producttypes/")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(syncToken)", forHTTPHeaderField: "Authorization")

        let payload = ProductTypeResponsePayload(type: "productTypes", productTypes: types)

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            logEvent("❌ Failed to encode productTypes")
            return
        }

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {4
                self.logEvent("❌ Upload productTypes error: \(error.localizedDescription)")
            } else {
                self.logEvent("☁️ Uploaded \(types.count) productTypes to server")
            }
        }.resume()
    }

    func sendServerRequest(_ requestData: Data) {
        var req = URLRequest(url: URL(string: "https://www.duszekjk.com/paradiso/api/request_producttypes/")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(syncToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = requestData

        URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data else {
                self.logEvent("❌ Failed to get ProductTypes from server")
                return
            }

            if let response = try? JSONDecoder().decode(ProductTypeResponsePayload.self, from: data),
               response.type == "productTypes" {
                DispatchQueue.main.async {
                    self.logEvent("☁️ Received \(response.productTypes.count) ProductTypes from server")
                    self.sendProductTypesToServer(response.productTypes)
                    for type in response.productTypes {
                        if let i = self.productTypes.firstIndex(where: { $0.productID == type.productID }) {
                            if self.productTypes[i].timestamp < type.timestamp {
                                self.productTypes[i] = type
                            }
                        } else {
                            self.productTypes.append(type)
                        }
                    }
                }
            }
        }.resume()
    }

}

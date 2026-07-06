import Foundation
import MultipeerConnectivity
import SwiftUI
import CryptoKit

extension Data {
    func sha256() -> String {
        let hash = SHA256.hash(data: self)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}


extension String {
    static var serviceName = "ssc123v3"
    static var persistentDeviceID: String {
        let key = "com.storeScaner.deviceID"
        if let saved = UserDefaults.standard.string(forKey: key) {
            return saved
        }
        let uuid = UUID().uuidString.prefix(30)
        UserDefaults.standard.set(String(uuid), forKey: key)
        return String(uuid)
    }
}

class MPConnectionManager: NSObject, ObservableObject {
    let serviceType = String.serviceName
    let myPeerId = MCPeerID(displayName: String.persistentDeviceID)
    let session: MCSession
    let nearbyServiceAdvertiser: MCNearbyServiceAdvertiser
    let nearbyServiceBrowser: MCNearbyServiceBrowser

    @Published var connectedPeer: MCPeerID?
    @Published var availablePeers: [MCPeerID] = []
    @Published var log: [String] = []
    @Published var seenUpdateKeys: Set<String> = LocalStorage.load(Set<String>.self, from: "seenUpdateKeys.json") ?? [] {
        didSet {
            DispatchQueue.global(qos: .background).async {
                LocalStorage.save(self.seenUpdateKeys, to: "seenUpdateKeys.json")
            }
        }
    }
    private var lastSentHashForPeer: [String: Int] = [:]


    
    @Published var productTypes: [ProductType] = LocalStorage.load([ProductType].self, from: "productTypes.json") ?? sampleProducts {
        didSet {
            DispatchQueue.global(qos: .background).async {
                LocalStorage.save(self.productTypes, to: "productTypes.json")
            }
        }
    }

    @Published var productUpdates: [ProductUpdate] = {
        let all = LocalStorage.load([ProductUpdate].self, from: "productUpdates.json") ?? []
        let cutoff = UserDefaults.standard.double(forKey: "resetTimestamp")
        print("resetTimestamp \(cutoff)")
        print("all \(all.count) \(all.first?.timestamp.description ?? "nil")")
        let fil = all.filter { $0.timestamp >= cutoff }
        print("fil \(fil.count)")
        return fil
    }() {
        didSet {
            DispatchQueue.global(qos: .background).async {
                LocalStorage.save(self.productUpdates, to: "productUpdates.json")
            }
        }
    }
    @Published var resetTimestamp: TimeInterval? = UserDefaults.standard.double(forKey: "resetTimestamp") {
        didSet {
            UserDefaults.standard.set(resetTimestamp, forKey: "resetTimestamp")
        }
    }

    @Published var inventory: [InventoryItem] = [] {
        didSet {
            DispatchQueue.global(qos: .background).async {
                LocalStorage.save(self.inventory, to: "inventory.json")
            }
        }
    }
    public var lastFailedInternetSync: Date? {
        get { UserDefaults.standard.object(forKey: "lastFailedInternetSync") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastFailedInternetSync") }
    }
    

    init(yourName: String) {
        self.session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        self.nearbyServiceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        self.nearbyServiceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        super.init()
        print("iit menager")
        session.delegate = self
        nearbyServiceAdvertiser.delegate = self
        nearbyServiceBrowser.delegate = self
        var items : [ProductItem] = []
        for productType in productTypes {
            items.append(contentsOf: productType.generateProductItems())
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
        {
            print("i\(self.inventory)")
            self.recalculateInventory()
            print("i\(self.inventory)")
            DispatchQueue.global(qos: .background).async {
                LocalStorage.save(self.inventory, to: "inventory.json")
            }
        }
    }
    public func computePayloadHash() -> Int {
        var hasher = Hasher()
        hasher.combine(productTypes.count)
        hasher.combine(productUpdates.count)
        for type in productTypes { hasher.combine(type.productID); hasher.combine(type.timestamp) }
        for update in productUpdates { hasher.combine(update.uniqueKey) }
        return hasher.finalize()
    }
    
    var stateChecksums: (productTypes: String, productUpdates: String, inventory: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        func hash<T: Encodable>(_ value: T) -> String {
            guard let data = try? encoder.encode(value) else { return "ENCODING_ERROR" }
            return data.sha256()
        }

        let ptHash = hash(productTypes.sorted(by: { $0.productID < $1.productID }))
        let puHash = hash(productUpdates.sorted(by: { $0.timestamp < $1.timestamp }))
        let invHash = hash(inventory.sorted(by: { $0.productItemID < $1.productItemID }))

        return (ptHash, puHash, invHash)
    }

    func productTypeHashes() -> [String: String] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return Dictionary(uniqueKeysWithValues:
            productTypes.sorted(by: { $0.productID < $1.productID }).compactMap {
                guard let data = try? encoder.encode($0) else { return nil }
                return ($0.productID, data.sha256())
            }
        )
    }

    func inventoryHashes() -> [String: String] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return Dictionary(uniqueKeysWithValues:
            inventory.sorted(by: { $0.productItemID < $1.productItemID }).compactMap {
                guard let data = try? encoder.encode($0) else { return nil }
                return ($0.productItemID, data.sha256())
            }
        )
    }


    func sendDetailedValidation() {
        let payload: [String: [String: String]] = [
            "validate_PT": productTypeHashes(),
            "validate_INV": inventoryHashes()
        ]

        if let data = try? JSONEncoder().encode(payload) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
            log.append("🔍 Sent detailed validation")
        }
    }


    func compareHashes(received: [String: String], local: [String: String], label: String) -> String {
        var result = "🔍 \(label):\n"
        let allKeys = Set(received.keys).union(local.keys)
        for key in allKeys.sorted() {
            let r = received[key] ?? "-"
            let l = local[key] ?? "-"
            if r != l {
                result += "❌ \(key): \(r.prefix(8)) ≠ \(l.prefix(8))\n"
            }
        }
        return result.isEmpty ? "\(label): ✅ All match" : result
    }


    
    func logEvent(_ message: String) {
        DispatchQueue.main.async {
            let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.log.append("[\(time)] \(message)")
        }
    }

    func startBrowsing() {
        logEvent("🔍 Starting to browse")
        nearbyServiceBrowser.startBrowsingForPeers()
    }

    func stopBrowsing() {
        logEvent("🛑 Stopped browsing")
        nearbyServiceBrowser.stopBrowsingForPeers()
        availablePeers.removeAll()
    }

    func startAdvertising() {
        logEvent("📡 Starting to advertise")
        nearbyServiceAdvertiser.startAdvertisingPeer()
        syncWithServerIfGoodConnection()
    }

    func stopAdvertising() {
        logEvent("🚫 Stopped advertising")
        nearbyServiceAdvertiser.stopAdvertisingPeer()
    }

    func sendCurrentState() {
//        DispatchQueue.global(qos: .background).async {
//            self.syncWithServerIfGoodConnection()
//        }
        guard !session.connectedPeers.isEmpty else {
            logEvent("No connected peers")
            return
        }

        let hash = computePayloadHash()
        let ptHashes = productTypeHashes()
        if let resetTimestamp
        {
            sendResetBroadcast(timestamp: resetTimestamp)
        }
        let metaPayload = SyncMetaPayload(
            deviceID: myPeerId.displayName,
            payloadHash: hash,
            productTypeHashes: ptHashes,
            productUpdates: productUpdates
        )

        do {
            let data = try JSONEncoder().encode(metaPayload)
            for peer in session.connectedPeers {
                try session.send(data, toPeers: [peer], with: .reliable)
                lastSentHashForPeer[peer.displayName] = hash
            }
            logEvent("Sent state meta (hashes & updates)")
        } catch {
            logEvent("Send failed: \(error.localizedDescription)")
        }
    }

    
    func sendValidationRequest() {
        let (pt, pu, inv) = stateChecksums
        let payload = [
            "validate_productTypes": pt,
            "validate_productUpdates": pu,
            "validate_inventory": inv
        ]

        if let data = try? JSONEncoder().encode(payload) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
            log.append("🔍 Sent validation: PT=\(pt.prefix(8)) PU=\(pu.prefix(8)) INV=\(inv.prefix(8))")
        }
    }



}


extension MPConnectionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .notConnected:
            DispatchQueue.main.async {
                self.logEvent("❌ Disconnected from \(peerID.displayName)")
                self.connectedPeer = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
                self.startBrowsing()
            }
        case .connecting:
            logEvent("🔌 Connecting to \(peerID.displayName)")
        case .connected:
            logEvent("✅ Connected to \(peerID.displayName)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.connectedPeer = peerID
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.5...1.5)) {
                self.sendCurrentState()
            }
        @unknown default:
            logEvent("❓ Unknown connection state")
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            if let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
                let pt = decoded["validate_PT"] ?? [:]
                let inv = decoded["validate_INV"] ?? [:]

                let ptResult = compareHashes(received: pt, local: productTypeHashes(), label: "ProductTypes")
                let invResult = compareHashes(received: inv, local: inventoryHashes(), label: "Inventory")

                log.append(ptResult)
                log.append(invResult)
                return
            }
            if let reset = try? JSONDecoder().decode(ResetInfo.self, from: data),
               reset.type == "reset" {
                if(self.resetTimestamp ?? 0 < reset.resetTimestamp)
                {
                    DispatchQueue.main.async {
                        self.resetTimestamp = reset.resetTimestamp
                        
                        let filtered = self.productUpdates.filter { $0.timestamp >= reset.resetTimestamp }
                        self.productUpdates = filtered
                        self.seenUpdateKeys = Set(filtered.map(\.uniqueKey))
                        
                        self.recalculateInventory()
                        self.logEvent("🔄 Applied remote reset from \(reset.origin), timestamp \(reset.resetTimestamp)")
                        
                        LocalStorage.save(self.productUpdates, to: "productUpdates.json")
                        LocalStorage.save(self.inventory, to: "inventory.json")
                        LocalStorage.save(Array(self.seenUpdateKeys), to: "seenUpdateKeys.json")
                    }
                }
            }


            if let dict = try? JSONDecoder().decode([String: String].self, from: data),
               let pt = dict["validate_productTypes"],
               let pu = dict["validate_productUpdates"],
               let inv = dict["validate_inventory"] {

                let local = stateChecksums
                var result = "🔍 Validation result:\n"

                result += "🧱 ProductTypes: " + (pt == local.productTypes ? "✅" : "❌") + " \(pt.prefix(8)) vs \(local.productTypes.prefix(8))\n"
                result += "📦 Updates: " + (pu == local.productUpdates ? "✅" : "❌") + " \(pu.prefix(8)) vs \(local.productUpdates.prefix(8))\n"
                result += "📊 Inventory: " + (inv == local.inventory ? "✅" : "❌") + " \(inv.prefix(8)) vs \(local.inventory.prefix(8))"

                if(inv != local.inventory || pu != local.productUpdates || pu != local.productUpdates)
                {
                    sendDetailedValidation()
                }
                log.append(result)
                return
            }



            DispatchQueue.main.async {
                // Attempt meta payload
                if let meta = try? JSONDecoder().decode(SyncMetaPayload.self, from: data) {
                    self.logEvent("Received meta state from \(peerID.displayName)")

                    // --- Apply productUpdates ---
                    for update in meta.productUpdates {
                        let key = update.uniqueKey
                        guard !self.seenUpdateKeys.contains(key) else { continue }

                        self.seenUpdateKeys.insert(key)
                        self.productUpdates.append(update)

                        if let invIndex = self.inventory.firstIndex(where: { $0.productItemID == update.productItemID }) {
                            self.inventory[invIndex].count += update.delta
                            self.inventory[invIndex].lastUpdateTimestamp = max(self.inventory[invIndex].lastUpdateTimestamp, update.timestamp)
                        } else {
                            self.inventory.append(InventoryItem(
                                productItemID: update.productItemID,
                                count: update.delta,
                                lastUpdateTimestamp: update.timestamp
                            ))
                        }
                    }

                    // --- Compare ProductType hashes ---
                    let localHashes = self.productTypeHashes()
                    let missing = meta.productTypeHashes.filter { pid, remoteHash in
                        localHashes[pid] != remoteHash
                    }.map(\.key)

                    if !missing.isEmpty {
                        let request = ProductTypeRequestPayload(type: "requestProductTypes", productIDs: missing)
                        if let data = try? JSONEncoder().encode(request) {
                            try? session.send(data, toPeers: [peerID], with: .reliable)
                            self.logEvent("Requested \(missing.count) productTypes")
                        }
                    } else {
                        self.logEvent("ProductTypes already up to date")
                    }
                    return
                }

                // Handle response with full ProductTypes
                if let response = try? JSONDecoder().decode(ProductTypeResponsePayload.self, from: data),
                   response.type == "productTypes" {
                    self.logEvent("Received \(response.productTypes.count) full productTypes")

                    for type in response.productTypes {
                        if let index = self.productTypes.firstIndex(where: { $0.productID == type.productID }) {
                            if !type.name.isEmpty && self.productTypes[index].timestamp < type.timestamp {
                                self.productTypes[index] = type
                            }
                        } else {
                            self.productTypes.append(type)
                        }
                    }
                    return
                }

                // Handle request for specific ProductTypes
                if let request = try? JSONDecoder().decode(ProductTypeRequestPayload.self, from: data),
                   request.type == "requestProductTypes" {

                    let toSend = self.productTypes.filter { request.productIDs.contains($0.productID) }
                    let response = ProductTypeResponsePayload(type: "productTypes", productTypes: toSend)

                    if let respData = try? JSONEncoder().encode(response) {
                        try? session.send(respData, toPeers: [peerID], with: .reliable)
                        self.logEvent("Sent \(toSend.count) productTypes on request")
                    }
                    return
                }
            }
        } catch {
            logEvent("❌ Failed to decode: \(error.localizedDescription)")
        }
    }

    // Unused
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
extension MPConnectionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        logEvent("🧭 Found peer: \(peerID.displayName)")
        if !availablePeers.contains(peerID) {
            availablePeers.append(peerID)
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logEvent("❗ Lost peer: \(peerID.displayName)")
        availablePeers.removeAll { $0 == peerID }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logEvent("❌ Could not browse: \(error.localizedDescription)")
    }
}

extension MPConnectionManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        logEvent("📬 Received invite from \(peerID.displayName)")
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logEvent("❌ Could not advertise: \(error.localizedDescription)")
    }
}

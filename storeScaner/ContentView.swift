import SwiftUI


struct ContentView: View {
    @State private var knownPeers: Set<String> = []
    @StateObject var connectionManager = MPConnectionManager(yourName: String.persistentDeviceID)
    @State private var showLog = false
    @State private var showProductEditor = false
    
    
    @State private var selectedType: ProductType?
    @State private var selectedGender: String?
    @State private var selectedSize: String?
    @State private var selectedColor: String?
    @State private var selectedCurrency: String?
    @State private var selectedPrice: Double?
    @State private var count: Int?
    @State private var customCount: String = ""

    var body: some View {
        TabView {
            // Selling
            ProductSelectionView(
                productTypes: connectionManager.productTypes,
                showCurrencyPicker: true,
                onSubmit: { apply(update: $0.withNegativeDelta()) },
                originPeerID: connectionManager.myPeerId.displayName,
                selectedType: $selectedType,
                selectedGender: $selectedGender,
                selectedSize: $selectedSize,
                selectedColor: $selectedColor,
                selectedCurrency: $selectedCurrency,
                selectedPrice: $selectedPrice,
                count: $count,
                customCount: $customCount
            )
            .tabItem {
                Label("Selling", systemImage: "cart")
            }
            .safeAreaInset(edge: .bottom) {
                if #available(iOS 26.0, *) {
                    Text(connectionManager.log.last ?? "No activity yet")
                        .font(.footnote)
                        .glassEffect()
                        .onTapGesture { showLog = true }
                } else {
                    Text(connectionManager.log.last ?? "No activity yet")
                        .font(.footnote)
                        .padding(6)
                        .background(Color(.systemGray6))
                        .onTapGesture { showLog = true }
                }
            }
            
            // Restocking
            ProductSelectionView(
                productTypes: connectionManager.productTypes,
                showCurrencyPicker: false,
                onSubmit: { apply(update: $0) },
                originPeerID: connectionManager.myPeerId.displayName,
                selectedType: $selectedType,
                selectedGender: $selectedGender,
                selectedSize: $selectedSize,
                selectedColor: $selectedColor,
                selectedCurrency: $selectedCurrency,
                selectedPrice: $selectedPrice,
                count: $count,
                customCount: $customCount
            )
            .tabItem {
                Label("Restocking", systemImage: "shippingbox.fill")
            }
            
            // Inventory
            //            List {
            //                ForEach(connectionManager.inventory, id: \.productItemID) { item in
            //                    VStack(alignment: .leading) {
            //                        Text("🆔 \(item.productItemID)")
            //                            .font(.headline)
            //                        Text("📦 Count: \(item.count)")
            //                    }
            //                }
            //            }
            InventoryView(productTypes: connectionManager.productTypes, inventory: connectionManager.inventory, updates: connectionManager.productUpdates)
                .tabItem {
                    Label("Inventory", systemImage: "archivebox")
                }
            
            ProductListView(productTypes: $connectionManager.productTypes, inventory: $connectionManager.inventory, send:
                                {connectionManager.sendCurrentState()})
            .tabItem {
                Label("Edit", systemImage: "square.and.pencil")
            }
            .sheet(isPresented: $showProductEditor) {
            }
        }
        .background(Color.clear)
        .onAppear {
            connectionManager.startBrowsing()
            connectionManager.startAdvertising()
        }
        .onReceive(connectionManager.$connectedPeer) { peer in
            guard let peerID = peer?.displayName, !knownPeers.contains(peerID) else { return }
            knownPeers.insert(peerID)
            //            connectionManager.logEvent("🔁 First time seeing \(peerID), sending state")
            //            connectionManager.sendCurrentState()
        }
        .sheet(isPresented: $showLog) {
            ScrollView {
                VStack()
                {
                    Button("Validate Sync") {
                        connectionManager.sendValidationRequest()
                    }
                    Text(connectionManager.log.joined(separator: "\n"))
                        .padding()
                        .textSelection(.enabled)
                        .font(.system(size: 13, design: .monospaced))
                }
            }
        }
    }

    func apply(update: ProductUpdate) {
        let key = update.uniqueKey
        guard !connectionManager.seenUpdateKeys.contains(key) else { return }

        connectionManager.seenUpdateKeys.insert(key)
        connectionManager.productUpdates.append(update)

        if let i = connectionManager.inventory.firstIndex(where: { $0.productItemID == update.productItemID }) {
            connectionManager.inventory[i].count += update.delta
            connectionManager.inventory[i].lastUpdateTimestamp = update.timestamp
        } else {
            connectionManager.inventory.append(
                InventoryItem(
                    productItemID: update.productItemID,
                    count: update.delta,
                    lastUpdateTimestamp: update.timestamp
                )
            )
        }

        connectionManager.sendCurrentState()
    }

}


extension ProductUpdate {
    func withNegativeDelta() -> ProductUpdate {
        ProductUpdate(
            productItemID: productItemID,
            delta: -abs(delta),
            price: price,
            currency: currency,
            timestamp: timestamp,
            originPeerID: originPeerID
        )
    }
}

extension ProductUpdate {
    func toDummyItem() -> ProductItem {
        ProductItem(
            productID: productItemID.components(separatedBy: "-").first ?? productItemID,
            productType: "unknown",
            gender: nil, size: nil, color: nil
        )
    }
}

func itemID(for item: ProductItem) -> String {
    [item.productID, item.gender ?? "any", item.size ?? "any", item.color ?? "any"].joined(separator: "-")
}

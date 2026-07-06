//
//  ProductListView.swift
//  storeScaner
//
//  Created by Jacek Kałużny on 19/06/2025.
//

import SwiftUI

struct ProductListView: View {
    @Binding var productTypes: [ProductType]
    @Binding var inventory: [InventoryItem]
    public var send: () -> (Void)

    @State private var selectedProduct: ProductType? = nil
    @State private var confirmDeleteProductID: String? = nil
    let new = ProductType(
        productID: UUID().uuidString,
        name: "",
        category: "",
        genders: nil,
        sizes: nil,
        colors: nil,
        photoData: nil,
        colorsPhotosData: [:],
        priceByCurrency: [:],
        originPeerID: String.persistentDeviceID,
        timestamp: Date().timeIntervalSince1970
    )
    var body: some View {
        NavigationView {
            List {
                ForEach(productTypes, id: \.productID) { product in
                    NavigationLink(
                        destination: ProductEditorView(
                            product: product,
                            onSave: { updated in
                                if let index = productTypes.firstIndex(where: { $0.productID == updated.productID }) {
                                    productTypes[index] = updated
                                }
                                send()
                            }
                        ),
                        tag: product,
                        selection: $selectedProduct
                    ) {
                        VStack(alignment: .leading) {
                            Text(product.name).bold()
                            Text(product.category).font(.caption)
                        }
                    }
                }
                .onDelete(perform: handleDelete)
            }
            .navigationTitle("Produkty")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        let new = ProductType(
                            productID: UUID().uuidString,
                            name: "",
                            category: "",
                            genders: nil,
                            sizes: nil,
                            colors: nil,
                            photoData: nil,
                            colorsPhotosData: [:],
                            priceByCurrency: [:],
                            originPeerID: String.persistentDeviceID,
                            timestamp: Date().timeIntervalSince1970
                        )
                        productTypes.append(new)
                        selectedProduct = new
                    }) {
                        Label("Dodaj", systemImage: "plus")
                    }
                }
                
            }

            // Right-hand detail view
            if let selected = selectedProduct {
                ProductEditorView(
                    product: selected,
                    onSave: { updated in
                        if let index = productTypes.firstIndex(where: { $0.productID == updated.productID }) {
                            productTypes[index] = updated
                        }
                        send()
                    }
                )
            } else {
                ProductEditorView(
                    product: new,
                    onSave: { updated in
                        productTypes.append(updated)
                        selectedProduct = updated
                        send()
                    }
                )
            }
        }
        .alert("Na pewno usunąć produkt?", isPresented: Binding(
            get: { confirmDeleteProductID != nil },
            set: { if !$0 { confirmDeleteProductID = nil } }
        )) {
            Button("Usuń", role: .destructive) {
                if let id = confirmDeleteProductID,
                   let index = productTypes.firstIndex(where: { $0.productID == id }) {
                    productTypes.remove(at: index)
                    if selectedProduct?.productID == id {
                        selectedProduct = nil
                    }
                }
                confirmDeleteProductID = nil
            }

            Button("Anuluj", role: .cancel) {
                confirmDeleteProductID = nil
            }
        } message: {
            if let id = confirmDeleteProductID,
               let product = productTypes.first(where: { $0.productID == id }) {
                let count = countOfInventoryItems(for: product)
                Text("Czy na pewno chcesz usunąć produkt „\(product.name)”?\nObecnie znajduje się w \(count) pozycjach magazynowych.")
            } else {
                Text("Czy na pewno chcesz usunąć ten produkt?")
            }
        }
        .navigationViewStyle(.automatic)
    }

    private func handleDelete(at offsets: IndexSet) {
        if let index = offsets.first {
            confirmDeleteProductID = productTypes[index].productID
        }
    }

    private func countOfInventoryItems(for product: ProductType) -> Int {
        inventory.filter { $0.productItemID.hasPrefix(product.productID) }.count
    }
}

//
//  Product.swift
//  storeScaner
//
//  Created by Jacek Kałużny on 09/04/2025.
//

import Foundation
import SwiftUI

struct ProductType: Codable, Hashable {
    let productID: String
    var name: String
    var category: String // e.g., \"clothing\", \"accessory\", \"food\"
    var genders: [String]? // \"men\", \"women\", \"universal\"
    var sizes: [String]? // e.g., [\"S\", \"M\", \"L\"]
    var colors: [String]? // e.g., [\"red\", \"blue\"]
    var photoData: Data?
    var colorsPhotosData: [String:Data]
    var priceByCurrency: [String: Double] // e.g., [\"PLN\": 49.99, \"EUR\": 10.99]
    var originPeerID: String
    var timestamp: TimeInterval
}

extension ProductType {
    func generateProductItems() -> [ProductItem] {
        let genderList = genders ?? nil
        let sizeList = sizes ?? nil
        let colorList = colors ?? nil

        var items: [ProductItem] = []

        for gender in genderList ?? [""] {
            for size in sizeList ?? [""] {
                for color in colorList ?? [""] {
                    items.append(toItem(from: self, gender: gender, size: size, color: color))
                }
            }
        }
        return items
    }
}
struct ProductItem: Codable, Hashable {
    let productID: String
    let productType: String
    var gender: String?
    var size: String?
    var color: String?
}
func toItem(from product: ProductType, gender: String?, size: String?, color: String?) -> ProductItem
{
    var productID = product.productID + "_" + (gender ?? "") + (size  ?? "") + (color ?? "")
    var productType = product.productID
    return ProductItem(productID: productID, productType: productType, gender: gender, size: size, color: color)
}
struct ProductUpdate: Codable, Hashable {
    let productItemID: String
    var delta: Int
    var price: Double
    var currency: String
    var timestamp: TimeInterval
    let originPeerID: String
    var uniqueKey: String {
        "\(productItemID)-\(timestamp)-\(originPeerID)"
    }
}

struct InventoryItem: Codable, Hashable {
    var productItemID: String
    var count: Int
    var lastUpdateTimestamp: TimeInterval
}




struct SyncMetaPayload: Codable {
    let deviceID: String
    let payloadHash: Int
    let productTypeHashes: [String: String] // productID → hash
    let productUpdates: [ProductUpdate]
}

struct ProductTypeRequestPayload: Codable {
    let type: String // = "requestProductTypes"
    let productIDs: [String]
}

struct ProductTypeResponsePayload: Codable {
    let type: String // = "productTypes"
    let productTypes: [ProductType]
}



let sampleProducts: [ProductType] = []
//    ProductType(
//        productID: "tshirt001",
//        name: "T-Shirt Example",
//        category: "clothing",
//        genders: ["men", "women"],
//        sizes: ["S", "M", "L", "XL"],
//        colors: ["white", "black"],
//        photoData: nil,
//        colorsPhotosData: [:],
//        priceByCurrency: ["PLN": 49.99, "EUR": 10.99],
//        originPeerID: "demo",
//        timestamp: Date().timeIntervalSince1970
//    ),
//]

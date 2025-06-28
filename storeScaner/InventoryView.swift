import SwiftUI
import Charts

struct InventoryView: View {
    let productTypes: [ProductType]
    let inventory: [InventoryItem]
    let updates: [ProductUpdate]

    @State private var selectedProduct: ProductType?

    func trimmedLabel(for id: String) -> String {
        let parts = id.split(separator: "_")
        return parts.count > 1 ? String(parts.suffix(1).joined(separator: "+")) : id
    }

    var body: some View {
        NavigationView {
            List(productTypes, id: \.productID, selection: $selectedProduct) { product in
                NavigationLink(destination: InventoryDetailView(
                    product: product,
                    inventory: inventory,
                    updates: updates
                ), tag: product, selection: $selectedProduct) {
                    VStack(alignment: .leading) {
                        Text(product.name).bold()
                        Text(product.category).font(.caption)
                    }
                }
            }
            .navigationTitle("Stan magazynowy")

            Text("Wybierz produkt po lewej stronie")
        }
        .navigationViewStyle(.automatic)
    }
}

struct InventoryDetailView: View {
    @State private var selectedGender: String? = nil
    @State private var selectedSize: String? = nil
    @State private var selectedColor: String? = nil
    func trimmedLabel(for id: String) -> String {
        let parts = id.split(separator: "_")
        return parts.count > 1 ? String(parts.suffix(1).joined(separator: "+")) : id
    }
    let product: ProductType
    let inventory: [InventoryItem]
    let updates: [ProductUpdate]
    
    struct CurrencyRevenue: Identifiable {
        let id = UUID()
        let currency: String
        let revenue: Double
    }
    
    struct TimeSeriesEntry: Identifiable {
        let id = UUID()
        let date: Date
        let value: Int
    }
    
    var filteredMatchingItems: [InventoryItem] {
        matchingItems.filter { item in
            guard let type = product.generateProductItems().first(where: { $0.productID == item.productItemID }) else { return false }
            let genderMatch = selectedGender == nil || type.gender == selectedGender
            let sizeMatch = selectedSize == nil || type.size == selectedSize
            let colorMatch = selectedColor == nil || type.color == selectedColor
            return genderMatch && sizeMatch && colorMatch
        }
    }
    
    var matchingItems: [InventoryItem] {
        inventory.filter { $0.productItemID.hasPrefix(product.productID) }
    }
    
    var soldUpdates: [ProductUpdate] {
        updates.filter { $0.productItemID.hasPrefix(product.productID) && $0.delta < 0 }
    }
    
    var groupedSales: [String: (count: Int, total: Double)] {
        Dictionary(grouping: soldUpdates, by: { $0.currency })
            .mapValues { updates in
                let count = updates.map { abs($0.delta) }.reduce(0, +)
                let total = updates.map { abs(Double($0.delta) * $0.price) }.reduce(0, +)
                return (count, total)
            }
    }
    
    var chartData: [CurrencyRevenue] {
        groupedSales.map { CurrencyRevenue(currency: $0.key, revenue: $0.value.total) }
    }
    
    var inventoryChartData: [CurrencyRevenue] {
        let grouped = Dictionary(grouping: filteredMatchingItems, by: { $0.productItemID })
            .mapValues { $0.map { $0.count }.reduce(0, +) }
        return grouped.map { CurrencyRevenue(currency: $0.key, revenue: Double($0.value)) }
    }
    
    var soldChartData: [CurrencyRevenue] {
        let grouped = Dictionary(grouping: soldUpdates.filter { update in
            selectedGender == nil || update.productItemID.contains(selectedGender!)
        }.filter { update in
            selectedSize == nil || update.productItemID.contains(selectedSize!)
        }.filter { update in
            selectedColor == nil || update.productItemID.contains(selectedColor!)
        }, by: { $0.productItemID })
            .mapValues { $0.map { abs($0.delta) }.reduce(0, +) }
        return grouped.map { CurrencyRevenue(currency: $0.key, revenue: Double($0.value)) }
    }
    
    var timeSeriesData: [TimeSeriesEntry] {
        let grouped = Dictionary(grouping: soldUpdates, by: { Calendar.current.startOfDay(for: Date(timeIntervalSince1970: $0.timestamp)) })
            .mapValues { $0.map { abs($0.delta) }.reduce(0, +) }
        return grouped.map { TimeSeriesEntry(date: $0.key, value: $0.value) }.sorted(by: { $0.date < $1.date })
    }
    
    var body: some View {
        ScrollView {
            let genders = product.genders ?? []
            let sizes = product.sizes ?? []
            let colors = product.colors ?? []
            VStack(alignment: .leading, spacing: 10) {
                VStack {
                    if !genders.isEmpty {
                        Picker("Płeć", selection: $selectedGender) {
                            Text("Wszystkie").tag(nil as String?)
                            ForEach(genders, id: \.self) { gender in
                                Text(gender).tag(Optional(gender))
                            }
                        }.pickerStyle(.segmented)
                    }
                    if !sizes.isEmpty {
                        Picker("Rozmiar", selection: $selectedSize) {
                            Text("Wszystkie").tag(nil as String?)
                            ForEach(sizes, id: \.self) { size in
                                Text(size).tag(Optional(size))
                            }
                        }.pickerStyle(.segmented)
                    }
                    if !colors.isEmpty {
                        Picker("Kolor", selection: $selectedColor) {
                            Text("Wszystkie").tag(nil as String?)
                            ForEach(colors, id: \.self) { color in
                                Text(color).tag(Optional(color))
                            }
                        }.pickerStyle(.segmented)
                    }
                }
                .padding(.bottom)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text(product.name)
                        .font(.largeTitle).bold()
                    
                    Text("📦 Aktualny stan magazynowy:")
                        .font(.title3).bold()
                    
                    ForEach(matchingItems, id: \.productItemID) { item in
                        Text("\(item.productItemID.split(separator: "_").dropFirst().first.map(String.init) ?? product.name): \(item.count) szt.")

                    }
                    
                    Divider()
                    
                    Text("📈 Statystyki sprzedaży:")
                        .font(.title3).bold()
                    
                    ForEach(Array(groupedSales.keys.sorted()), id: \.self) { currency in
                        let data = groupedSales[currency]!
                        VStack(alignment: .leading) {
                            Text("💵 Waluta: \(currency)")
                            Text("🧾 Sprzedano: \(data.count) szt.")
                            Text("💰 Przychód: \(String(format: "%.2f", data.total)) \(currency)")
                        }
                        .padding(.bottom, 8)
                    }
                    
                    Text("📊 Przychód według waluty")
                        .font(.title3).bold()
                    
                    Chart(chartData) { item in
                        BarMark(x: .value("Waluta", item.currency), y: .value("Przychód", item.revenue))
                            .foregroundStyle(by: .value("Waluta", item.currency))
                    }
                    .frame(height: 200)
                    
                    Text("📆 Sprzedaż w czasie")
                        .font(.title3).bold()
                    
                    Chart(timeSeriesData) { entry in
                        LineMark(x: .value("Data", entry.date), y: .value("Sztuki", entry.value))
                    }
                    .frame(height: 200)
                    
                    Text("📦 Obecny stan")
                        .font(.title3).bold()
                    
                    Chart(inventoryChartData) { entry in
                        BarMark(x: .value("Wariant", trimmedLabel(for: entry.currency)), y: .value("Sztuki", entry.revenue))
                            .foregroundStyle(by: .value("Wariant", trimmedLabel(for: entry.currency)))
                    }
                    .frame(height: 200)
                    
                    Chart(inventoryChartData) { entry in
                        SectorMark(angle: .value("Udział", entry.revenue), innerRadius: .ratio(0.5))
                            .foregroundStyle(by: .value("Wariant", trimmedLabel(for: entry.currency)))
                    }
                    .frame(height: 200)
                    
                    Text("📤 Sprzedaż")
                        .font(.title3).bold()
                    
                    Chart(soldChartData) { entry in
                        BarMark(x: .value("Wariant", trimmedLabel(for: entry.currency)), y: .value("Sztuki", entry.revenue))
                            .foregroundStyle(by: .value("Wariant", trimmedLabel(for: entry.currency)))
                    }
                    .frame(height: 200)
                    
                    Chart(soldChartData) { entry in
                        SectorMark(angle: .value("Udział", entry.revenue), innerRadius: .ratio(0.5))
                            .foregroundStyle(by: .value("Wariant", trimmedLabel(for: entry.currency)))
                    }
                    .frame(height: 200)
                    
                    Divider()
                    
                    Text("🪟 Szczegóły sprzedaży (ostatnie 20):")
                        .font(.title3).bold()
                    
                    ForEach(soldUpdates.sorted(by: { $0.timestamp > $1.timestamp }).prefix(20), id: \.uniqueKey) { update in
                        VStack(alignment: .leading) {
                            Text("🆔 \(update.productItemID.replacingOccurrences(of: "_", with: "\n"))")
                                .lineLimit(5)
                            Text("🕒 \(Date(timeIntervalSince1970: update.timestamp).formatted(date: .numeric, time: .shortened))")
                            Text("➖ \(abs(update.delta)) szt., \(String(format: "%.2f", update.price)) \(update.currency)")
                        }
                        .padding(.bottom, 6)
                    }
                }
                .padding()
            }
        }
    }
}

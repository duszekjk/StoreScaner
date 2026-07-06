import SwiftUI
import Charts

struct InventoryView: View {
    let productTypes: [ProductType]
    let inventory: [InventoryItem]
    let updates: [ProductUpdate]

    @State private var selectedProduct: ProductType?
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    
    @State private var showImporter = false
    @EnvironmentObject var mpManager : MPConnectionManager
    
    
    
    @State private var selectedImportData: Data?
    @State private var showBackupSheet = false
    @State private var backupURL: URL?
    @State private var showFinalResetAlert = false
    @State private var pendingImportedUpdates: [ProductUpdate]?
    @State private var delimiterSelection: CSVDelimiter? = nil
    @State private var showDelimiterDialog = false


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
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    Button {

                        if let url = FileExporter.exportProductUpdatesAsCSV(mpManager.productUpdates)
                        {
                            exportURL = url
                            DispatchQueue.main.async()
                            {
                                if(exportURL != nil)
                                {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
                                    {
                                        showShareSheet = true
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Eksport CSV", systemImage: "square.and.arrow.up")
                    }
//
//                    Button {
//                        if let url = FileExporter.exportProductUpdates(mpManager.productUpdates) {
//                            exportURL = url
//                            showShareSheet = true
//                        }
//                    } label: {
//                        Label("Eksport CSV", systemImage: "square.and.arrow.up.on.square")
//                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let url = try result.get().first else { return }
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }

                        let data = try Data(contentsOf: url)
                        if let text = String(data: data, encoding: .utf8) {
                            print("📄 CSV contents:\n\(text)")
                        } else {
                            print("❌ Failed to decode CSV data as UTF-8")
                        }

                        selectedImportData = data
                    } else {
                        print("⚠️ Could not access security-scoped resource")
                    }

                    showDelimiterDialog = true

                } catch {
                    print("Import failed: \(error)")
                }
            }
            .confirmationDialog("Select CSV Delimiter", isPresented: $showDelimiterDialog, titleVisibility: .visible) {
                ForEach(CSVDelimiter.allCases, id: \.self) { delimiter in
                    Button(delimiter.description) {
                        delimiterSelection = delimiter
                    }
                }
                Button("Cancel", role: .cancel) {}
            }




            Text("Wybierz produkt po lewej stronie")
        }
        .navigationViewStyle(.automatic)
        .sheet(isPresented: $showShareSheet) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
        .sheet(isPresented: $showBackupSheet, onDismiss: {
            showFinalResetAlert = true
        }) {
            if let backupURL {
                ShareSheet(activityItems: [backupURL])
            }
        }
        .alert("🧨 Confirm Reset?", isPresented: $showFinalResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                guard let updatesLoad = pendingImportedUpdates else { return }


                mpManager.resetAllData(withUpdates: updatesLoad)

                var newTime = mpManager.resetTimestamp?.advanced(by: 1.0) ?? Date().timeIntervalSince1970.advanced(by: 1.0)

                let updates = updatesLoad.map { updateNew -> ProductUpdate in
                    var update = updateNew
                    newTime += 0.001
                    update.timestamp = newTime
                    return update
                }
                mpManager.productUpdates = updates
                mpManager.seenUpdateKeys = Set(updates.map(\.uniqueKey))
                mpManager.inventory = []

                LocalStorage.save(mpManager.productUpdates, to: "productUpdates.json")
                LocalStorage.save(mpManager.inventory, to: "inventory.json")
                LocalStorage.save(Array(mpManager.seenUpdateKeys), to: "seenUpdateKeys.json")
//                for update in updates {
////                    if let index = mpManager.inventory.firstIndex(where: { $0.productItemID == update.productItemID }) {
////                        mpManager.inventory[index].count += update.delta
////                        mpManager.inventory[index].lastUpdateTimestamp = update.timestamp
////                    } else {
//                        mpManager.inventory.append(InventoryItem(
//                            productItemID: update.productItemID,
//                            count: update.delta,
//                            lastUpdateTimestamp: update.timestamp
//                        ))
////                    }
//                }
                mpManager.recalculateInventory()

                LocalStorage.save(mpManager.productUpdates, to: "productUpdates.json")
                LocalStorage.save(mpManager.inventory, to: "inventory.json")
                LocalStorage.save(Array(mpManager.seenUpdateKeys), to: "seenUpdateKeys.json")
                
                mpManager.sendCurrentState()
                mpManager.logEvent("📥 Imported \(updates.count) updates from CSV and synced")
            }

        } message: {
            Text("Backup was created. This will remove all old updates and inventory. Continue?")
        }
        .onChange(of: delimiterSelection) { delimiter in
            print("Selected delimiter: \(delimiter?.description ?? "nil")")
            guard let delimiter, let data = selectedImportData else {
                print("Missing data or delimiter")
                return
            }
            do {
                let updates = try InventoryImporter.importProductUpdatesCSV(data: data, delimiter: delimiter.rawValue)
                pendingImportedUpdates = updates
                print("✅ Parsed \(updates.count) updates")

                if updates.isEmpty {
                    print("No updates to import")
                    return
                }

                // Export current backup
                if let url = FileExporter.exportProductUpdatesBackup(mpManager.productUpdates) {
                    backupURL = url
                    DispatchQueue.main.async()
                    {
                        if(backupURL != nil)
                        {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
                            {
                                showBackupSheet = true
                            }
                        }
                        else
                        {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
                            {
                                showFinalResetAlert = true
                            }
                        }
                    }
                }
            } catch {
                mpManager.logEvent("❌ Failed to import updates: \(error.localizedDescription)")
            }

        }



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
        print(inventory)
        return inventory.filter { $0.productItemID.hasPrefix(product.productID) }
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
//                HStack {
//                    Button("📤 Eksportuj jako JSON") {
//                        if let url = FileExporter.exportInventory(filteredMatchingItems, as: .json) {
//                            print("Exported file at: \(url.path)")
//                            exportURL = url
//                            showShareSheet = true
//                        }
//                    }
//                    Button("📤 Eksportuj jako CSV") {
//                        if let url = FileExporter.exportInventory(filteredMatchingItems, as: .csv) {
//                            print("Exported file at: \(url.path)")
//                            exportURL = url
//                            showShareSheet = true
//                        }
//                    }
//                }
//                .padding(.bottom)

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
                            Text(product.name)
                                .bold()
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
//        .sheet(isPresented: $showShareSheet) {
//            if let exportURL {
//                ShareSheet(activityItems: [exportURL])
//            } else {
//                Text("Nie znaleziono pliku do udostępnienia.")
//            }
//        }
    }
}
import UIKit
import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

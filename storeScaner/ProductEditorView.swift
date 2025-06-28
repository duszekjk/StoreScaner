//
//  ProductEditorView.swift
//  storeScaner
//
//  Created by Jacek Kałużny on 19/06/2025.
//
import SwiftUI
import PhotosUI
struct EditablePrice: Identifiable {
    var id = UUID()
    var currency: String
    var value: String
}


struct ProductEditorView: View {
    @State var product: ProductType
    var onSave: ((ProductType) -> Void)? = nil

    @Environment(\.dismiss) var dismiss

    @State private var selectedItem: PhotosPickerItem? = nil
    
    @State private var editablePrices: [EditablePrice] = []




    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Podstawowe")) {
                    TextField("Nazwa", text: Binding(get: { product.name }, set: { product.name = $0 }))
                    TextField("Kategoria", text: Binding(get: { product.category }, set: { product.category = $0 }))
                }
                
                Section(header: Text("Opcje")) {
                    TextField("Płeć (oddzielone przecinkami)", text: Binding(
                        get: { (product.genders ?? []).joined(separator: ", ") },
                        set: { product.genders = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                    ))
                    TextField("Rozmiary", text: Binding(
                        get: { (product.sizes ?? []).joined(separator: ", ") },
                        set: { product.sizes = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                    ))
                    TextField("Kolory", text: Binding(
                        get: { (product.colors ?? []).joined(separator: ", ") },
                        set: { product.colors = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                    ))
                }
                
                Section(header: Text("Ceny")) {
                    ForEach($editablePrices) { $entry in
                        HStack {
                            TextField("Waluta", text: $entry.currency)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)

                            TextField("Cena", text: $entry.value)
                                .keyboardType(.decimalPad)

                            Button(role: .destructive) {
                                editablePrices.removeAll { $0.id == entry.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }

                    Button("Dodaj walutę") {
                        editablePrices.append(EditablePrice(currency: "PLN", value: "0"))
                    }
                }


                
                
                
                Section(header: Text("Zdjęcie")) {
                    if let data = product.photoData, let image = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(10)
                                .clipped()

                            Button(action: {
                                product.photoData = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.title)
                                    .padding(8)
                                    .background(Color.white.opacity(0.8))
                                    .clipShape(Circle())
                            }
                            .padding(-15)
                        }
                        .padding(.top, 15)
                    }

                    PhotosPicker("Wybierz zdjęcie", selection: $selectedItem)
                        .onChange(of: selectedItem) { newItem in
                            if let newItem {
                                Task {
                                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                                        product.photoData = data
                                    }
                                }
                            }
                        }
                }
                
                if let colors = product.colors {
                    Section(header: Text("Zdjęcia kolorów")) {
                        ForEach(colors, id: \.self) { color in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(color.capitalized)

                                if let data = product.colorsPhotosData[color], let image = UIImage(data: data) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxHeight: 150)
                                            .cornerRadius(8)

                                        Button(action: {
                                            product.colorsPhotosData.removeValue(forKey: color)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .font(.title2)
                                                .padding(6)
                                                .background(Color.white.opacity(0.8))
                                                .clipShape(Circle())
                                        }
                                        .padding(-12)
                                    }
                                }

                                PhotosPicker("Wybierz zdjęcie dla \(color)", selection: Binding(
                                    get: { nil },
                                    set: { newItem in
                                        guard let newItem else { return }
                                        Task {
                                            if let data = try? await newItem.loadTransferable(type: Data.self) {
                                                if product.colorsPhotosData == nil {
                                                    product.colorsPhotosData = [:]
                                                }
                                                product.colorsPhotosData[color] = data
                                            }
                                        }
                                    }
                                ))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                
                
            }
            .onAppear {
                editablePrices = product.priceByCurrency.map { EditablePrice(currency: $0.key, value: String($0.value)) }
            }


            Button("Zapisz") {
                var newMap: [String: Double] = [:]
                for entry in editablePrices {
                    if let price = Double(entry.value), !entry.currency.isEmpty {
                        newMap[entry.currency] = price
                    }
                }
                product.priceByCurrency = newMap
                product.timestamp = Date().timeIntervalSince1970
                onSave?(product)
                dismiss()
                
            }

            .padding()
        }
    }
}

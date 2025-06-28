import SwiftUI

//
struct ProductSelectionView: View {
    @Namespace private var animationNamespace

    let productTypes: [ProductType]
    let showCurrencyPicker: Bool
    let onSubmit: (ProductUpdate) -> Void
    let originPeerID: String

    @Binding var selectedType: ProductType?
    @Binding var selectedGender: String?
    @Binding var selectedSize: String?
    @Binding var selectedColor: String?
    @Binding var selectedCurrency: String?
    @Binding var selectedPrice: Double?
    @Binding var count: Int?
    @Binding var customCount: String
    
    @State var lastOrder: ProductUpdate? = nil

    let columns = [GridItem(.adaptive(minimum: 120))]

    var body: some View {
        
            ZStack(alignment: .bottom)
            {
                ScrollView {
                    VStack(spacing: 20) {
                        if selectedType == nil {
                                let availableWidth = UIScreen.main.bounds.width - 32
                                let minItemWidth: CGFloat = 140
                                let maxColumns = min(4, max(2, Int(availableWidth / minItemWidth)))
                                let totalSpacing = CGFloat(maxColumns - 1) * 20
                                let itemWidth = (availableWidth - totalSpacing) / CGFloat(maxColumns)
                                let totalHeight = itemWidth * ((CGFloat(1.0) + CGFloat(productTypes.count)) / CGFloat(maxColumns))
                                
                                let columns = Array(repeating: GridItem(.fixed(itemWidth), spacing: 20), count: maxColumns)
                                
                                
                                LazyVGrid(columns: columns, spacing: 20) {
                                    ForEach(productTypes, id: \.productID) { product in
                                        Button(action: {
                                            print("Tapped \(product.name)")
                                            selectedType = product
                                        }) {
                                            ZStack(alignment: .center)
                                            {
                                                Color.white.opacity(0.001)

                                                if let data = product.photoData, let image = UIImage(data: data) {
                                                    Image(uiImage: image)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .cornerRadius(10)
//                                                        .matchedGeometryEffect(id: "image_\(product.productID)", in: animationNamespace)
                                                    if #available(iOS 26.0, *) {
                                                        Text(product.name)
                                                            .font(.title2)
                                                            .bold()
                                                            .multilineTextAlignment(.center)
                                                            .lineLimit(3)
                                                            .frame(width: itemWidth*0.8, height: 30, alignment: .center)
                                                            .cornerRadius(10)
                                                            .glassEffect().allowsHitTesting(false)
                                                    } else {
                                                        Text(product.name)
                                                            .frame(width: itemWidth*0.8, height: 30, alignment: .center)
                                                            .background(Color.white.opacity(0.7))
                                                            .cornerRadius(10).allowsHitTesting(false)
                                                    }
                                                }
                                                else
                                                {
                                                    Text(product.name)
                                                        .font(.title2)
                                                        .bold()
                                                }
                                            }
                                            .frame(width: itemWidth, height: itemWidth)
                                            .background(product.productID == selectedType?.productID
                                                        ? Color.blue.opacity(0.3)
                                                        : Color.gray.opacity(0.1))
                                            .border(Color.red)
                                            .cornerRadius(10)
                                        }
                                        .contentShape(Rectangle())
                                        .frame(width: itemWidth, height: itemWidth)
                                        .buttonStyle(.plain)
                                    }
                                    if(lastOrder != nil)
                                    {
                                        lastProductView
                                    }
                                }
                                .allowsHitTesting(true)
                                .padding(.horizontal, 16)
                        }
                        if let type = selectedType {
                            VStack
                            {
                                Group {
                                    
                                    if let genders = type.genders {
                                        if(genders.count > 1)
                                        {
                                            SelectableOptionsView(title: "Płeć", options: genders, selected: $selectedGender)
                                        }
                                    }
                                    if let sizes = type.sizes {
                                        if(sizes.count > 1)
                                        {
                                            SelectableOptionsView(title: "Rozmiar", options: sizes, selected: $selectedSize)
                                        }
                                    }
                                    if let colors = type.colors {
                                        if(colors.count > 1)
                                        {
                                            SelectableOptionsView(title: "Kolor", options: colors, selected: $selectedColor)
                                        }
                                    }
                                }
                                
                                if showCurrencyPicker {
                                    VStack(alignment: .leading, spacing: 4) {
                                        
                                        if #available(iOS 26.0, *) {
                                            GlassEffectContainer
                                            {
                                                Text("Płatność").font(.headline)
                                                    .padding()
                                                    .glassEffect()
                                                
                                                LazyVGrid(columns: columns, spacing: 4) {
                                                    ForEach(type.priceByCurrency.keys.sorted(), id: \.self) { currency in
                                                        if(currency == selectedCurrency)
                                                        {
                                                            Button(String(format: "%.2f %@", type.priceByCurrency[currency] ?? 0, currency)) {
                                                                selectedCurrency = currency
                                                                selectedPrice = type.priceByCurrency[currency] ?? 0
                                                            }
                                                            .padding(8)
                                                            .frame(width:100, height: 60)
                                                            .buttonStyle(.plain)
                                                            .glassEffect(.regular.tint(Color.orange))
                                                        }
                                                        else
                                                        {
                                                            Button(String(format: "%.2f %@", type.priceByCurrency[currency] ?? 0, currency)) {
                                                                selectedCurrency = currency
                                                                selectedPrice = type.priceByCurrency[currency] ?? 0
                                                            }
                                                            .padding(8)
                                                            .frame(width:100, height: 60)
                                                            .buttonStyle(.plain)
                                                            .glassEffect()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        else
                                        {
                                            Text("Płatność").font(.headline)
                                            
                                            LazyVGrid(columns: columns, spacing: 4) {
                                                ForEach(type.priceByCurrency.keys.sorted(), id: \.self) { currency in
                                                        Button(String(format: "%.2f %@", type.priceByCurrency[currency] ?? 0, currency)) {
                                                            selectedCurrency = currency
                                                            selectedPrice = type.priceByCurrency[currency] ?? 0
                                                        }
                                                        .padding(8)
                                                        .frame(width:100, height: 60)
                                                        .background(currency == selectedCurrency ? Color.orange.opacity(0.3) : Color.gray.opacity(0.1))
                                                        .cornerRadius(8)
                                                    }
                                                }
                                        }
                                    }
                                }
                                iloscView
                            }
                        }
                    }
                }
                if let type = selectedType {
                    HStack(spacing: 10) {
                        Button(action: {
                            selectedType = nil
                        }) {
                            if #available(iOS 26.0, *) {
                                Text("Anuluj")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .buttonStyle(.plain)
                                    .glassEffect()
                                    .matchedGeometryEffect(id: "name_\(type.productID)", in: animationNamespace)
                            } else {
                                Text("Anuluj")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                            }
                        }
                        Spacer()
                        if((type.colors?.count ?? 0 < 2 || selectedColor != nil) && (type.genders?.count ?? 0 < 2 || selectedGender != nil) && (type.sizes?.count ?? 0 < 2 || selectedSize != nil))
                        {
                            Button(action: {
                                let gender = selectedGender ?? type.genders?.first
                                let size = selectedSize ?? type.sizes?.first
                                let color = selectedColor ?? type.colors?.first
                                let currecy = selectedCurrency ?? type.priceByCurrency.keys.first ?? " "
                                let price = selectedPrice ?? type.priceByCurrency[currecy] ?? 0.0
                                let finalCount = count ?? 1
                                
                                let item = toItem(from: selectedType!, gender: gender, size: size, color: color)
                                
                                let update = ProductUpdate(
                                    productItemID: item.productID,
                                    delta: finalCount,
                                    price: price,
                                    currency: currecy ?? "",
                                    timestamp: Date().timeIntervalSince1970,
                                    originPeerID: originPeerID
                                )
                                lastOrder = update
                                onSubmit(update)
                                selectedType = nil
                                selectedGender = nil
                                selectedSize = nil
                                selectedColor = nil
                                selectedPrice = nil
                                selectedCurrency = nil
                                
                            }) {
                                if #available(iOS 26.0, *) {
                                    Text("OK")
                                        .bold()
                                        .padding()
                                        .buttonStyle(.plain)
                                        .frame(maxWidth: .infinity)
                                        .glassEffect()
                                } else {
                                    Text("OK")
                                        .bold()
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                }
            }
            .background {
                if let type = selectedType {
                    if let data = type.colorsPhotosData[selectedColor ?? "none"] ?? type.photoData,
                       let image = UIImage(data: data) {
                        GeometryReader { geometry in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width*1.15, height: geometry.size.height*1.15, alignment: .top)
                                .ignoresSafeArea()
                                .matchedGeometryEffect(id: "image_\(type.productID)", in: animationNamespace)
                        }
                    }
                }
            }
    }
    
    var lastProductView: some View {
            let availableWidth = UIScreen.main.bounds.width - 32
            let minItemWidth: CGFloat = 140
            let maxColumns = min(4, max(2, Int(availableWidth / minItemWidth)))
            let totalSpacing = CGFloat(maxColumns - 1) * 20
            let itemWidth = (availableWidth - totalSpacing) / CGFloat(maxColumns)
            let totalHeight = itemWidth * ((CGFloat(1.0) + CGFloat(productTypes.count)) / CGFloat(maxColumns))
        
        
            return Button(action: {
                if let lastOrder = lastOrder
                {
                    let update = ProductUpdate(
                        productItemID: lastOrder.productItemID,
                        delta: lastOrder.delta,
                        price: lastOrder.price,
                        currency: lastOrder.currency,
                        timestamp: Date().timeIntervalSince1970,
                        originPeerID: lastOrder.originPeerID
                    )
                    self.lastOrder = update
                    onSubmit(update)
                }
            }, label: {
                let idPrefix = lastOrder!.productItemID
                                 .split(separator: "_")           // returns [Substring]
                                 .first
                                 .map(String.init)                // Substring → String
                                 ?? "None__"
                
                if let product = productTypes.first(where: { $0.productID == idPrefix })
                {
                ZStack(alignment: .center)
                {
                    Color.white.opacity(0.001)
                    if let data = product.photoData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(10)
                    }
                            //                                                        .matchedGeometryEffect(id: "image_\(product.productID)", in: animationNamespace)
                            if #available(iOS 26.0, *) {
                                VStack
                                {
                                    Text("\(product.name)")
                                        .font(.title2)
                                        .bold()
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                        .frame(width: itemWidth*0.8, height: 30, alignment: .center)
                                        .cornerRadius(10)
                                        .glassEffect().allowsHitTesting(false)
                                    Text("\(lastOrder!.productItemID.components(separatedBy: "_").dropFirst().joined(separator: " "))")
                                        .font(.title2)
                                        .bold()
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                        .frame(width: itemWidth*0.8, height: 30, alignment: .center)
                                        .cornerRadius(10)
                                        .glassEffect().allowsHitTesting(false)
                                    Text("\(lastOrder!.delta.description)")
                                        .font(.title2)
                                        .bold()
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                        .frame(width: itemWidth*0.8, height: 30, alignment: .center)
                                        .cornerRadius(10)
                                        .glassEffect().allowsHitTesting(false)
                                    Text("\(lastOrder!.price.description) \(lastOrder!.currency)")
                                        .font(.title2)
                                        .bold()
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                        .frame(width: itemWidth*0.8, height: 30, alignment: .center)
                                        .cornerRadius(10)
                                        .glassEffect().allowsHitTesting(false)
                                }
                            } else {
                                Text(product.name)
                                    .frame(width: itemWidth*0.8, height: 30, alignment: .center)
                                    .background(Color.white.opacity(0.7))
                                    .cornerRadius(10).allowsHitTesting(false)
                                Text("\(lastOrder!.productItemID.components(separatedBy: "_").dropFirst().joined(separator: " "))")
                                    .frame(width: itemWidth*0.8, height: 30, alignment: .center)
                                    .background(Color.white.opacity(0.7))
                                    .cornerRadius(10).allowsHitTesting(false)
                                Text(lastOrder!.delta.description)
                                    .frame(width: itemWidth*0.8, height: 30, alignment: .center)
                                    .background(Color.white.opacity(0.7))
                                    .cornerRadius(10).allowsHitTesting(false)
                                Text("\(lastOrder!.price.description) \(lastOrder!.currency)")
                                    .frame(width: itemWidth*0.8, height: 30, alignment: .center)
                                    .background(Color.white.opacity(0.7))
                                    .cornerRadius(10).allowsHitTesting(false)
                            }
                    }
                    .frame(width: itemWidth, height: itemWidth)
                    .background(product.productID == selectedType?.productID
                                ? Color.blue.opacity(0.3)
                                : Color.gray.opacity(0.1))
                    .border(Color.green)
                    .cornerRadius(10)
                }
            })
            .contentShape(Rectangle())
            .frame(width: itemWidth, height: itemWidth)
            .buttonStyle(.plain)
        
    }
    var iloscView: some View {
        
        VStack(alignment: .leading, spacing: 10) {
            if #available(iOS 26.0, *) {
                
            } else {
                Text("Ilość").font(.headline)
            }
            
            if #available(iOS 26.0, *) {
                GlassEffectContainer
                {
                    Text("Ilość").font(.headline)
                        .padding()
                        .glassEffect()
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach([1,2,3,4,5,6,7,8,9,10,15,20,25], id: \.self) { n in
                                Button(action: {
                                    count = n
                                    customCount = ""
                                }) {
                                    if(count == n)
                                    {
                                        Text("\(n)")
                                            .frame(width:100, height: 60)
                                            .padding(8)
                                            .glassEffect(.regular.tint(Color.green))
                                    }
                                    else
                                    {
                                        Text("\(n)")
                                            .frame(width:100, height: 60)
                                            .padding(8)
                                            .glassEffect()
                                    }
                                }
                                .buttonStyle(.plain)

                        }
                        VStack()
                        {
                            TextField("np. 37", text: $customCount)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: customCount) { newValue in
                                    count = Int(newValue)
                                }
                        }
                        .frame(width: 100, height: 60)
                        .padding(8)
                        .glassEffect(count?.description == customCount ? .regular.tint(Color.green) : .regular)
                    }
                    
                }
            } else {
                
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach([1,2,3,4,5,6,7,8,9,10,15,20,25], id: \.self) { n in
                        Button(action: {
                            count = n
                            customCount = ""
                        }) {
                            Text("\(n)")
                                .frame(width:100, height: 70)
                                .padding(8)
                                .background(count == n ? Color.green.opacity(0.3) : Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        
                    }
                    
                    VStack()
                    {
                        TextField("np. 37", text: $customCount)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: customCount) { newValue in
                                count = Int(newValue)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom,  200)
    }
}

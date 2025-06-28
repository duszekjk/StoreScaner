import SwiftUI

struct SelectableOptionsView: View {
    let title: String
    let options: [String]
    @Binding var selected: String?

    // New: Track selected position for animation
    @State private var selectedRow: CGFloat = -10.0
    @State private var selectedCol: CGFloat = -10.0
    

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if #available(iOS 26.0, *) {
                GlassEffectContainer {
                    content.padding(10)
                }
            } else {
                content
            }
        }
    }

    @ViewBuilder
    var content: some View {
        if #available(iOS 26.0, *) {
            
            let columnsCount = 4
            VStack(alignment: .leading, spacing: 0.0)
            {
                Text(title)
                    .font(.headline)
                    .padding()
                    .glassEffect()
                    .padding()
                
                let columns = Array(repeating: GridItem(.flexible()), count: columnsCount)
                let baseWidth = (UIScreen.main.bounds.width / CGFloat(columnsCount)) + 1
                
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(options.indices, id: \.self) { index in
                        let option = options[index]
                        let col = CGFloat(index % columnsCount)
                        let row = CGFloat(index / columnsCount)
                        
                        let dx = abs(col - selectedCol)
                        let dy = abs(row - selectedRow)
                        let distance = sqrt(Double(dx * dx + dy * dy))
                        let influence = max(0, 1.0 - distance * 0.9)
                        let influence_tr = max(0, influence - 0.2)
                        
                        let width = CGFloat(baseWidth + 10 * influence)
                        let height = CGFloat(70 + 10 * influence)
                        let isSelected = selected == option
                        
                        Button(action: {
                            let newRow = row
                            let newCol = col
                            
                            // Only start animation if target is different
                            guard newRow != selectedRow || newCol != selectedCol else {
                                selected = option
                                return
                            }
                            
                            let steps = 12
                            let delay: Double = 0.02
                            
                            for step in 1...steps {
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay * Double(step)) {
                                    let progress = CGFloat(step) / CGFloat(steps)
                                    selectedRow = selectedRow + (newRow - selectedRow) * progress
                                    selectedCol = selectedCol + (newCol - selectedCol) * progress
                                }
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay * Double(steps + 1)) {
                                withAnimation(.easeOut(duration: 0.4)) {
                                    selected = option
                                }
                            }
                            
                        }) {
                            Text(option)
                                .frame(width: width,
                                       height: height)
                                .glassEffect(.regular.tint(.green.opacity(influence_tr)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else {
            Text(title)
                .font(.headline)
                .padding()
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 4) {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        withAnimation {
                            selected = option
                        }
                    }) {
                        if selected == option {
                            Text(option)
                                .frame(width: 100, height: 60)
                                .background(.green.opacity(0.4))
                        } else {
                            Text(option)
                                .frame(width: 100, height: 60)
                                .background(.gray.opacity(0.3))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

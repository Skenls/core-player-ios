import SwiftUI

// Material-style tab row: text tabs with a white underline indicator (no accent).

struct SegmentedPicker<T: Hashable>: View {
    let items: [T]
    let title: (T) -> String
    @Binding var selection: T

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                let selected = selection == item
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = item }
                } label: {
                    VStack(spacing: 8) {
                        Text(title(item))
                            .font(.system(size: 15, weight: selected ? .bold : .medium))
                            .foregroundColor(selected ? CoreColors.textPrimary : CoreColors.textSecondary)
                            .lineLimit(1)
                        Group {
                            if selected {
                                Capsule().fill(Color.white)
                                    .matchedGeometryEffect(id: "indicator", in: indicator)
                            } else {
                                Capsule().fill(Color.clear)
                            }
                        }
                        .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }
}

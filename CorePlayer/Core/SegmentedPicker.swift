import SwiftUI

struct SegmentedPicker<T: Hashable>: View {
    let items: [T]
    let title: (T) -> String
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = item }
                } label: {
                    Text(title(item))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selection == item ? .white : CoreColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selection == item ? CoreColors.surfaceVariant : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(CoreColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

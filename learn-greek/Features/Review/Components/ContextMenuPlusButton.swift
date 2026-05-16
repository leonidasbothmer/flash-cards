import SwiftUI

struct ContextMenuPlusButtonRepresentable: View {
    let onAdd: () -> Void
    let onBatchAdd: () -> Void
    let controlSize: CGFloat

    var body: some View {
        Menu {
            Button("Add one card", systemImage: "plus") {
                onAdd()
            }

            Button("Add multiple cards", systemImage: "tablecells") {
                onBatchAdd()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: controlSize, height: controlSize)
        } primaryAction: {
            onAdd()
        }
        .frame(width: controlSize, height: controlSize)
        .buttonStyle(.plain)
    }
}

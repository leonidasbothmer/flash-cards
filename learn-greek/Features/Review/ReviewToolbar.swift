import SwiftUI

struct ReviewToolbar: View {
    let hasCurrentCard: Bool
    @Binding var isStreakFireEnabled: Bool
    @Binding var isBackSideFirst: Bool
    let onFocus: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onAdd: () -> Void
    let onBatchAdd: () -> Void

    private let toolbarControlSize: CGFloat = 48

    var body: some View {
        bottomToolbar
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    private var bottomToolbar: some View {
        ZStack {
            HStack {
                optionsMenu

                Spacer(minLength: 24)

                addButton
            }

            HStack(spacing: 0) {
                toolbarIconButton(systemName: "trash", isEnabled: hasCurrentCard, action: onDelete)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(
                                    key: TrashButtonFramePreferenceKey.self,
                                    value: proxy.frame(in: .named("reviewSpace"))
                                )
                        }
                    )

                toolbarIconButton(systemName: "pencil", isEnabled: hasCurrentCard, action: onEdit)
            }
            .frame(height: toolbarControlSize)
            .padding(.horizontal, 4)
            .glassEffect(
                .regular.tint(.clear).interactive(),
                in: .rect(cornerRadius: toolbarControlSize / 2)
            )
        }
    }

    private var addButton: some View {
        ContextMenuPlusButtonRepresentable(
            onAdd: onAdd,
            onBatchAdd: onBatchAdd,
            controlSize: toolbarControlSize
        )
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: AddButtonFramePreferenceKey.self,
                        value: proxy.frame(in: .named("reviewSpace"))
                    )
            }
        )
        .glassEffect(
            .regular.tint(.clear).interactive(),
            in: Circle()
        )
    }

    private var optionsMenu: some View {
        Menu {
            Button("Focus Mode", systemImage: "eye.slash") {
                onFocus()
            }
            .disabled(!hasCurrentCard)

            Toggle("Show Back First", systemImage: "rectangle.on.rectangle.angled", isOn: $isBackSideFirst)

            Toggle("Streak Fire", systemImage: "flame", isOn: $isStreakFireEnabled)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: toolbarControlSize, height: toolbarControlSize)
        }
        .frame(width: toolbarControlSize, height: toolbarControlSize)
        .buttonStyle(.plain)
        .glassEffect(
            .regular.tint(.clear).interactive(),
            in: Circle()
        )
    }

    private func toolbarIconButton(
        systemName: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary.opacity(isEnabled ? 1 : 0.35))
                .frame(width: toolbarControlSize, height: toolbarControlSize)
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
}

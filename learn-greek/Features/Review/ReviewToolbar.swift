import SwiftUI

struct ReviewToolbar: View {
    let hasCurrentCard: Bool
    @Binding var isStreakFireEnabled: Bool
    let onFocus: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onAdd: () -> Void

    private let toolbarControlSize: CGFloat = 48

    var body: some View {
        bottomToolbar
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    private var bottomToolbar: some View {
        HStack {
            optionsMenu

            Spacer(minLength: 24)

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

                toolbarIconButton(systemName: "plus", action: onAdd)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(
                                    key: AddButtonFramePreferenceKey.self,
                                    value: proxy.frame(in: .named("reviewSpace"))
                                )
                        }
                    )
            }
            .frame(height: toolbarControlSize)
            .padding(.horizontal, 4)
            .glassEffect(
                .regular.tint(.clear).interactive(),
                in: .rect(cornerRadius: toolbarControlSize / 2)
            )
        }
    }

    private var optionsMenu: some View {
        Menu {
            Button("Focus Mode", systemImage: "eye.slash") {
                onFocus()
            }
            .disabled(!hasCurrentCard)

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

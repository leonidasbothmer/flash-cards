import SwiftUI

struct ReviewKeyboardAccessory: View {
    let showsSave: Bool
    let showsFlip: Bool
    let onCancel: () -> Void
    let onFlip: (() -> Void)?
    let onSave: () -> Void

    @Namespace private var glassNamespace

    private let controlSize: CGFloat = 48

    init(
        isSaveEnabled: Bool,
        showsFlip: Bool = true,
        onCancel: @escaping () -> Void,
        onFlip: (() -> Void)? = nil,
        onSave: @escaping () -> Void
    ) {
        self.showsSave = isSaveEnabled
        self.showsFlip = showsFlip
        self.onCancel = onCancel
        self.onFlip = onFlip
        self.onSave = onSave
    }

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                accessoryButton(systemName: "xmark", id: "cancel", action: onCancel)

                if showsFlip, let onFlip {
                    accessoryButton(systemName: "rectangle.portrait.rotate", id: "flip", action: onFlip)
                }

                if showsSave {
                    accessoryButton(systemName: "checkmark", id: "save", action: onSave)
                        .glassEffectTransition(.materialize)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(height: controlSize)
            .padding(.horizontal, 4)
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.86), value: showsSave)
    }

    private func accessoryButton(
        systemName: String,
        id: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary.opacity(isEnabled ? 1 : 0.35))
                .frame(width: controlSize, height: controlSize)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .glassEffect(
            .regular.tint(.clear).interactive(isEnabled),
            in: .rect(cornerRadius: controlSize / 2)
        )
        .glassEffectID(id, in: glassNamespace)
        .glassEffectUnion(id: "edit-accessory-band", namespace: glassNamespace)
    }
}

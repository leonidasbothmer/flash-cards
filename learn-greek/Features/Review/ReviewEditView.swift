import SwiftUI

private enum ReviewEditField: Hashable {
    case front
    case back
}

struct ReviewEditView: View {
    @Binding var isBackSide: Bool
    @Binding var draftFrontText: String
    @Binding var draftBackText: String
    let isKeyboardFocusRequested: Bool
    let isSaveEnabled: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    @FocusState private var focusedField: ReviewEditField?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.08), radius: 24, y: 10)

            ZStack {
                editor(
                    text: $draftFrontText,
                    prompt: "Front",
                    field: .front
                )
                .opacity(isBackSide ? 0 : 1)
                .allowsHitTesting(!isBackSide)

                editor(
                    text: $draftBackText,
                    prompt: "Back",
                    field: .back
                )
                .opacity(isBackSide ? 1 : 0)
                .allowsHitTesting(isBackSide)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                keyboardButton(systemName: "xmark", action: onCancel)

                Spacer(minLength: 8)

                Text(isBackSide ? "Back" : "Front")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(.quaternary, in: Capsule())

                Spacer(minLength: 8)

                keyboardButton(systemName: "rectangle.portrait.rotate", action: flipSide)
                keyboardButton(systemName: "checkmark", isEnabled: isSaveEnabled, action: onSave)
            }
        }
        .onAppear {
            updateFocus()
        }
        .onChange(of: isBackSide) { _, _ in
            updateFocus()
        }
        .onChange(of: isKeyboardFocusRequested) { _, _ in
            updateFocus()
        }
    }

    private func editor(text: Binding<String>, prompt: String, field: ReviewEditField) -> some View {
        ZStack(alignment: .center) {
            if text.wrappedValue.isEmpty {
                Text(prompt)
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.28))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            TextEditor(text: text)
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: field)
                .opacity(text.wrappedValue.isEmpty ? 0.14 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func keyboardButton(
        systemName: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary.opacity(isEnabled ? 1 : 0.35))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func flipSide() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isBackSide.toggle()
        }
    }

    private func updateFocus() {
        focusedField = isKeyboardFocusRequested ? activeField : nil
    }

    private var activeField: ReviewEditField {
        isBackSide ? .back : .front
    }
}

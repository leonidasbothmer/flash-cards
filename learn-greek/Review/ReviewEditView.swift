import SwiftUI

private enum ReviewEditField: Hashable {
    case front
    case english
    case german
}

struct ReviewEditView: View {
    let note: CardNote
    @Binding var isBackSide: Bool
    @Binding var draftFrontText: String
    @Binding var draftEnglishText: String
    @Binding var draftGermanText: String
    let isSaveEnabled: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    @FocusState private var focusedField: ReviewEditField?

    private var showsGermanBackField: Bool {
        CardNoteDisplay.showsGermanBackField(for: note)
    }

    var body: some View {
        ZStack {
            Color.white

            ZStack {
                frontEditor
                    .opacity(isBackSide ? 0 : 1)
                    .allowsHitTesting(!isBackSide)

                backEditor
                    .opacity(isBackSide ? 1 : 0)
                    .allowsHitTesting(isBackSide)
            }
            .padding(.horizontal, 28)
            .padding(.top, 48)
            .padding(.bottom, 28)
        }
        .ignoresSafeArea()
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
            focusActiveSide(after: 0.25)
        }
        .onChange(of: isBackSide) { _, _ in
            focusActiveSide(after: 0.05)
        }
    }

    private var frontEditor: some View {
        editor(
            text: $draftFrontText,
            prompt: CardNoteDisplay.frontEditorPrompt(for: note),
            field: .front
        )
    }

    @ViewBuilder
    private var backEditor: some View {
        if showsGermanBackField {
            VStack(spacing: 18) {
                editor(
                    text: $draftEnglishText,
                    prompt: CardNoteDisplay.backEditorPrompt(for: note),
                    field: .english
                )
                editor(
                    text: $draftGermanText,
                    prompt: "German",
                    field: .german
                )
            }
        } else {
            editor(
                text: $draftEnglishText,
                prompt: CardNoteDisplay.backEditorPrompt(for: note),
                field: .english
            )
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

    private func focusActiveSide(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            focusedField = activeFieldForCurrentSide
        }
    }

    private var activeFieldForCurrentSide: ReviewEditField {
        if isBackSide {
            return showsGermanBackField ? .german : .english
        }
        return .front
    }
}

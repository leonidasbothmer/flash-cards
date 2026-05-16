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
    let isBackFaceVisible: Bool

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
                .opacity(isBackFaceVisible ? 0 : 1)
                .allowsHitTesting(!isBackFaceVisible)

                editor(
                    text: $draftBackText,
                    prompt: "Back",
                    field: .back
                )
                .modifier(BackFaceTilt())
                .opacity(isBackFaceVisible ? 1 : 0)
                .allowsHitTesting(isBackFaceVisible)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear {
            updateFocus()
        }
        .onChange(of: isBackSide) { _, _ in
            updateFocus()
        }
        .onChange(of: isBackFaceVisible) { _, _ in
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

            TextField("", text: text, axis: .vertical)
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .lineLimit(1...8)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: field)
                .opacity(text.wrappedValue.isEmpty ? 0.14 : 1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func updateFocus() {
        focusedField = isKeyboardFocusRequested ? activeField : nil
    }

    private var activeField: ReviewEditField {
        isBackFaceVisible ? .back : .front
    }
}

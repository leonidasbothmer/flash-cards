import SwiftUI
import UIKit

enum KeyboardLanguageColumn {
    case front
    case back

    var preferredPrimaryLanguage: String {
        switch self {
        case .front: return "el"
        case .back: return "en"
        }
    }
}

enum KeyboardLanguagePreferences {
    private static var lastPrimaryLanguageByColumn: [KeyboardLanguageColumn: String] = [:]

    static func cachedInputMode(for column: KeyboardLanguageColumn) -> UITextInputMode? {
        guard let language = lastPrimaryLanguageByColumn[column] else { return nil }
        return activeInputModes.first { $0.primaryLanguage == language }
    }

    static func store(_ mode: UITextInputMode?, for column: KeyboardLanguageColumn) {
        guard let language = mode?.primaryLanguage else { return }
        lastPrimaryLanguageByColumn[column] = language
    }

    static func preferredInputMode(for column: KeyboardLanguageColumn) -> UITextInputMode? {
        if let cached = cachedInputMode(for: column) {
            return cached
        }

        let targetLanguage = column.preferredPrimaryLanguage
        return activeInputModes.first { $0.primaryLanguage == targetLanguage }
    }

    private static var activeInputModes: [UITextInputMode] {
        UITextInputMode.activeInputModes
    }
}

final class PreferredInputModeTextView: UITextView {
    var preferredTextInputMode: UITextInputMode?

    override var textInputMode: UITextInputMode? {
        preferredTextInputMode ?? super.textInputMode
    }
}

struct KeyboardLanguageTextField: UIViewRepresentable {
    @Binding var text: String
    let column: KeyboardLanguageColumn
    let placeholder: String
    var isFocused: Bool = false
    let onFocusChange: (Bool) -> Void
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PreferredInputModeTextView {
        let textView = PreferredInputModeTextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 17, weight: .semibold)
        textView.textAlignment = .center
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.returnKeyType = .default
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 0, bottom: 10, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.inputAccessoryView = context.coordinator.makeAccessoryView()

        let placeholderLabel = UILabel()
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.textAlignment = .center
        placeholderLabel.numberOfLines = 1
        textView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: textView.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: textView.centerYAnchor),
            placeholderLabel.leadingAnchor.constraint(greaterThanOrEqualTo: textView.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: textView.trailingAnchor)
        ])
        context.coordinator.placeholderLabel = placeholderLabel

        return textView
    }

    func updateUIView(_ uiView: PreferredInputModeTextView, context: Context) {
        context.coordinator.parent = self

        if uiView.text != text {
            uiView.text = text
        }

        context.coordinator.placeholderLabel?.text = placeholder
        context.coordinator.placeholderLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        context.coordinator.placeholderLabel?.textColor = UIColor.label.withAlphaComponent(0.28)
        context.coordinator.placeholderLabel?.isHidden = !text.isEmpty

        if isFocused, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }

        if uiView.isFirstResponder {
            KeyboardLanguageTextField.applyPreferredInputMode(to: uiView, column: column)
        }
    }

    static func dismantleUIView(_ uiView: PreferredInputModeTextView, coordinator: Coordinator) {
        uiView.resignFirstResponder()
        uiView.delegate = nil
    }

    static func applyPreferredInputMode(to textView: UITextView, column: KeyboardLanguageColumn) {
        guard let textView = textView as? PreferredInputModeTextView else { return }
        textView.preferredTextInputMode = KeyboardLanguagePreferences.preferredInputMode(for: column)
        textView.reloadInputViews()
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: KeyboardLanguageTextField
        weak var placeholderLabel: UILabel?

        init(parent: KeyboardLanguageTextField) {
            self.parent = parent
        }

        func makeAccessoryView() -> UIView {
            let container = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 52))
            container.backgroundColor = .clear

            let toolbar = UIToolbar()
            toolbar.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(toolbar)
            NSLayoutConstraint.activate([
                toolbar.topAnchor.constraint(equalTo: container.topAnchor),
                toolbar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                toolbar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                toolbar.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
            ])

            let nextItem = UIBarButtonItem(
                image: UIImage(systemName: "arrow.right.to.line"),
                style: .plain,
                target: self,
                action: #selector(focusNextCell)
            )
            nextItem.accessibilityLabel = "Next Cell"
            toolbar.items = [
                UIBarButtonItem.flexibleSpace(),
                nextItem
            ]
            return container
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
            placeholderLabel?.isHidden = !parent.text.isEmpty
        }

        @objc private func focusNextCell() {
            parent.onSubmit()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFocusChange(true)
            KeyboardLanguageTextField.applyPreferredInputMode(to: textView, column: parent.column)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onFocusChange(false)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            KeyboardLanguagePreferences.store(textView.textInputMode, for: parent.column)
        }
    }
}

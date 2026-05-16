import SwiftUI
import UIKit

struct BatchAddCardsView: View {
    let onCancel: () -> Void
    let onSave: (_ completedRows: [(front: String, back: String)]) -> Void

    @State private var rows: [BatchRowDraft] = [
        BatchRowDraft(),
        BatchRowDraft(isPlaceholder: true)
    ]
    @State private var validationErrors: Set<BatchCellID> = []
    @State private var focusedCell: BatchCellID?
    @State private var isDiscardConfirmationPresented = false
    @State private var isClosingSheet = false

    private let rowHeight: CGFloat = 52
    private let rowLineHeight: CGFloat = 24

    private var canAttemptSave: Bool {
        BatchRowValidator.canAttemptSave(rows)
    }

    private var hasDraftContent: Bool {
        BatchRowValidator.hasAnyContent(rows)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                                    rowView(row: row, index: index)
                                        .id(row.id)
                                }
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                        }
                        .frame(maxHeight: tableMaxHeight(for: proxy.size.height), alignment: .top)
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: validationErrors) { _, _ in
                            guard let first = firstValidationErrorInRowOrder() else { return }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                scrollProxy.scrollTo(first.rowID, anchor: .center)
                            }
                        }
                        .onChange(of: rows.count) { _, _ in
                            guard let focusedCell else { return }
                            withAnimation(.easeInOut(duration: 0.18)) {
                                scrollProxy.scrollTo(focusedCell.rowID, anchor: .center)
                            }
                        }
                        .onChange(of: focusedCell) { _, cellID in
                            guard let cellID else { return }
                            withAnimation(.easeInOut(duration: 0.18)) {
                                scrollProxy.scrollTo(cellID.rowID, anchor: .center)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.white)
            }
            .navigationTitle("Add Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    toolbarIconButton(systemName: "xmark", accessibilityLabel: "Cancel", action: requestCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    toolbarIconButton(systemName: "checkmark", accessibilityLabel: "Save", action: attemptSave)
                        .disabled(!canAttemptSave)
                        .tint(.blue)
                }
            }
            .alert(
                "Discard cards?",
                isPresented: $isDiscardConfirmationPresented
            ) {
                Button("Discard", role: .destructive, action: cancelAndDismiss)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your creations will be lost.")
            }
            .interactiveDismissDisabled(hasDraftContent)
            .onAppear {
                isClosingSheet = false
                DispatchQueue.main.async {
                    guard !isClosingSheet else { return }
                    focusedCell = BatchCellID(rowID: rows[0].id, column: .front)
                }
            }
            .onDisappear {
                isClosingSheet = true
                dismissKeyboard()
            }
        }
    }

    private func toolbarIconButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func tableMaxHeight(for sheetHeight: CGFloat) -> CGFloat {
        let contentHeight = rows.reduce(36) { partialHeight, row in
            partialHeight + rowHeight(for: row) + 1
        }
        let halfSheetHeight = max(rowHeight * 3, sheetHeight * 0.5)
        return min(contentHeight, halfSheetHeight)
    }

    private func rowView(row: BatchRowDraft, index: Int) -> some View {
        let showDivider = !row.isPlaceholder || index > 0
        let height = rowHeight(for: row)

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                cell(
                    text: binding(for: row.id, column: .front, keyPath: \.front),
                    row: row,
                    column: .front,
                    placeholder: "Front"
                )
                cell(
                    text: binding(for: row.id, column: .back, keyPath: \.back),
                    row: row,
                    column: .back,
                    placeholder: "Back"
                )
            }
            .frame(height: height)
            .animation(.spring(response: 0.24, dampingFraction: 0.88), value: height)

            if showDivider {
                Rectangle()
                    .fill(row.isPlaceholder ? Color.clear : Color.black.opacity(0.12))
                    .frame(height: 1)
            }
        }
    }

    private func rowHeight(for row: BatchRowDraft) -> CGFloat {
        let lineCount = max(lineCount(in: row.front), lineCount(in: row.back))
        return rowHeight + CGFloat(max(0, lineCount - 1)) * rowLineHeight
    }

    private func lineCount(in text: String) -> Int {
        max(1, text.components(separatedBy: .newlines).count)
    }

    private func cell(
        text: Binding<String>,
        row: BatchRowDraft,
        column: BatchCellColumn,
        placeholder: String
    ) -> some View {
        let cellID = BatchCellID(rowID: row.id, column: column)
        let hasError = validationErrors.contains(cellID)
        let languageColumn: KeyboardLanguageColumn = column == .front ? .front : .back

        return ZStack {
            if hasError {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.red.opacity(0.08))
            }

            KeyboardLanguageTextField(
                text: text,
                column: languageColumn,
                placeholder: placeholder,
                isFocused: focusedCell == cellID && !isClosingSheet,
                onFocusChange: { isFocused in
                    guard !isClosingSheet else { return }
                    if isFocused {
                        focusedCell = cellID
                    } else if focusedCell == cellID {
                        focusedCell = nil
                    }
                },
                onSubmit: { focusNext(from: cellID) }
            )
            .padding(.horizontal, 10)
        }
        .overlay {
            if hasError {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.red, lineWidth: 1.5)
                    .padding(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isClosingSheet else { return }
            focusedCell = cellID
        }
    }

    private func binding(
        for rowID: UUID,
        column: BatchCellColumn,
        keyPath: WritableKeyPath<BatchRowDraft, String>
    ) -> Binding<String> {
        Binding(
            get: {
                rows.first(where: { $0.id == rowID })?[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                guard let index = rows.firstIndex(where: { $0.id == rowID }) else { return }
                rows[index][keyPath: keyPath] = newValue
                validationErrors.remove(BatchCellID(rowID: rowID, column: column))
                syncRowsAfterEdit(at: index)
            }
        )
    }

    private func syncRowsAfterEdit(at index: Int) {
        if rows[index].isPlaceholder {
            let row = rows[index]
            if !BatchRowValidator.isEmpty(row) {
                rows[index].isPlaceholder = false
            }
        }

        if let lastNonPlaceholder = rows.lastIndex(where: { !$0.isPlaceholder }),
           BatchRowValidator.isComplete(rows[lastNonPlaceholder]) {
            if lastNonPlaceholder == rows.count - 1 {
                rows.append(BatchRowDraft(isPlaceholder: true))
            } else if !rows[lastNonPlaceholder + 1].isPlaceholder {
                rows.insert(BatchRowDraft(isPlaceholder: true), at: lastNonPlaceholder + 1)
            }
        }

        while rows.count >= 2,
              rows[rows.count - 1].isPlaceholder,
              rows[rows.count - 2].isPlaceholder,
              BatchRowValidator.isEmpty(rows[rows.count - 2]) {
            rows.remove(at: rows.count - 2)
        }
    }

    private func focusNext(from cellID: BatchCellID) {
        guard !isClosingSheet,
              let rowIndex = rows.firstIndex(where: { $0.id == cellID.rowID })
        else { return }

        switch cellID.column {
        case .front:
            focusedCell = BatchCellID(rowID: cellID.rowID, column: .back)
        case .back:
            let nextIndex = rowIndex + 1
            if nextIndex < rows.count {
                focusedCell = BatchCellID(rowID: rows[nextIndex].id, column: .front)
            } else {
                syncRowsAfterEdit(at: rowIndex)
                if let newRow = rows.dropFirst(rowIndex + 1).first {
                    focusedCell = BatchCellID(rowID: newRow.id, column: .front)
                }
            }
        }
    }

    private func requestCancel() {
        dismissKeyboard()
        if hasDraftContent {
            isDiscardConfirmationPresented = true
        } else {
            cancelAndDismiss()
        }
    }

    private func cancelAndDismiss() {
        isClosingSheet = true
        dismissKeyboard()
        DispatchQueue.main.async {
            onCancel()
        }
    }

    private func dismissKeyboard() {
        focusedCell = nil
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            windowScene.windows.forEach { $0.endEditing(true) }
        }
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func firstValidationErrorInRowOrder() -> BatchCellID? {
        rows.lazy
            .flatMap { row in
                [
                    BatchCellID(rowID: row.id, column: .front),
                    BatchCellID(rowID: row.id, column: .back)
                ]
            }
            .first { validationErrors.contains($0) }
    }

    private func attemptSave() {
        let errors = BatchRowValidator.partialRowEmptyCells(from: rows)
        guard errors.isEmpty else {
            validationErrors = Set(errors)
            if let first = errors.first {
                focusedCell = first
            }
            return
        }

        let completed = BatchRowValidator.completedRows(from: rows)
        guard !completed.isEmpty else { return }

        let payload = completed.map {
            (
                front: BatchRowValidator.trimmedFront($0),
                back: BatchRowValidator.trimmedBack($0)
            )
        }
        isClosingSheet = true
        dismissKeyboard()
        DispatchQueue.main.async {
            onSave(payload)
        }
    }
}

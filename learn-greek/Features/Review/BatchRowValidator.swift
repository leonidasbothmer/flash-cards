import Foundation

struct BatchRowDraft: Identifiable, Equatable {
    let id: UUID
    var front: String
    var back: String
    var isPlaceholder: Bool

    init(id: UUID = UUID(), front: String = "", back: String = "", isPlaceholder: Bool = false) {
        self.id = id
        self.front = front
        self.back = back
        self.isPlaceholder = isPlaceholder
    }
}

enum BatchCellColumn: Hashable {
    case front
    case back
}

struct BatchCellID: Hashable {
    let rowID: UUID
    let column: BatchCellColumn
}

enum BatchRowValidator {
    static func trimmedFront(_ row: BatchRowDraft) -> String {
        row.front.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func trimmedBack(_ row: BatchRowDraft) -> String {
        row.back.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isComplete(_ row: BatchRowDraft) -> Bool {
        !trimmedFront(row).isEmpty && !trimmedBack(row).isEmpty
    }

    static func isPartial(_ row: BatchRowDraft) -> Bool {
        let hasFront = !trimmedFront(row).isEmpty
        let hasBack = !trimmedBack(row).isEmpty
        return hasFront != hasBack
    }

    static func isEmpty(_ row: BatchRowDraft) -> Bool {
        trimmedFront(row).isEmpty && trimmedBack(row).isEmpty
    }

    static func completedRows(from rows: [BatchRowDraft]) -> [BatchRowDraft] {
        rows.filter { !$0.isPlaceholder && isComplete($0) }
    }

    static func partialRowEmptyCells(from rows: [BatchRowDraft]) -> [BatchCellID] {
        rows.flatMap { row -> [BatchCellID] in
            guard !row.isPlaceholder, isPartial(row) else { return [] }
            if trimmedFront(row).isEmpty {
                return [BatchCellID(rowID: row.id, column: .front)]
            }
            return [BatchCellID(rowID: row.id, column: .back)]
        }
    }

    static func hasAnyContent(_ rows: [BatchRowDraft]) -> Bool {
        rows.contains { !isEmpty($0) }
    }

    static func canAttemptSave(_ rows: [BatchRowDraft]) -> Bool {
        hasAnyContent(rows)
    }
}

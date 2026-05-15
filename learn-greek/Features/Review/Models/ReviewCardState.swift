import Foundation

struct ReviewCardState: Identifiable, Hashable {
    let note: CardNote
    let progress: CardProgress

    var id: String { note.id }
}

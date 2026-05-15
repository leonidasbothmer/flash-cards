//
//  learn_greekTests.swift
//  learn-greekTests
//
//  Created by Leonidas von Bothmer on 30.04.26.
//

import Foundation
import Testing
@testable import learn_greek

struct learn_greekTests {
    @Test func wrongAnswerKeepsNewCardsNew() {
        let updated = ReviewEngine.apply(result: .wrong, to: .initial)

        #expect(updated.stack == .new)
        #expect(updated.correctStreak == 0)
    }

    @Test func twoCorrectAnswersPromoteSeenCard() {
        let progress = CardProgress(stack: .seen, correctStreak: 1, lastSeenAt: nil)
        let updated = ReviewEngine.apply(result: .correct, to: progress)

        #expect(updated.stack == .once)
        #expect(updated.correctStreak == 0)
    }

    @Test func wrongAnswerDemotesButNotBelowSeen() {
        let seen = CardProgress(stack: .seen, correctStreak: 1, lastSeenAt: nil)
        let know = CardProgress(stack: .know, correctStreak: 1, lastSeenAt: nil)

        let seenUpdated = ReviewEngine.apply(result: .wrong, to: seen)
        let knowUpdated = ReviewEngine.apply(result: .wrong, to: know)

        #expect(seenUpdated.stack == .seen)
        #expect(knowUpdated.stack == .good)
    }

    @Test func pickItemFromSpecificStackOnlyReturnsThatStack() throws {
        let newNote = CardNote(id: "new", cardType: .genericV1, facets: [CardFacetKey.front: ["new"]])
        let seenNote = CardNote(id: "seen", cardType: .genericV1, facets: [CardFacetKey.front: ["seen"]])
        let progressByID = [
            newNote.id: CardProgress(stack: .new, correctStreak: 0, lastSeenAt: nil),
            seenNote.id: CardProgress(stack: .seen, correctStreak: 0, lastSeenAt: nil)
        ]

        let selected = try #require(ReviewEngine.pickItem(
            from: .seen,
            items: [newNote, seenNote],
            progressByID: progressByID
        ))

        #expect(selected.id == seenNote.id)
        #expect(selected.progress.stack == .seen)
    }

    @Test func pickItemFromSpecificStackCanExcludeCurrentCard() throws {
        let first = CardNote(id: "first", cardType: .genericV1, facets: [CardFacetKey.front: ["first"]])
        let second = CardNote(id: "second", cardType: .genericV1, facets: [CardFacetKey.front: ["second"]])
        let progressByID = [
            first.id: CardProgress(stack: .seen, correctStreak: 0, lastSeenAt: nil),
            second.id: CardProgress(stack: .seen, correctStreak: 0, lastSeenAt: nil)
        ]

        let selected = try #require(ReviewEngine.pickItem(
            from: .seen,
            items: [first, second],
            progressByID: progressByID,
            excluding: first.id
        ))

        #expect(selected.id == second.id)
    }

    @Test func dataStoreLoadsSimpleFrontBackJSON() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }

        let json = """
        [
          { "front": "νερό", "back": "water" },
          { "front": "βιβλίο", "back": "book" }
        ]
        """

        try json.write(to: url, atomically: true, encoding: .utf8)

        let notes = try BundledCardCatalogLoader.loadCatalog(from: url)

        #expect(notes.count == 2)
        #expect(notes[0].cardType == .genericV1)
        #expect(notes[0].facets[CardFacetKey.front] == ["νερό"])
        #expect(notes[0].facets[CardFacetKey.back] == ["water"])
        #expect(notes[1].id == "seed.2")
    }
}

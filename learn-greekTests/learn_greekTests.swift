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
        let progress = VocabProgress(stack: .seen, correctStreak: 1, lastSeenAt: nil)
        let updated = ReviewEngine.apply(result: .correct, to: progress)

        #expect(updated.stack == .once)
        #expect(updated.correctStreak == 0)
    }

    @Test func wrongAnswerDemotesButNotBelowSeen() {
        let seen = VocabProgress(stack: .seen, correctStreak: 1, lastSeenAt: nil)
        let know = VocabProgress(stack: .know, correctStreak: 1, lastSeenAt: nil)

        let seenUpdated = ReviewEngine.apply(result: .wrong, to: seen)
        let knowUpdated = ReviewEngine.apply(result: .wrong, to: know)

        #expect(seenUpdated.stack == .seen)
        #expect(knowUpdated.stack == .good)
    }

    @Test func dataStoreMapsEnglishAndGermanFallbacks() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }

        let json = """
        [
          {
            "id": "sample",
            "greek": "νερό",
            "lemma": "νερό",
            "pos": "noun",
            "english": "water",
            "german": ["Wasser"]
          }
        ]
        """

        try json.write(to: url, atomically: true, encoding: .utf8)

        let items = try VocabDataStore.loadVocab(from: url)

        #expect(items.count == 1)
        #expect(items[0].english == ["water"])
        #expect(items[0].german == ["Wasser"])
    }
}

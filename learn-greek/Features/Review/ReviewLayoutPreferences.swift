import SwiftUI

struct StackFramePreferenceKey: PreferenceKey {
    static var defaultValue: [LearningStack: CGRect] = [:]

    static func reduce(value: inout [LearningStack: CGRect], nextValue: () -> [LearningStack: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct CardFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct AddButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct TrashButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

import SwiftUI

struct ReviewStackSummary: View {
    let countsByStack: [LearningStack: Int]
    let transferSourceStack: LearningStack?
    let transferDestinationStack: LearningStack?
    let transferSourcePulse: CGFloat
    let transferDestinationPulse: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            ForEach(LearningStack.allCases, id: \.self) { stack in
                StatPill(
                    title: stack.title,
                    count: countsByStack[stack] ?? 0,
                    color: pillColor(stack),
                    inwardPulse: transferSourceStack == stack ? transferSourcePulse : 0,
                    outwardPulse: transferDestinationStack == stack ? transferDestinationPulse : 0
                )
                .background(
                    GeometryReader { pillProxy in
                        Color.clear
                            .preference(
                                key: StackFramePreferenceKey.self,
                                value: [stack: pillProxy.frame(in: .named("reviewSpace"))]
                            )
                    }
                )
            }
        }
    }

    private func pillColor(_ stack: LearningStack) -> Color {
        switch stack {
        case .new: return .purple
        case .seen: return .red
        case .once: return .orange
        case .solid: return .yellow
        case .good: return .green
        case .know: return .blue
        }
    }
}

import SwiftUI

struct ReviewStackSummary: View {
    @State private var holdingStack: LearningStack?
    @State private var emptyShakeStack: LearningStack?
    @State private var emptyShakeOffset: CGFloat = 0
    @State private var pressedStack: LearningStack?
    @State private var pressedScale: CGFloat = 1
    @State private var visualLockedStack: LearningStack?

    let countsByStack: [LearningStack: Int]
    let transferSourceStack: LearningStack?
    let transferDestinationStack: LearningStack?
    let transferSourcePulse: CGFloat
    let transferDestinationPulse: CGFloat
    let dropTargetStack: LearningStack?
    let currentStack: LearningStack?
    let lockedStack: LearningStack?
    let onStackTap: (LearningStack) -> Void
    let onStackLongPress: (LearningStack) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(LearningStack.allCases, id: \.self) { stack in
                StatPill(
                    stack: stack,
                    title: stack.title,
                    count: countsByStack[stack] ?? 0,
                    color: stack.reviewColor,
                    inwardPulse: transferSourceStack == stack ? transferSourcePulse : 0,
                    outwardPulse: transferDestinationStack == stack ? transferDestinationPulse : 0,
                    isDropTargeted: dropTargetStack == stack,
                    showsCurrentCardIndicator: currentStack == stack,
                    isLocked: visualLockedStack == stack
                )
                .scaleEffect(scale(for: stack))
                .offset(x: emptyShakeStack == stack ? emptyShakeOffset : 0)
                .contentShape(Rectangle())
                .onTapGesture {
                    handleStackTap(stack)
                }
                .onLongPressGesture(
                    minimumDuration: 0.42,
                    maximumDistance: 18,
                    perform: {
                        handleStackLongPress(stack)
                    },
                    onPressingChanged: { isPressing in
                        updateHoldingStack(stack, isPressing: isPressing)
                    }
                )
                .animation(.spring(response: 0.28, dampingFraction: 0.88), value: holdingStack)
                .animation(.spring(response: 0.3, dampingFraction: 0.88), value: visualLockedStack)
            }
        }
        .onAppear {
            visualLockedStack = lockedStack
        }
        .onChange(of: lockedStack) { _, stack in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                visualLockedStack = stack
            }
        }
    }

    private func updateHoldingStack(_ stack: LearningStack, isPressing: Bool) {
        guard isPressing, (countsByStack[stack] ?? 0) > 0 else {
            if holdingStack == stack {
                holdingStack = nil
            }
            return
        }

        holdingStack = stack
    }

    private func scale(for stack: LearningStack) -> CGFloat {
        if holdingStack == stack {
            return 1.12
        }
        if pressedStack == stack {
            return pressedScale
        }
        return 1
    }

    private func handleStackTap(_ stack: LearningStack) {
        if lockedStack != nil {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                visualLockedStack = nil
            }
            onStackTap(stack)
            return
        }

        guard (countsByStack[stack] ?? 0) == 0 else {
            runFilledStackPress(for: stack)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onStackTap(stack)
            }
            return
        }

        runEmptyStackShake(for: stack)
    }

    private func handleStackLongPress(_ stack: LearningStack) {
        guard (countsByStack[stack] ?? 0) > 0 else {
            runEmptyStackShake(for: stack)
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
            visualLockedStack = stack
        }
        onStackLongPress(stack)
    }

    private func runFilledStackPress(for stack: LearningStack) {
        pressedStack = stack
        withAnimation(.easeInOut(duration: 0.06)) {
            pressedScale = 0.94
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            guard pressedStack == stack else { return }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.72)) {
                pressedScale = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            guard pressedStack == stack else { return }
            pressedStack = nil
        }
    }

    private func runEmptyStackShake(for stack: LearningStack) {
        emptyShakeStack = stack
        emptyShakeOffset = 0

        let sequence: [(TimeInterval, CGFloat)] = [
            (0.00, -3),
            (0.05, 3),
            (0.10, -2),
            (0.15, 2),
            (0.20, 0)
        ]

        for (delay, offset) in sequence {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard emptyShakeStack == stack else { return }
                withAnimation(.easeInOut(duration: 0.05)) {
                    emptyShakeOffset = offset
                }

                if offset == 0 {
                    emptyShakeStack = nil
                }
            }
        }
    }
}

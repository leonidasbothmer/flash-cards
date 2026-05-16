import SwiftUI

struct ReviewStackBurstEvent: Identifiable, Equatable {
    let id = UUID()
    let stack: LearningStack
    let origin: CGPoint
    let travelDistance: CGFloat
}

struct ReviewStackCompletionBurst: View {
    let event: ReviewStackBurstEvent

    @State private var isExpanded = false

    private let particles: [Particle] = [
        .init(angle: -152, distanceMultiplier: 0.88, size: 8.0, delay: 0.00),
        .init(angle: -96, distanceMultiplier: 1.06, size: 9.2, delay: 0.02),
        .init(angle: -18, distanceMultiplier: 0.96, size: 7.4, delay: 0.01),
        .init(angle: 46, distanceMultiplier: 1.0, size: 8.6, delay: 0.03),
        .init(angle: 132, distanceMultiplier: 0.82, size: 7.0, delay: 0.00)
    ]

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(event.stack.reviewBackgroundColor)
                    .frame(width: particle.size, height: particle.size)
                    .shadow(color: event.stack.reviewBackgroundColor.opacity(isExpanded ? 0 : 0.2), radius: 2)
                    .scaleEffect(isExpanded ? 0.34 : 1)
                    .opacity(isExpanded ? 0 : 0.92)
                    .offset(isExpanded ? particle.offset(travelDistance: event.travelDistance) : .zero)
                    .animation(
                        .easeOut(duration: 0.7).delay(particle.delay),
                        value: isExpanded
                    )
            }
        }
        .position(event.origin)
        .onAppear {
            isExpanded = false
            DispatchQueue.main.async {
                isExpanded = true
            }
        }
    }
}

private struct Particle: Identifiable {
    let id = UUID()
    let angle: Double
    let distanceMultiplier: CGFloat
    let size: CGFloat
    let delay: TimeInterval

    func offset(travelDistance: CGFloat) -> CGSize {
        let radians = angle * .pi / 180
        let distance = travelDistance * distanceMultiplier
        return CGSize(
            width: cos(radians) * distance,
            height: sin(radians) * distance
        )
    }
}

extension LearningStack {
    var reviewColor: Color {
        switch self {
        case .new: return .purple
        case .seen: return .red
        case .once: return .orange
        case .solid: return .yellow
        case .good: return .green
        case .know: return .blue
        }
    }

    var reviewBackgroundColor: Color {
        reviewColor.opacity(0.24)
    }
}

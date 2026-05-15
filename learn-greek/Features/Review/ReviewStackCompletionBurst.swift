import SwiftUI

struct ReviewStackBurstEvent: Identifiable, Equatable {
    let id = UUID()
    let stack: LearningStack
    let origin: CGPoint
}

struct ReviewStackCompletionBurst: View {
    let event: ReviewStackBurstEvent

    @State private var isExpanded = false

    private let particles: [Particle] = [
        .init(angle: -132, distanceFraction: 0.21, size: 8.0, delay: 0.00),
        .init(angle: -58, distanceFraction: 0.25, size: 9.2, delay: 0.02),
        .init(angle: 4, distanceFraction: 0.22, size: 7.4, delay: 0.01),
        .init(angle: 64, distanceFraction: 0.24, size: 8.6, delay: 0.03),
        .init(angle: 142, distanceFraction: 0.20, size: 7.0, delay: 0.00)
    ]

    var body: some View {
        GeometryReader { proxy in
            let travelBase = min(proxy.size.width, proxy.size.height)

            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(event.stack.reviewBackgroundColor)
                        .frame(width: particle.size, height: particle.size)
                        .shadow(color: event.stack.reviewBackgroundColor.opacity(isExpanded ? 0 : 0.2), radius: 2)
                        .scaleEffect(isExpanded ? 0.34 : 1)
                        .opacity(isExpanded ? 0 : 0.92)
                        .offset(isExpanded ? particle.offset(travelBase: travelBase) : .zero)
                        .animation(
                            .easeOut(duration: 0.52).delay(particle.delay),
                            value: isExpanded
                        )
                }
            }
            .position(event.origin)
        }
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
    let distanceFraction: CGFloat
    let size: CGFloat
    let delay: TimeInterval

    func offset(travelBase: CGFloat) -> CGSize {
        let radians = angle * .pi / 180
        let distance = travelBase * distanceFraction
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

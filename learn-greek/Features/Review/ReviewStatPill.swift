import SwiftUI

struct StatPill: View {
    let stack: LearningStack
    let title: String
    let count: Int
    let color: Color
    let inwardPulse: CGFloat
    let outwardPulse: CGFloat
    let isDropTargeted: Bool
    let showsCurrentCardIndicator: Bool

    var body: some View {
        let sourceScale = 1 - (0.12 * inwardPulse)
        let destinationScale = 1 + (0.14 * outwardPulse)
        let dropTargetScale: CGFloat = 1

        VStack(spacing: 4) {
            Text(shortNumber(count))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color.opacity(0.9))
                .frame(width: 52, height: 52)
                .background(tileFrameReader)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(UIColor.systemGray6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(color.opacity(0.24))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    color.opacity(isDropTargeted ? 0.9 : 0),
                                    lineWidth: isDropTargeted ? 3 : 0
                                )
                                .padding(1.5)
                        }
                        .overlay(alignment: .bottom) {
                            Circle()
                                .fill(color.opacity(showsCurrentCardIndicator ? 0.95 : 0))
                                .frame(width: 4, height: 4)
                                .padding(.bottom, 10)
                        }
                        .scaleEffect(
                            x: sourceScale * destinationScale * dropTargetScale,
                            y: sourceScale * destinationScale * dropTargetScale,
                            anchor: .center
                        )
                }
                .scaleEffect(
                    x: (1 - (0.04 * inwardPulse)) * (1 + (0.05 * outwardPulse)),
                    y: (1 - (0.04 * inwardPulse)) * (1 + (0.05 * outwardPulse)),
                    anchor: .center
                )

            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(color)
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.84), value: isDropTargeted)
    }

    private func shortNumber(_ value: Int) -> String {
        if value >= 1000 {
            let compact = Double(value) / 1000
            return String(format: compact >= 10 ? "%.0fk" : "%.1fk", compact)
        }
        return "\(value)"
    }

    private var tileFrameReader: some View {
        GeometryReader { tileProxy in
            Color.clear
                .preference(
                    key: StackFramePreferenceKey.self,
                    value: [stack: tileProxy.frame(in: .named("reviewSpace"))]
                )
        }
    }
}

import SwiftUI

struct StatPill: View {
    let title: String
    let count: Int
    let color: Color
    let inwardPulse: CGFloat
    let outwardPulse: CGFloat

    var body: some View {
        let sourceScale = 1 - (0.12 * inwardPulse)
        let destinationScale = 1 + (0.14 * outwardPulse)

        VStack(spacing: 4) {
            Text(shortNumber(count))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color.opacity(0.9))
                .frame(width: 52, height: 52)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.25))
                        .scaleEffect(
                            x: sourceScale * destinationScale,
                            y: sourceScale * destinationScale,
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
                .foregroundStyle(.secondary)
        }
    }

    private func shortNumber(_ value: Int) -> String {
        if value >= 1000 {
            let compact = Double(value) / 1000
            return String(format: compact >= 10 ? "%.0fk" : "%.1fk", compact)
        }
        return "\(value)"
    }
}

import SwiftUI

struct SplashScreenView: View {
    private let startDate = Date()
    private let displayDuration: TimeInterval = 1.85

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let progress = smoothStep(min(max(elapsed / displayDuration, 0), 1))

            GeometryReader { proxy in
                let targetSize = reviewCardSize(for: proxy.size)
                let cardWidth = lerp(54, targetSize.width, progress)
                let cardHeight = lerp(75, targetSize.height, progress)
                let cornerRadius = lerp(10, 28, progress)

                ZStack {
                    SplashSunriseBackground(progress: progress, time: elapsed)

                    SpinningSplashCard(
                        time: elapsed,
                        progress: progress,
                        cornerRadius: cornerRadius
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .shadow(
                        color: Color(red: 0.23, green: 0.08, blue: 0.31).opacity(0.18),
                        radius: lerp(18, 24, progress),
                        x: 0,
                        y: lerp(14, 10, progress)
                    )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .ignoresSafeArea()
    }

    private func reviewCardSize(for size: CGSize) -> CGSize {
        CGSize(
            width: min(max(size.width, 1) * 0.86, 420),
            height: min(max(size.height, 1) * 0.62, 620)
        )
    }

    private func smoothStep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }

    private func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: Double) -> CGFloat {
        start + (end - start) * CGFloat(progress)
    }
}

private struct SplashSunriseBackground: View {
    let progress: Double
    let time: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let longestSide = max(size.width, size.height)
            let bloomSize = longestSide * (0.92 + 2.25 * progress)
            let roseCenterY = size.height * (1.18 - 0.38 * progress)
            let drift = CGFloat(sin(time * 0.72) * 0.012)

            ZStack {
                fliederBase

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.86, green: 0.48, blue: 0.68).opacity(0.34),
                                Color(red: 0.76, green: 0.38, blue: 0.64).opacity(0.24),
                                Color(red: 0.66, green: 0.42, blue: 0.72).opacity(0.14),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: bloomSize * 0.5
                        )
                    )
                    .frame(width: bloomSize, height: bloomSize)
                    .position(x: size.width * (0.5 + drift), y: roseCenterY)
                    .blur(radius: 28 + 26 * progress)
                    .blendMode(.softLight)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.1 * progress),
                        Color.clear,
                        Color(red: 0.5, green: 0.42, blue: 0.64).opacity(0.1 * (1 - progress))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    private var fliederBase: some View {
        LinearGradient(
            colors: [
                Color(red: 0.72, green: 0.68, blue: 0.82),
                Color(red: 0.66, green: 0.61, blue: 0.78),
                Color(red: 0.59, green: 0.52, blue: 0.72)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct SpinningSplashCard: View {
    let time: TimeInterval
    let progress: Double
    let cornerRadius: CGFloat

    private var remainingTilt: Double {
        1 - progress
    }

    private var xDegrees: Double {
        remainingTilt * (22 * sin(time * 2.45 + 0.4) + 4 * sin(time * 0.86 + 1.8))
    }

    private var yDegrees: Double {
        remainingTilt * (30 * sin(time * 2.05 + 2.1) + 5 * sin(time * 2.8))
    }

    private var zDegrees: Double {
        1440 * progress + remainingTilt * 18 * sin(time * 1.2 + 0.9)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
            .rotation3DEffect(.degrees(xDegrees), axis: (x: 1, y: 0, z: 0), perspective: 0.82)
            .rotation3DEffect(.degrees(yDegrees), axis: (x: 0, y: 1, z: 0), perspective: 0.82)
            .rotationEffect(.degrees(zDegrees))
    }

    private var cardFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.98),
                Color(red: 0.97, green: 0.94, blue: 0.98).opacity(0.95),
                Color(red: 0.93, green: 0.88, blue: 0.96).opacity(0.9)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    SplashScreenView()
}

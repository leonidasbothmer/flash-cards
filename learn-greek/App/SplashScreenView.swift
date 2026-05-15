import SwiftUI

struct SplashScreenView: View {
    let targetCardFrame: CGRect?

    private let startDate = Date()
    private let loadingHoldDuration: TimeInterval = 0.42
    private let growthDuration: TimeInterval = 1.58
    private let baseSpinDegreesPerSecond = 92.0
    private let finalSpinDegrees = 900.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let growthPhase = min(max((elapsed - loadingHoldDuration) / growthDuration, 0), 1)
            let growthProgress = exponentialEaseIn(growthPhase)
            let backgroundOpacity = 1 - growthProgress
            let spinDegrees = spinDegrees(elapsed: elapsed, growthPhase: growthPhase)
            let reboundScale = reboundScale(for: growthPhase)

            GeometryReader { proxy in
                let targetFrame = targetCardFrame.flatMap { $0.isEmpty ? nil : $0 } ?? reviewCardFrame(for: proxy)
                let cardWidth = lerp(54, targetFrame.width, growthProgress)
                let cardHeight = lerp(75, targetFrame.height, growthProgress)
                let cardX = lerp(proxy.size.width * 0.5, targetFrame.midX, growthProgress)
                let cardY = lerp(proxy.size.height * 0.5, targetFrame.midY, growthProgress)
                let cornerRadius = lerp(10, 28, growthProgress)

                ZStack {
                    SplashBackground()
                        .ignoresSafeArea()
                        .opacity(backgroundOpacity)

                    SpinningSplashCard(
                        time: elapsed,
                        progress: growthProgress,
                        zDegrees: spinDegrees,
                        cornerRadius: cornerRadius
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .scaleEffect(reboundScale)
                    .position(x: cardX, y: cardY)
                    .shadow(
                        color: Color(red: 0.23, green: 0.08, blue: 0.31).opacity(0.18),
                        radius: lerp(18, 24, growthProgress),
                        x: 0,
                        y: lerp(14, 10, growthProgress)
                    )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private func reviewCardFrame(for proxy: GeometryProxy) -> CGRect {
        let reviewSize = CGSize(
            width: max(proxy.size.width, 1),
            height: max(proxy.size.height, 1)
        )
        let cardSize = CGSize(
            width: min(reviewSize.width * 0.86, 420),
            height: min(reviewSize.height * 0.62, 620)
        )
        let origin = CGPoint(
            x: (reviewSize.width - cardSize.width) / 2,
            y: (reviewSize.height - cardSize.height) / 2
        )

        return CGRect(origin: origin, size: cardSize)
    }

    private func exponentialEaseIn(_ value: Double) -> Double {
        guard value > 0 else { return 0 }
        guard value < 1 else { return 1 }
        return pow(value, 2.35)
    }

    private func reboundScale(for growthPhase: Double) -> CGFloat {
        guard growthPhase > 0.78, growthPhase < 1 else { return 1 }

        let phase = (growthPhase - 0.78) / 0.22
        let primary = sin(phase * .pi)
        let settle = sin(phase * .pi * 2)
        return 1 + CGFloat(0.075 * primary - 0.022 * settle * (1 - phase))
    }

    private func spinReboundDegrees(for growthPhase: Double) -> Double {
        guard growthPhase > 0.78, growthPhase < 1 else { return 0 }

        let phase = (growthPhase - 0.78) / 0.22
        return 24 * sin(phase * .pi) - 8 * sin(phase * .pi * 2) * (1 - phase)
    }

    private func spinDegrees(elapsed: TimeInterval, growthPhase: Double) -> Double {
        let holdElapsed = min(elapsed, loadingHoldDuration)
        let holdDegrees = holdElapsed * baseSpinDegreesPerSecond
        guard growthPhase > 0 else { return holdDegrees }

        let activeLinearProgress = 0.26 * growthPhase
        let activeAcceleratingProgress = 0.74 * exponentialEaseIn(growthPhase)
        let activeProgress = min(activeLinearProgress + activeAcceleratingProgress, 1)
        let targetDegrees = holdDegrees + (finalSpinDegrees - holdDegrees) * activeProgress
        return targetDegrees + spinReboundDegrees(for: growthPhase)
    }

    private func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: Double) -> CGFloat {
        start + (end - start) * CGFloat(progress)
    }
}

private struct SplashBackground: View {
    var body: some View {
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
    let zDegrees: Double
    let cornerRadius: CGFloat

    private var remainingTilt: Double {
        max(1 - min(progress, 1), 0)
    }

    private var xDegrees: Double {
        remainingTilt * (7 * sin(time * 2.2 + 0.4) + 2 * sin(time * 0.86 + 1.8))
    }

    private var yDegrees: Double {
        remainingTilt * (32 * sin(time * 2.05 + 2.1) + 6 * sin(time * 2.8))
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.white)
            .rotation3DEffect(.degrees(xDegrees), axis: (x: 1, y: 0, z: 0), perspective: 0.82)
            .rotation3DEffect(.degrees(yDegrees), axis: (x: 0, y: 1, z: 0), perspective: 0.82)
            .rotationEffect(.degrees(zDegrees))
    }
}

#Preview {
    SplashScreenView(targetCardFrame: nil)
}

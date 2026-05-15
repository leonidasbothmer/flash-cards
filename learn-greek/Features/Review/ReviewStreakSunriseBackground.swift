import SwiftUI

struct StreakBreakAnimation: Equatable {
    let previousStreak: Int
    let token: UUID
}

struct ReviewStreakSunriseBackground: View {
    let correctStreak: Int
    let breakAnimation: StreakBreakAnimation?
    let translation: CGSize

    private var progress: CGFloat {
        min(max(CGFloat(correctStreak) / 20, 0), 1)
    }

    private var emberProgress: CGFloat {
        smoothStep(min(max((CGFloat(correctStreak) - 15) / 5, 0), 1))
    }

    private var redShift: CGFloat {
        smoothStep(min(max((CGFloat(correctStreak) - 14) / 6, 0), 1))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let wave = sin(time * (1.0 + 1.5 * emberProgress)) * 0.5 + 0.5
            let emberWave = sin(time * (1.8 + 2.4 * emberProgress)) * 0.5 + 0.5
            let activeWave = emberProgress * CGFloat(wave)
            let activeEmberWave = emberProgress * CGFloat(emberWave)

            ZStack {
                baseSky

                sunriseGlow(
                    progress: progress,
                    wave: activeWave,
                    emberWave: activeEmberWave
                )

                outOfFocusFlames(
                    time: time,
                    progress: emberProgress,
                    collapse: 0
                )

                if let breakAnimation {
                    collapsingFire(
                        event: breakAnimation,
                        time: time
                    )
                }

                swipeFeedbackOverlay
            }
        }
        .animation(.easeInOut(duration: 0.75), value: correctStreak)
        .animation(.easeOut(duration: 0.52), value: breakAnimation)
        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: translation)
        .ignoresSafeArea()
    }

    private var baseSky: some View {
        LinearGradient(
            colors: [
                Color(red: 0.82 - 0.08 * redShift, green: 0.86 - 0.18 * redShift, blue: 0.91 - 0.28 * redShift),
                Color(red: 0.92 + 0.03 * progress, green: 0.94 - 0.22 * redShift, blue: 0.96 - 0.34 * redShift),
                Color(red: 0.96 + 0.02 * progress, green: 0.96 - 0.24 * redShift, blue: 0.97 - 0.38 * redShift)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func sunriseGlow(progress: CGFloat, wave: CGFloat, emberWave: CGFloat) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let longestSide = max(size.width, size.height)
            let coreSize = longestSide * (0.55 + 1.45 * progress + 0.1 * wave)
            let fireSize = longestSide * (0.28 + 0.68 * emberProgress + 0.12 * emberWave)
            let rise = size.height * (0.3 * progress)
            let centerYOffset = size.height * 0.54 - rise

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.58 - 0.18 * redShift, blue: 0.22 - 0.12 * redShift).opacity(0.44 * progress),
                                Color(red: 1.0, green: 0.74 - 0.24 * redShift, blue: 0.38 - 0.20 * redShift).opacity(0.25 * progress),
                                Color(red: 0.98, green: 0.34 - 0.18 * redShift, blue: 0.22 - 0.14 * redShift).opacity(0.15 * progress),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: coreSize * 0.5
                        )
                    )
                    .frame(width: coreSize, height: coreSize)
                    .position(x: size.width * 0.5, y: size.height + centerYOffset)
                    .blur(radius: 10 + 18 * progress)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.14, blue: 0.04).opacity(0.42 * emberProgress),
                                Color(red: 1.0, green: 0.38 - 0.10 * redShift, blue: 0.04).opacity(0.24 * emberProgress),
                                Color(red: 0.78, green: 0.04, blue: 0.02).opacity(0.14 * redShift),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: fireSize * 0.5
                        )
                    )
                    .frame(width: fireSize, height: fireSize)
                    .position(
                        x: size.width * (0.5 + 0.035 * wave),
                        y: size.height + centerYOffset - size.height * 0.04 * emberProgress
                    )
                    .blur(radius: 18 + 10 * emberProgress)
                    .blendMode(.plusLighter)
            }
        }
    }

    private func collapsingFire(event: StreakBreakAnimation, time: TimeInterval) -> some View {
        let previousProgress = smoothStep(min(max((CGFloat(event.previousStreak) - 15) / 5, 0), 1))
        return outOfFocusFlames(time: time, progress: previousProgress, collapse: 1)
            .id(event.token)
            .transition(.identity)
    }

    private func outOfFocusFlames(time: TimeInterval, progress: CGFloat, collapse: CGFloat) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let longestSide = max(size.width, size.height)
            let pace = 0.65 + 1.6 * progress
            let extent = size.height * (0.04 + 0.18 * progress) * (1 - collapse)
            let baseY = size.height * (0.88 - 0.16 * progress + 0.12 * collapse)
            let targetX = size.width * 0.5
            let collapseScale = 1 - 0.72 * collapse
            let collapseOpacity = progress * (1 - 0.88 * collapse)

            ZStack {
                flameBlob(
                    color: Color(red: 1.0, green: 0.16, blue: 0.04),
                    opacity: 0.18 + 0.28 * redShift,
                    width: longestSide * (0.32 + 0.18 * progress) * collapseScale,
                    height: longestSide * (0.46 + 0.28 * progress) * collapseScale,
                    x: lerp(size.width * (0.34 + 0.04 * sin(time * pace)), targetX, collapse),
                    y: baseY - extent * CGFloat(sin(time * (pace * 0.9))),
                    blur: 34 + 16 * progress + 16 * collapse
                )

                flameBlob(
                    color: Color(red: 1.0, green: 0.46 - 0.12 * redShift, blue: 0.04),
                    opacity: 0.16 + 0.2 * progress,
                    width: longestSide * (0.28 + 0.16 * progress) * collapseScale,
                    height: longestSide * (0.38 + 0.24 * progress) * collapseScale,
                    x: lerp(size.width * (0.53 + 0.05 * sin(time * (pace * 1.2) + 1.4)), targetX, collapse),
                    y: baseY - extent * CGFloat(sin(time * (pace * 1.15) + 0.7)),
                    blur: 30 + 18 * progress + 16 * collapse
                )

                flameBlob(
                    color: Color(red: 0.82, green: 0.05, blue: 0.02),
                    opacity: 0.1 + 0.24 * redShift,
                    width: longestSide * (0.36 + 0.2 * progress) * collapseScale,
                    height: longestSide * (0.5 + 0.26 * progress) * collapseScale,
                    x: lerp(size.width * (0.68 + 0.035 * sin(time * (pace * 0.8) + 2.1)), targetX, collapse),
                    y: baseY - extent * CGFloat(sin(time * (pace * 1.35) + 1.9)),
                    blur: 40 + 18 * progress + 16 * collapse
                )
            }
            .opacity(collapseOpacity)
            .scaleEffect(0.92 + 0.12 * progress - 0.18 * collapse, anchor: .bottom)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }

    private func flameBlob(
        color: Color,
        opacity: CGFloat,
        width: CGFloat,
        height: CGFloat,
        x: CGFloat,
        y: CGFloat,
        blur: CGFloat
    ) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(opacity),
                        color.opacity(opacity * 0.45),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(width, height) * 0.5
                )
            )
            .frame(width: width, height: height)
            .position(x: x, y: y)
            .blur(radius: blur)
    }

    @ViewBuilder
    private var swipeFeedbackOverlay: some View {
        if translation.width > 20 {
            let strength = min(translation.width / 180, 1)
            Color(red: 0.46, green: 0.86, blue: 0.46)
                .opacity(0.22 * strength)
        } else if translation.width < -20 {
            let strength = min(abs(translation.width) / 180, 1)
            Color(red: 0.96, green: 0.36, blue: 0.42)
                .opacity(0.24 * strength)
        } else {
            Color.clear
        }
    }

    private func smoothStep(_ value: CGFloat) -> CGFloat {
        value * value * (3 - 2 * value)
    }

    private func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }
}

#Preview {
    ReviewStreakSunriseBackground(
        correctStreak: 15,
        breakAnimation: nil,
        translation: .zero
    )
}

import SwiftUI

struct CardMotionModifier: ViewModifier {
    let entryScale: CGFloat
    let editTransitionScale: CGFloat
    let pressShrinkScale: CGFloat
    let pressShrinkAnchor: UnitPoint
    let dragRollDegrees: Double
    let cancelShakeDegrees: Double
    let pressTiltXDegrees: Double
    let pressTiltYDegrees: Double
    let pressTiltAnchor: UnitPoint
    let flipRotation: Double
    let flipAxis: (x: CGFloat, y: CGFloat, z: CGFloat)
    let translation: CGSize
    let entryOffset: CGSize
    let isEditing: Bool

    func body(content: Content) -> some View {
        let activeEntryScale = isEditing ? 1 : entryScale
        let activePressShrinkScale = isEditing ? 1 : pressShrinkScale
        let activeDragRollDegrees = isEditing ? 0 : dragRollDegrees
        let activePressTiltXDegrees = isEditing ? 0 : pressTiltXDegrees
        let activePressTiltYDegrees = isEditing ? 0 : pressTiltYDegrees
        let activeFlipRotation = isEditing ? 0 : flipRotation
        let activeTranslation = isEditing ? .zero : translation
        let activeEntryOffset = isEditing ? .zero : entryOffset

        content
            .scaleEffect(activeEntryScale, anchor: .center)
            .scaleEffect(editTransitionScale, anchor: .center)
            .scaleEffect(activePressShrinkScale, anchor: pressShrinkAnchor)
            .rotationEffect(.degrees(activeDragRollDegrees + cancelShakeDegrees))
            .rotation3DEffect(
                .degrees(activePressTiltXDegrees),
                axis: (x: 1, y: 0, z: 0),
                anchor: pressTiltAnchor,
                perspective: 0.9
            )
            .rotation3DEffect(
                .degrees(activePressTiltYDegrees),
                axis: (x: 0, y: 1, z: 0),
                anchor: pressTiltAnchor,
                perspective: 0.9
            )
            .rotation3DEffect(
                .degrees(activeFlipRotation),
                axis: flipAxis,
                perspective: 0.9
            )
            .offset(
                x: activeTranslation.width + activeEntryOffset.width,
                y: activeTranslation.height * 0.2 + activeEntryOffset.height
            )
    }
}

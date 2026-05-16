import UIKit

enum HapticFeedback {
    static func contextMenuOpened() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 0.85)
    }
}

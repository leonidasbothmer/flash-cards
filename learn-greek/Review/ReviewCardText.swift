import SwiftUI
import UIKit

struct BackFaceTilt: ViewModifier {
    func body(content: Content) -> some View {
        content.rotation3DEffect(
            .degrees(180),
            axis: (x: 0, y: 1, z: 0)
        )
    }
}

struct AdaptiveCardText: View {
    let text: String

    private let maximumFontSize: CGFloat = 42
    private let minimumFontSize: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            let limitSize = CGSize(
                width: proxy.size.width * 0.75,
                height: proxy.size.height * 0.75
            )
            let fontSize = fittingFontSize(for: text, in: limitSize)

            Text(text)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.black)
                .frame(width: limitSize.width, height: limitSize.height, alignment: .center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func fittingFontSize(for text: String, in size: CGSize) -> CGFloat {
        let measuredText = text.isEmpty ? " " : text
        var low = minimumFontSize
        var high = maximumFontSize

        for _ in 0..<8 {
            let mid = (low + high) / 2
            if measuredSize(for: measuredText, fontSize: mid, constrainedWidth: size.width).fits(in: size) {
                low = mid
            } else {
                high = mid
            }
        }

        return low
    }

    private func measuredSize(for text: String, fontSize: CGFloat, constrainedWidth: CGFloat) -> CGSize {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        let rect = (text as NSString).boundingRect(
            with: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .paragraphStyle: paragraph
            ],
            context: nil
        )

        return CGSize(width: ceil(rect.width), height: ceil(rect.height))
    }
}

private extension CGSize {
    func fits(in limit: CGSize) -> Bool {
        width <= limit.width && height <= limit.height
    }
}

import SwiftUI

extension Font {
    static func cormorantGaramond(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .light: fontName = "CormorantGaramond-Light"
        case .medium: fontName = "CormorantGaramond-Medium"
        case .semibold: fontName = "CormorantGaramond-SemiBold"
        case .bold: fontName = "CormorantGaramond-Bold"
        default: fontName = "CormorantGaramond-Regular"
        }
        return .custom(fontName, size: size)
    }
}

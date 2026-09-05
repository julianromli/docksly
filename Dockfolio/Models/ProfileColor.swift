import SwiftUI

/// Named color swatch for a dock profile. Stored as sRGB hex without a leading `#`.
struct ProfileColor: Codable, Equatable, Hashable, Identifiable {
    var hex: String

    var id: String { hex.uppercased() }

    static let palette: [ProfileColor] = [
        ProfileColor(hex: "0A84FF"),
        ProfileColor(hex: "FF9F0A"),
        ProfileColor(hex: "BF5AF2"),
        ProfileColor(hex: "32D74B"),
        ProfileColor(hex: "FF453A"),
        ProfileColor(hex: "FF375F"),
        ProfileColor(hex: "64D2FF"),
        ProfileColor(hex: "8E8E93")
    ]

    static let `default` = palette[0]

    var color: Color {
        Color(hex: hex)
    }

    var displayName: String {
        switch hex.uppercased() {
        case "0A84FF": return "Blue"
        case "FF9F0A": return "Orange"
        case "BF5AF2": return "Purple"
        case "32D74B": return "Green"
        case "FF453A": return "Red"
        case "FF375F": return "Pink"
        case "64D2FF": return "Teal"
        case "8E8E93": return "Gray"
        default: return "#\(hex.uppercased())"
        }
    }

    /// WCAG relative luminance of the swatch fill.
    var relativeLuminance: Double {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        guard cleaned.count == 6 else { return 0.23 }
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    /// Light fills need a dark check so the mark stays above 3:1.
    var prefersDarkMark: Bool {
        relativeLuminance > 0.40
    }

    var markColor: Color {
        prefersDarkMark ? Color(hex: "1A1A1A") : Color.white
    }

}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        switch cleaned.count {
        case 6:
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
        default:
            r = 0.23
            g = 0.51
            b = 0.96
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

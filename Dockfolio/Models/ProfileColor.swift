import SwiftUI

/// Named color swatch for a dock profile. Stored as sRGB hex without a leading `#`.
struct ProfileColor: Codable, Equatable, Hashable, Identifiable {
    var hex: String

    var id: String { hex.uppercased() }

    static let palette: [ProfileColor] = [
        ProfileColor(hex: "3B82F6"),
        ProfileColor(hex: "F59E0B"),
        ProfileColor(hex: "8B5CF6"),
        ProfileColor(hex: "10B981"),
        ProfileColor(hex: "EF4444"),
        ProfileColor(hex: "EC4899"),
        ProfileColor(hex: "06B6D4"),
        ProfileColor(hex: "64748B")
    ]

    static let `default` = palette[0]

    var color: Color {
        Color(hex: hex)
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

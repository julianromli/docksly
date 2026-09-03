import SwiftUI

struct ColorDot: View {
    var color: Color
    var diameter: CGFloat = 10

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .overlay {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

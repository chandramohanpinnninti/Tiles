import SwiftUI
import UIKit

/// Renders a tile's icon using the hybrid strategy: show the SF Symbol when one
/// genuinely fits, otherwise fall back to the emoji the AI provided.
struct TileGlyph: View {
    let icon: String
    let emoji: String
    var color: Color = .primary
    var font: Font = .title3

    /// Generic shapes the model reaches for when nothing specific fits. We treat
    /// these as "no real symbol" so the emoji wins instead of a meaningless dot.
    private static let placeholders: Set<String> = [
        "circle", "circle.fill", "square", "square.fill", "app", "app.fill"
    ]

    /// The SF Symbol to use, or nil when there's no meaningful one. A name only
    /// counts if it's non-empty, not a placeholder, and actually ships on this OS
    /// (UIImage(systemName:) is the source of truth — it's nil for hallucinations).
    private var resolvedSymbol: String? {
        let name = icon.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty,
              !Self.placeholders.contains(name.lowercased()),
              UIImage(systemName: name) != nil else { return nil }
        return name
    }

    var body: some View {
        if let resolvedSymbol {
            Image(systemName: resolvedSymbol)
                .font(font)
                .foregroundStyle(color)
        } else if !emoji.isEmpty {
            Text(emoji)
                .font(font)
        } else {
            // Legacy tiles with neither a real symbol nor an emoji.
            Image(systemName: "circle.fill")
                .font(font)
                .foregroundStyle(color)
        }
    }
}

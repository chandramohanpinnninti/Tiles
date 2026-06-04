import SwiftUI

struct TileCardView: View {
    let tile: Tile
    let onQuickLog: () -> Void

    private var tileColor: Color { Color(hex: tile.colorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: tile.icon)
                    .font(.title3)
                    .foregroundStyle(tileColor)
                Spacer()
                Button(action: onQuickLog) {
                    Image(systemName: tile.type == .counter ? "plus.circle.fill" : "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(tileColor)
                }
                .buttonStyle(.plain)
            }

            Text(tile.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(tile.displayValue.formatted())
                    .font(.title2.bold())
                Text(tile.unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let progress = tile.goalProgress {
                ProgressView(value: progress)
                    .tint(tileColor)
                    .scaleEffect(x: 1, y: 1.5)
            } else {
                Spacer().frame(height: 4)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(tileColor.opacity(0.2), lineWidth: 1)
        )
    }
}

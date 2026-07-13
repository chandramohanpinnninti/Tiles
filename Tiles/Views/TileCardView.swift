import SwiftUI

struct TileCardView: View {
    let tile: Tracker
    var isEditing: Bool = false
    var onDelete: (() -> Void)? = nil
    let onQuickLog: () -> Void

    @State private var jiggle = false

    private var tileColor: Color { Color(hex: tile.colorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                TileGlyph(icon: tile.icon, emoji: tile.emoji, color: tileColor, font: .system(size: 16, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(tileColor.opacity(0.1), in: Circle())

                Spacer()

                if !isEditing {
                    Button(action: onQuickLog) {
                        Image(systemName: tile.type == .measurement ? "pencil" : "plus")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(tileColor, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("tile.action.quickLog"))
                }
            }

            Spacer(minLength: 18)

            Text(tile.name)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            valueContent

            if let progress = tile.goalProgress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(tileColor)
                    .scaleEffect(x: 1, y: 1.4, anchor: .center)
                    .padding(.top, 10)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .rotationEffect(.degrees(isEditing ? (jiggle ? 1.4 : -1.4) : 0))
        .overlay(alignment: .topTrailing) {
            if isEditing {
                deleteBadge
                    .offset(x: 8, y: -8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onChange(of: isEditing) { _, editing in updateJiggle(editing) }
        .onAppear { updateJiggle(isEditing) }
    }

    @ViewBuilder
    private var valueContent: some View {
        if tile.type == .sessionLog {
            sessionLogValue
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(tile.displayValue.formatted())
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if !supplementalValueText.isEmpty {
                    Text(supplementalValueText)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
    }

    private var sessionLogValue: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(lastLogText)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(sessionDetailText)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.top, 2)
    }

    private var supplementalValueText: String {
        if let targetValue = tile.targetValue, targetValue > 0 {
            return "/ \(targetValue.formatted())"
        }

        let unit = tile.unit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !unit.isEmpty else { return "" }
        guard unit.normalizedUnitText != tile.name.normalizedUnitText else { return "" }
        return unit
    }

    private var lastLogText: String {
        guard let loggedAt = tile.recentValues.first?.entry?.loggedAt else { return "Not yet" }
        let weekday = loggedAt.formatted(.dateTime.weekday(.abbreviated))
        return "Last: \(weekday)"
    }

    private var sessionDetailText: String {
        guard let latest = tile.recentValues.first else { return "-" }
        let formattedValue = latest.value.formatted()
        return tile.unit.isEmpty ? formattedValue : "\(formattedValue) \(tile.unit)"
    }

    private var deleteBadge: some View {
        Button {
            onDelete?()
        } label: {
            Image(systemName: "minus")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.red, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    /// Drives the home-screen-style wobble while in edit mode.
    private func updateJiggle(_ editing: Bool) {
        if editing {
            withAnimation(.easeInOut(duration: 0.13).repeatForever(autoreverses: true)) {
                jiggle = true
            }
        } else {
            withAnimation(.default) { jiggle = false }
        }
    }
}

private extension String {
    var normalizedUnitText: String {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.count > 1, normalized.hasSuffix("s") {
            return String(normalized.dropLast())
        }
        return normalized
    }
}

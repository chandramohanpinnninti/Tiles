import SwiftUI

struct DebriefPreview: Identifiable {
    let id = UUID()
    let updates: [UpdateItem]
    let unmatched: [String]

    struct UpdateItem: Identifiable {
        let id = UUID()
        let tileId: String
        let tileName: String
        let tileIcon: String
        let tileColorHex: String
        let value: Double
        let unit: String
        let note: String?
    }

    init(result: ClaudeService.DebriefResult, tiles: [Tile]) {
        self.updates = result.updates.compactMap { update in
            guard let tile = tiles.first(where: { $0.id.uuidString == update.tileId }) else { return nil }
            return UpdateItem(
                tileId: update.tileId,
                tileName: tile.name,
                tileIcon: tile.icon,
                tileColorHex: tile.colorHex,
                value: update.value,
                unit: tile.unit,
                note: update.note
            )
        }
        self.unmatched = result.unmatched
    }
}

struct DebriefPreviewSheet: View {
    let preview: DebriefPreview
    let onDone: (Bool) -> Void

    var body: some View {
        NavigationStack {
            List {
                if !preview.updates.isEmpty {
                    Section("debrief.section.logging") {
                        ForEach(preview.updates) { item in
                            HStack(spacing: 12) {
                                Image(systemName: item.tileIcon)
                                    .foregroundStyle(Color(hex: item.tileColorHex))
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.tileName)
                                        .font(.subheadline.weight(.medium))
                                    if let note = item.note {
                                        Text(note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(item.value.formatted()) \(item.unit)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !preview.unmatched.isEmpty {
                    Section("debrief.section.unmatched") {
                        ForEach(preview.unmatched, id: \.self) { item in
                            Label(item, systemImage: "questionmark.circle")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("debrief.nav.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("debrief.action.cancel") { onDone(false) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("debrief.action.confirm") { onDone(true) }
                        .bold()
                        .disabled(preview.updates.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

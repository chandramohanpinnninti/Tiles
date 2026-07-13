import SwiftUI

struct DebriefPreview: Identifiable {
    let id = UUID()
    let updates: [UpdateItem]
    let exerciseSets: [DebriefExerciseSet]
    let mealItems: [DebriefMealItem]
    let unmatched: [String]

    struct UpdateItem: Identifiable {
        let id = UUID()
        let trackerId: String
        let tileName: String
        let tileIcon: String
        let tileEmoji: String
        let tileColorHex: String
        let value: Double
        let unit: String
        let note: String?
    }

    init(result: DebriefResult, trackers: [Tracker]) {
        self.updates = result.updates.compactMap { update in
            guard let tracker = trackers.first(where: { $0.id.uuidString == update.trackerId }) else { return nil }
            return UpdateItem(
                trackerId: update.trackerId,
                tileName: tracker.name,
                tileIcon: tracker.icon,
                tileEmoji: tracker.emoji,
                tileColorHex: tracker.colorHex,
                value: update.value,
                unit: tracker.unit,
                note: update.note
            )
        }
        self.exerciseSets = result.exerciseSets
        self.mealItems = result.mealItems
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
                                TileGlyph(icon: item.tileIcon, emoji: item.tileEmoji, color: Color(hex: item.tileColorHex))
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

                if !preview.exerciseSets.isEmpty {
                    Section("Workout") {
                        ForEach(preview.exerciseSets, id: \.order) { set in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(set.exerciseName)
                                    .font(.subheadline.weight(.medium))
                                Text(exerciseSummary(set))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !preview.mealItems.isEmpty {
                    Section("Meal") {
                        ForEach(preview.mealItems, id: \.order) { item in
                            HStack {
                                Text(item.foodName)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                if let kcal = item.kcal {
                                    Text("~\(kcal.formatted()) kcal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
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
                        .disabled(preview.updates.isEmpty && preview.exerciseSets.isEmpty && preview.mealItems.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func exerciseSummary(_ set: DebriefExerciseSet) -> String {
        let load = set.weightKg.map { "\($0.formatted()) kg " } ?? ""
        if let reps = set.reps {
            return "\(load)\(set.sets)x\(reps)"
        }
        if let durationSec = set.durationSec {
            return "\(load)\(set.sets)x\(durationSec)s"
        }
        return "\(load)\(set.sets) sets"
    }
}

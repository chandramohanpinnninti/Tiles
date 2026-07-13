import SwiftData
import Foundation

@Observable
@MainActor
final class StorageService {
    let container: ModelContainer

    private var context: ModelContext { container.mainContext }

    init() {
        let schema = Schema([
            Tracker.self,
            Entry.self,
            EntryTrackerValue.self,
            ExerciseSet.self,
            MealItem.self
        ])
        // Prefer CloudKit-backed store; fall back to local if unavailable
        // (no iCloud account, missing entitlement, simulator, etc.)
        if let ckContainer = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        ) {
            container = ckContainer
        } else {
            container = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema)
            )
        }
    }

    // MARK: - Trackers

    func insertTile(from spec: TileSpec) {
        let tracker = Tracker(
            name: spec.name,
            type: TrackerType(rawValue: spec.type) ?? .counter,
            unit: spec.unit,
            period: spec.period.flatMap { TrackerPeriod(rawValue: $0) } ?? defaultPeriod(for: spec.type),
            targetValue: spec.goal,
            targetDirection: spec.targetDirection.flatMap { TargetDirection(rawValue: $0) },
            group: spec.group ?? defaultGroup(for: spec.category),
            category: spec.category.flatMap { TrackerCategory(rawValue: $0) } ?? .custom,
            sortOrder: nextSortOrder(),
            icon: spec.icon,
            emoji: spec.emoji,
            colorHex: spec.color
        )
        context.insert(tracker)
    }

    func deleteTile(_ tracker: Tracker) {
        context.delete(tracker)
    }

    // MARK: - Entries

    func addEntry(to tracker: Tracker, value: Double, note: String?, loggedAt: Date = Date()) {
        let entry = Entry(loggedAt: loggedAt, source: .manual, notes: note)
        context.insert(entry)
        addValue(to: entry, tracker: tracker, value: value)
    }

    func addWorkoutEntry(to tracker: Tracker, exercises: [ExerciseInput], note: String?, loggedAt: Date = Date()) {
        let volume = exercises.reduce(0.0) { $0 + $1.volume }
        let entry = Entry(loggedAt: loggedAt, source: .manual, notes: note)
        context.insert(entry)
        var order = 0
        for exercise in exercises {
            for set in exercise.sets where set.isValid {
                context.insert(ExerciseSet(
                    entry: entry,
                    exerciseName: exercise.name,
                    weightKg: set.parsedWeight,
                    sets: 1,
                    reps: set.parsedReps,
                    order: order
                ))
                order += 1
            }
        }
        addValue(to: entry, tracker: tracker, value: volume)
    }

    func applyDebrief(_ result: DebriefResult, rawText: String, trackers: [Tracker], source: EntrySource = .debrief) {
        guard !result.updates.isEmpty || !result.exerciseSets.isEmpty || !result.mealItems.isEmpty else { return }

        let entry = Entry(loggedAt: Date(), source: source, rawText: rawText, notes: result.note)
        context.insert(entry)

        for update in result.updates {
            guard let tracker = trackers.first(where: { $0.id.uuidString == update.trackerId }) else { continue }
            addValue(to: entry, tracker: tracker, value: update.value)
        }

        for exerciseSet in result.exerciseSets.sorted(by: { $0.order < $1.order }) {
            context.insert(ExerciseSet(
                entry: entry,
                exerciseName: exerciseSet.exerciseName,
                weightKg: exerciseSet.weightKg,
                sets: exerciseSet.sets,
                reps: exerciseSet.reps,
                durationSec: exerciseSet.durationSec,
                order: exerciseSet.order
            ))
        }

        for mealItem in result.mealItems.sorted(by: { $0.order < $1.order }) {
            context.insert(MealItem(
                entry: entry,
                foodName: mealItem.foodName,
                quantityG: mealItem.quantityG,
                kcal: mealItem.kcal,
                proteinG: mealItem.proteinG,
                carbsG: mealItem.carbsG,
                fatG: mealItem.fatG,
                order: mealItem.order
            ))
        }
    }

    func deleteEntry(_ entry: Entry) {
        context.delete(entry)
    }

    private func addValue(to entry: Entry, tracker: Tracker, value: Double) {
        tracker.isPlaceholder = false
        context.insert(EntryTrackerValue(entry: entry, tracker: tracker, value: value, unit: tracker.unit))
    }

    private func nextSortOrder() -> Int {
        let descriptor = FetchDescriptor<Tracker>()
        let trackers = (try? context.fetch(descriptor)) ?? []
        return (trackers.map(\.sortOrder).max() ?? -1) + 1
    }

    private func defaultPeriod(for type: String) -> TrackerPeriod {
        switch TrackerType(rawValue: type) ?? .counter {
        case .counter, .sessionLog:
            return .daily
        case .measurement:
            return .never
        }
    }

    private func defaultGroup(for category: String?) -> String {
        switch category.flatMap(TrackerCategory.init(rawValue:)) {
        case .nutrition:
            return "Food"
        case .fitness:
            return "Workouts"
        default:
            return "My Tiles"
        }
    }
}

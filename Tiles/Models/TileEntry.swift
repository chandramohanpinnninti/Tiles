import SwiftData
import Foundation

enum EntrySource: String, Codable, CaseIterable {
    case manual
    case chat
    case debrief
    case `import`
}

@Model
final class Entry {
    var id: UUID = UUID()
    var loggedAt: Date = Date()
    var source: EntrySource = EntrySource.manual
    var rawText: String?
    var notes: String?
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \EntryTrackerValue.entry) var trackerValues: [EntryTrackerValue]? = []
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.entry) var exerciseSets: [ExerciseSet]? = []
    @Relationship(deleteRule: .cascade, inverse: \MealItem.entry) var mealItems: [MealItem]? = []

    init(
        loggedAt: Date = Date(),
        source: EntrySource,
        rawText: String? = nil,
        notes: String? = nil
    ) {
        self.loggedAt = loggedAt
        self.source = source
        self.rawText = rawText
        self.notes = notes
    }
}

@Model
final class EntryTrackerValue {
    var id: UUID = UUID()
    var value: Double = 0
    var unit: String = ""
    var entry: Entry?
    var tracker: Tracker?

    init(entry: Entry, tracker: Tracker, value: Double, unit: String) {
        self.entry = entry
        self.tracker = tracker
        self.value = value
        self.unit = unit
    }
}

@Model
final class ExerciseSet {
    var id: UUID = UUID()
    var exerciseName: String = ""
    var weightKg: Double?
    var sets: Int = 0
    var reps: Int?
    var durationSec: Int?
    var order: Int = 0
    var entry: Entry?

    init(
        entry: Entry,
        exerciseName: String,
        weightKg: Double? = nil,
        sets: Int,
        reps: Int? = nil,
        durationSec: Int? = nil,
        order: Int
    ) {
        self.entry = entry
        self.exerciseName = exerciseName
        self.weightKg = weightKg
        self.sets = sets
        self.reps = reps
        self.durationSec = durationSec
        self.order = order
    }
}

@Model
final class MealItem {
    var id: UUID = UUID()
    var foodName: String = ""
    var quantityG: Double?
    var kcal: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var order: Int = 0
    var entry: Entry?

    init(
        entry: Entry,
        foodName: String,
        quantityG: Double? = nil,
        kcal: Double? = nil,
        proteinG: Double? = nil,
        carbsG: Double? = nil,
        fatG: Double? = nil,
        order: Int
    ) {
        self.entry = entry
        self.foodName = foodName
        self.quantityG = quantityG
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.order = order
    }
}

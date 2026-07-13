import FoundationModels
import Foundation

// MARK: - Shared types (used by both ClaudeService and AppleAIService)

@Generable
struct TileSpec: Codable {
    @Guide(description: "Short display name, e.g. Water, Sleep, Weight")
    var name: String
    @Guide(description: "counter, measurement, or session_log")
    var type: String
    @Guide(description: "Unit label, e.g. glasses, hours, kg, kcal, session")
    var unit: String
    @Guide(description: "daily, weekly, monthly, yearly, or never")
    var period: String?
    @Guide(description: "Numeric goal target, or nil")
    var goal: Double?
    @Guide(description: "floor when higher is better, ceiling when lower is better, or nil")
    var targetDirection: String?
    @Guide(description: "Display group, e.g. My Tiles, Food, Workouts")
    var group: String?
    @Guide(description: "hydration, nutrition, fitness, body, sleep, mood, habits, substance, finance, health, or custom")
    var category: String?
    @Guide(description: "A well-known SF Symbol name ONLY if one clearly fits the topic. If unsure or none fits, use an empty string.")
    var icon: String
    @Guide(description: "A single emoji representing the topic. Always provide one.")
    var emoji: String
    @Guide(description: "Tasteful hex color, e.g. #4A90E2")
    var color: String
}

@Generable
struct DebriefUpdate: Codable {
    @Guide(description: "UUID string of the matching tracker")
    var trackerId: String
    @Guide(description: "Numeric contribution for this tracker")
    var value: Double
    @Guide(description: "Short optional note describing this tracker impact")
    var note: String?
}

@Generable
struct DebriefExerciseSet: Codable {
    @Guide(description: "Exercise name, e.g. Bench Press")
    var exerciseName: String
    @Guide(description: "Weight in kilograms, nil for bodyweight or unknown")
    var weightKg: Double?
    @Guide(description: "Number of sets")
    var sets: Int
    @Guide(description: "Reps per set, nil for time-based exercises")
    var reps: Int?
    @Guide(description: "Duration in seconds, nil for rep-based exercises")
    var durationSec: Int?
    @Guide(description: "Display order within the workout session")
    var order: Int
}

@Generable
struct DebriefMealItem: Codable {
    @Guide(description: "Food item name")
    var foodName: String
    @Guide(description: "Estimated quantity in grams, nil if unknown")
    var quantityG: Double?
    @Guide(description: "Estimated calories, nil if unknown")
    var kcal: Double?
    @Guide(description: "Estimated protein grams, nil if unknown")
    var proteinG: Double?
    @Guide(description: "Estimated carbohydrate grams, nil if unknown")
    var carbsG: Double?
    @Guide(description: "Estimated fat grams, nil if unknown")
    var fatG: Double?
    @Guide(description: "Display order within the meal")
    var order: Int
}

@Generable
struct DebriefResult: Codable {
    @Guide(description: "Tracker values extracted from the free-text. Include one row per impacted tracker.")
    var updates: [DebriefUpdate]
    @Guide(description: "Workout exercise detail. Only include when the text describes a workout/session.")
    var exerciseSets: [DebriefExerciseSet]
    @Guide(description: "Meal item detail. Only include when the text describes food/nutrition.")
    var mealItems: [DebriefMealItem]
    @Guide(description: "Things mentioned that did not match any active tracker")
    var unmatched: [String]
    @Guide(description: "Short note for the whole entry, or nil")
    var note: String?
}

// MARK: - Protocol

@MainActor
protocol TileAIService {
    func buildTile(from prompt: String) async throws -> TileSpec
    func parseDebrief(text: String, trackers: [Tracker]) async throws -> DebriefResult
    func answer(question: String, trackers: [Tracker]) async throws -> String
    func classifyIntent(_ text: String) async throws -> String // returns "build", "log", or "ask"
}

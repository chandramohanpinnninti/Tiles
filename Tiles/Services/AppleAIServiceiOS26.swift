// iOS 26 / Xcode 26 version - uses SystemLanguageModel (on-device).
// Active by default. Switch to AppleAIService once on Xcode 27.
#if !IOS27

import FoundationModels
import Foundation

struct AppleAIService: TileAIService {
    static let shared = AppleAIService()

    func buildTile(from prompt: String) async throws -> TileSpec {
        let session = LanguageModelSession(instructions: """
        You are a tracker builder for a personal tracking app. Users track any personal habit or metric.
        - type: "counter", "measurement", or "session_log".
        - period: "daily", "weekly", "monthly", "yearly", or "never". Use "never" for measurements unless stated.
        - targetDirection: "floor" for higher-is-better, "ceiling" for lower-is-better, nil with no target.
        - category: hydration, nutrition, fitness, body, sleep, mood, habits, substance, finance, health, or custom.
        - group: "Food" for nutrition, "Workouts" for fitness sessions, otherwise "My Tiles" unless named.
        - icon: a well-known SF Symbol name only if one clearly represents the topic. If unsure, return an empty string.
        - emoji: a single emoji representing the topic.
        - color: tasteful hex color.
        """)
        return try await session.respond(to: prompt, generating: TileSpec.self).content
    }

    func parseDebrief(text: String, trackers: [Tracker]) async throws -> DebriefResult {
        let trackerList = trackers
            .map { "\($0.id.uuidString): \($0.name) (\($0.type.rawValue), unit: \($0.unit), category: \($0.category.rawValue), group: \($0.group))" }
            .joined(separator: "\n")
        let session = LanguageModelSession(instructions: """
        You are a debrief parser for a personal tracking app. Extract one structured entry from free text.

        Active trackers:
        \(trackerList)

        Rules:
        - updates: one row per impacted tracker id.
        - counter/session_log trackers add contributions; measurement trackers record the measured value.
        - session_log workout text should include exerciseSets.
        - nutrition text should update matching macro/calorie trackers and include mealItems.
        - Put unmatched mentions in unmatched. Empty arrays when not relevant.
        """)
        return try await session.respond(to: text, generating: DebriefResult.self).content
    }

    func answer(question: String, trackers: [Tracker]) async throws -> String {
        let dataSummary = trackers.map { tracker in
            let recent = tracker.recentValues.prefix(30)
                .map { value in
                    let loggedAt = value.entry?.loggedAt.formatted(date: .abbreviated, time: .shortened) ?? "unknown date"
                    return "  \(loggedAt): \(value.value) \(value.unit)"
                }
                .joined(separator: "\n")
            return "\(tracker.name) (\(tracker.type.rawValue), \(tracker.unit)):\n\(recent.isEmpty ? "  no entries" : recent)"
        }.joined(separator: "\n\n")

        let session = LanguageModelSession(instructions: """
        You are a personal data analyst for a tracking app. Answer concisely and insightfully in 2-3 sentences.

        User data:
        \(dataSummary.isEmpty ? "No data recorded yet." : dataSummary)
        """)
        return try await session.respond(to: question).content
    }

    func classifyIntent(_ text: String) async throws -> String {
        let session = LanguageModelSession(instructions: """
        You are an intent classifier for a personal tracking app. Respond with exactly one word:
        - build   (user wants to create a new tracking tile)
        - log     (user is reporting what happened)
        - ask     (user is asking a question about their data)
        """)
        return try await session.respond(to: text).content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

#endif

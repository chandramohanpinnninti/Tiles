import Foundation

struct ClaudeService: TileAIService {
    static let shared = ClaudeService()

    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    // MARK: - TileAIService

    func buildTile(from prompt: String) async throws -> TileSpec {
        let system = """
        You are a tracker builder for a personal tracking app. Given a description of what to track, respond with ONLY a JSON object - no markdown, no extra text.

        {
          "name": "Water",
          "type": "counter",
          "unit": "glasses",
          "period": "daily",
          "goal": 8,
          "targetDirection": "floor",
          "group": "My Tiles",
          "category": "hydration",
          "icon": "drop.fill",
          "emoji": "💧",
          "color": "#4A90E2"
        }

        Rules:
        - type: "counter" for accumulating values, "measurement" for point-in-time snapshots, "session_log" for workout/session tiles.
        - period: "daily", "weekly", "monthly", "yearly", or "never". Use "never" for measurements unless the user says otherwise.
        - targetDirection: "floor" when higher is better, "ceiling" when lower is better, null when there is no target.
        - category: hydration, nutrition, fitness, body, sleep, mood, habits, substance, finance, health, or custom.
        - group: use "Food" for nutrition, "Workouts" for fitness session logs, otherwise "My Tiles" unless the user names a group.
        - unit: for session_log strength/weight training trackers (e.g. push day, chest day, deadlifts), use "kg" for metric or "lb" for imperial — this represents total volume lifted. For other session_log trackers (yoga, running, meditation) use natural units like "min", "km", or "sessions".
        - icon: a well-known SF Symbol name only if one clearly represents the topic. If unsure, return "".
        - emoji: a single emoji representing the topic.
        - color: tasteful hex color.
        """
        let text = try await send(system: system, user: prompt, model: Config.fastModel)
        return try decode(TileSpec.self, from: text)
    }

    func parseDebrief(text: String, trackers: [Tracker]) async throws -> DebriefResult {
        let trackerList = trackers.map {
            #"{"id":"\#($0.id.uuidString)","name":"\#($0.name)","type":"\#($0.type.rawValue)","unit":"\#($0.unit)","category":"\#($0.category.rawValue)","group":"\#($0.group)"}"#
        }.joined(separator: ",")

        let system = """
        You are a debrief parser for a personal tracking app. Respond with ONLY a JSON object - no markdown, no extra text.

        Return this shape exactly:
        {
          "updates": [{"trackerId": "uuid-here", "value": 6, "note": "drank 6 glasses"}],
          "exerciseSets": [{"exerciseName": "Bench Press", "weightKg": 80, "sets": 3, "reps": 8, "durationSec": null, "order": 1}],
          "mealItems": [{"foodName": "chicken breast", "quantityG": null, "kcal": 320, "proteinG": 42, "carbsG": 0, "fatG": 4, "order": 1}],
          "unmatched": [],
          "note": "optional entry-level note or null"
        }

        Active trackers: [\(trackerList)]

        Rules:
        - Create one update per impacted tracker using the tracker id exactly.
        - For counter trackers, value is the contribution to add.
        - For measurement trackers, value is the measured/latest value.
        - For session_log trackers, add value 1 when that workout/session happened, and include exerciseSets when exercises are described.
        - If a general workout counter exists along with a specific session_log tracker, update both when appropriate.
        - For nutrition/food text, update matching nutrition trackers such as calories, protein, carbs, or fat with meal totals, and include mealItems as the food breakdown.
        - Estimate nutrition values when reasonable from free text. Leave nullable fields null when unknown.
        - Put mentioned items with no matching tracker in unmatched.
        - Arrays must be empty when not relevant.
        """
        let response = try await send(system: system, user: text, model: Config.fastModel)
        return try decode(DebriefResult.self, from: response)
    }

    func answer(question: String, trackers: [Tracker]) async throws -> String {
        let dataSummary = trackers.map { tracker in
            let recent = tracker.recentValues.prefix(30).map { value in
                let loggedAt = value.entry?.loggedAt.formatted(date: .abbreviated, time: .shortened) ?? "unknown date"
                return "  \(loggedAt): \(value.value) \(value.unit)"
            }.joined(separator: "\n")
            return "**\(tracker.name)** (\(tracker.type.rawValue), unit: \(tracker.unit)):\n\(recent.isEmpty ? "  no entries" : recent)"
        }.joined(separator: "\n\n")

        let system = """
        You are a personal data analyst for a tracking app. Answer concisely and insightfully in 2-3 sentences.

        User data:
        \(dataSummary.isEmpty ? "No data recorded yet." : dataSummary)
        """
        return try await send(system: system, user: question, model: Config.smartModel)
    }

    func classifyIntent(_ text: String) async throws -> String {
        let system = """
        You are an intent classifier for a personal tracking app. Respond with ONLY one word:
        - build   (user wants to create a new tracking tile)
        - log     (user is reporting what happened)
        - ask     (user is asking a question about their data)
        Respond with exactly one word. No punctuation.
        """
        return try await send(system: system, user: text, model: Config.fastModel)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    // MARK: - Core HTTP

    private func send(system: String, user: String, model: String) async throws -> String {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1600,
            "system": system,
            "messages": [["role": "user", "content": user]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeError.invalidResponse }
        guard http.statusCode == 200 else { throw ClaudeError.httpError(http.statusCode) }

        let decoded = try JSONDecoder().decode(MessageResponse.self, from: data)
        return decoded.content.first?.text ?? ""
    }

    private func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        let cleaned = text
            .replacingOccurrences(of: #"^```[a-z]*\n?"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\n?```$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else { throw ClaudeError.invalidResponse }
        return try JSONDecoder().decode(type, from: data)
    }

    // MARK: - Response shape

    private struct MessageResponse: Decodable {
        let content: [Block]
        struct Block: Decodable {
            let type: String
            let text: String
        }
    }

    enum ClaudeError: LocalizedError {
        case httpError(Int)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .httpError(let code): "API error \(code)"
            case .invalidResponse: "Invalid response from Claude"
            }
        }
    }
}

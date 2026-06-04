import Foundation

struct ClaudeService {
    static let shared = ClaudeService()

    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    // MARK: - Public API

    struct TileSpec: Codable {
        let name: String
        let type: String
        let unit: String
        let icon: String
        let color: String
        let goal: Double?
        let resetCadence: String?
        let trendDirection: String?
    }

    func buildTile(from prompt: String) async throws -> TileSpec {
        let system = """
        You are a tile builder for a personal tracking app. Given a description of what to track, respond with ONLY a JSON object — no markdown, no extra text.

        {
          "name": "Water",
          "type": "counter",
          "unit": "glasses",
          "icon": "drop.fill",
          "color": "#4A90E2",
          "goal": 8,
          "resetCadence": "daily",
          "trendDirection": null
        }

        Rules:
        - type: "counter" (things that accumulate: water, coffees, pushups) or "measurement" (point-in-time snapshots: weight, mood, sleep)
        - icon: a valid SF Symbol name that represents the topic
        - color: a tasteful hex color matching the topic
        - goal: numeric target or null
        - resetCadence: "daily", "weekly", or null (null for measurements)
        - trendDirection: "up" (higher=better) or "down" (lower=better) for measurements; null for counters
        """
        let text = try await send(system: system, user: prompt, model: Config.fastModel)
        return try decode(TileSpec.self, from: text)
    }

    struct DebriefUpdate: Codable {
        let tileId: String
        let value: Double
        let note: String?
    }

    struct DebriefResult: Codable {
        let updates: [DebriefUpdate]
        let unmatched: [String]
    }

    func parseDebrief(text: String, tiles: [Tile]) async throws -> DebriefResult {
        let tileList = tiles.map {
            #"{"id":"\#($0.id.uuidString)","name":"\#($0.name)","type":"\#($0.type.rawValue)","unit":"\#($0.unit)"}"#
        }.joined(separator: ",")

        let system = """
        You are a debrief parser for a personal tracking app. Given free-text and a list of active tiles, extract numeric updates.
        Respond with ONLY a JSON object — no markdown, no extra text.

        {
          "updates": [{"tileId": "uuid-here", "value": 6, "note": "drank 6 glasses"}],
          "unmatched": ["things mentioned that don't match any tile"]
        }

        Active tiles: [\(tileList)]
        """
        let response = try await send(system: system, user: text, model: Config.fastModel)
        return try decode(DebriefResult.self, from: response)
    }

    func classify(system: String, user: String) async throws -> String {
        try await send(system: system, user: user, model: Config.fastModel)
    }

    func answer(question: String, tiles: [Tile]) async throws -> String {
        let dataSummary = tiles.map { tile in
            let recent = tile.recentEntries.prefix(30).map {
                "  \($0.loggedAt.formatted(date: .abbreviated, time: .shortened)): \($0.value) \(tile.unit)"
            }.joined(separator: "\n")
            return "**\(tile.name)** (\(tile.type.rawValue), unit: \(tile.unit)):\n\(recent.isEmpty ? "  no entries" : recent)"
        }.joined(separator: "\n\n")

        let system = """
        You are a personal data analyst for a tracking app. Answer questions about the user's data concisely and insightfully. Keep it to 2–3 sentences unless a comparison or breakdown genuinely needs more.

        User data:
        \(dataSummary.isEmpty ? "No data recorded yet." : dataSummary)
        """
        return try await send(system: system, user: question, model: Config.smartModel)
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
            "max_tokens": 1024,
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
        // Strip markdown code fences if model wraps JSON in ```
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

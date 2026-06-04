import Foundation

enum ChatIntent {
    case buildTile(String)
    case logDebrief(String)
    case askQuestion(String)
}

func classifyIntent(_ text: String) async throws -> ChatIntent {
    let system = """
    You are an intent classifier for a personal tracking app. Given a user message, respond with ONLY one of these three words:
    - build   (user wants to create a new tracking tile, e.g. "track my water", "add pushups")
    - log     (user is reporting what happened, e.g. "drank 6 glasses, went to gym, 3 coffees")
    - ask     (user is asking a question about their data, e.g. "how much coffee this week?")

    Respond with exactly one word. No punctuation, no explanation.
    """

    let response = try await ClaudeService.shared.classify(system: system, user: text)

    switch response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "build": return .buildTile(text)
    case "ask":   return .askQuestion(text)
    default:      return .logDebrief(text)
    }
}

import Foundation

enum ChatIntent {
    case buildTile(String)
    case logDebrief(String)
    case askQuestion(String)
}

func classifyIntent(_ text: String) async throws -> ChatIntent {
    let word = try await Config.ai.classifyIntent(text)
    switch word {
    case "build": return .buildTile(text)
    case "ask":   return .askQuestion(text)
    default:      return .logDebrief(text)
    }
}

enum Config {
    // Anthropic API key (only needed when using ClaudeService). Read from the
    // gitignored Secrets.swift — see Secrets.example.swift to set it up.
    // Before shipping: move this to your backend and remove from the app bundle.
    static let claudeAPIKey = Secrets.claudeAPIKey

    // Fast + cheap for structured tasks (tile builder, debrief parser)
    static let fastModel = "claude-haiku-4-5-20251001"
    // More capable for open-ended Q&A
    static let smartModel = "claude-haiku-4-5-20251001"

    // Switch AI provider here — one line change.
    // Using Claude for now: Apple's Foundation Models (PCC + on-device) aren't
    // available in the iOS Simulator. Switch back to AppleAIService on a real
    // Apple Intelligence device.
    static let ai: any TileAIService = ClaudeService.shared
    // static let ai: any TileAIService = AppleAIService.shared
}

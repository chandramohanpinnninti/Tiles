enum Config {
    // Replace with your Anthropic API key.
    // Before shipping: move this to your backend and remove from app bundle.
    static let claudeAPIKey = ""

    // Fast + cheap for structured tasks (tile builder, debrief parser)
    static let fastModel = "claude-haiku-4-5-20251001"
    // More capable for open-ended Q&A
    static let smartModel = "claude-haiku-4-5-20251001"
}

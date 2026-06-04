import SwiftUI
import SwiftData

@main
struct TilesApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [Tile.self, TileEntry.self])
    }
}

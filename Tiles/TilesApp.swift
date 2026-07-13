import SwiftUI
import SwiftData

@main
struct TilesApp: App {
    @State private var storage = StorageService()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(storage)
        }
        .modelContainer(storage.container)
    }
}

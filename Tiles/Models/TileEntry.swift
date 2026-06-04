import SwiftData
import Foundation

@Model
final class TileEntry {
    var id: UUID
    var value: Double
    var note: String?
    var loggedAt: Date
    var tile: Tile?

    init(value: Double, note: String? = nil, tile: Tile? = nil) {
        self.id = UUID()
        self.value = value
        self.note = note
        self.loggedAt = Date()
        self.tile = tile
    }
}

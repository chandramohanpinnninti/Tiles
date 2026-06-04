import SwiftData
import Foundation

enum TileType: String, Codable, CaseIterable {
    case counter
    case measurement
}

enum TrendDirection: String, Codable {
    case up   // higher is better (sleep hours, workouts)
    case down // lower is better (weight, caffeine)
}

enum ResetCadence: String, Codable {
    case daily
    case weekly
}

@Model
final class Tile {
    var id: UUID
    var name: String
    var type: TileType
    var unit: String
    var icon: String
    var colorHex: String
    var goal: Double?
    var resetCadence: ResetCadence?
    var trendDirection: TrendDirection?
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var entries: [TileEntry] = []

    init(
        name: String,
        type: TileType,
        unit: String,
        icon: String = "circle.fill",
        colorHex: String = "#4A90E2",
        goal: Double? = nil,
        resetCadence: ResetCadence? = nil,
        trendDirection: TrendDirection? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.unit = unit
        self.icon = icon
        self.colorHex = colorHex
        self.goal = goal
        self.resetCadence = resetCadence
        self.trendDirection = trendDirection
        self.createdAt = Date()
    }

    // Value to show on the tile card
    var displayValue: Double {
        switch type {
        case .counter:
            return periodEntries(for: resetCadence ?? .daily).reduce(0) { $0 + $1.value }
        case .measurement:
            return entries.sorted { $0.loggedAt > $1.loggedAt }.first?.value ?? 0
        }
    }

    var goalProgress: Double? {
        guard let goal, goal > 0 else { return nil }
        return min(displayValue / goal, 1.0)
    }

    func periodEntries(for cadence: ResetCadence) -> [TileEntry] {
        let calendar = Calendar.current
        let now = Date()
        let start: Date
        switch cadence {
        case .daily:
            start = calendar.startOfDay(for: now)
        case .weekly:
            start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        }
        return entries.filter { $0.loggedAt >= start }
    }

    var recentEntries: [TileEntry] {
        entries.sorted { $0.loggedAt > $1.loggedAt }
    }
}

import SwiftData
import Foundation

enum TrackerType: String, Codable, CaseIterable {
    case counter
    case measurement
    case sessionLog = "session_log"
}

enum TrackerPeriod: String, Codable, CaseIterable {
    case daily
    case weekly
    case monthly
    case yearly
    case never
}

enum TargetDirection: String, Codable, CaseIterable {
    case floor
    case ceiling
}

enum TrackerCategory: String, Codable, CaseIterable {
    case hydration
    case nutrition
    case fitness
    case body
    case sleep
    case mood
    case habits
    case substance
    case finance
    case health
    case custom
}

@Model
final class Tracker {
    var id: UUID = UUID()
    var name: String = ""
    var type: TrackerType = TrackerType.counter
    var unit: String = ""
    var period: TrackerPeriod = TrackerPeriod.daily
    var targetValue: Double?
    var targetDirection: TargetDirection?
    var group: String = "My Tiles"
    var category: TrackerCategory = TrackerCategory.custom
    var sortOrder: Int = 0
    var isPlaceholder: Bool = false
    var icon: String = "circle.fill"
    var emoji: String = ""
    var colorHex: String = "#4A90E2"
    var createdAt: Date = Date()
    var archivedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \EntryTrackerValue.tracker) var values: [EntryTrackerValue]? = []

    init(
        name: String,
        type: TrackerType,
        unit: String,
        period: TrackerPeriod = .daily,
        targetValue: Double? = nil,
        targetDirection: TargetDirection? = nil,
        group: String = "My Tiles",
        category: TrackerCategory = .custom,
        sortOrder: Int = 0,
        isPlaceholder: Bool = false,
        icon: String = "circle.fill",
        emoji: String = "",
        colorHex: String = "#4A90E2"
    ) {
        self.name = name
        self.type = type
        self.unit = unit
        self.period = period
        self.targetValue = targetValue
        self.targetDirection = targetDirection
        self.group = group
        self.category = category
        self.sortOrder = sortOrder
        self.isPlaceholder = isPlaceholder
        self.icon = icon
        self.emoji = emoji
        self.colorHex = colorHex
    }
}

extension Tracker {
    var displayValue: Double {
        switch type {
        case .counter, .sessionLog:
            return values(in: currentPeriodStart()).reduce(0) { $0 + $1.value }
        case .measurement:
            return recentValues.first?.value ?? 0
        }
    }

    var goalProgress: Double? {
        guard let targetValue, targetValue > 0 else { return nil }
        switch targetDirection ?? .floor {
        case .floor:
            return min(displayValue / targetValue, 1.0)
        case .ceiling:
            return min(max((targetValue - displayValue) / targetValue, 0), 1.0)
        }
    }

    var recentValues: [EntryTrackerValue] {
        (values ?? [])
            .filter { $0.entry != nil }
            .sorted { ($0.entry?.loggedAt ?? .distantPast) > ($1.entry?.loggedAt ?? .distantPast) }
    }

    func values(in startDate: Date?) -> [EntryTrackerValue] {
        guard let startDate else { return values ?? [] }
        return (values ?? []).filter { value in
            guard let loggedAt = value.entry?.loggedAt else { return false }
            return loggedAt >= startDate
        }
    }

    private func currentPeriodStart() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        switch period {
        case .daily:
            return calendar.startOfDay(for: now)
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: now)?.start
        case .monthly:
            return calendar.dateInterval(of: .month, for: now)?.start
        case .yearly:
            return calendar.dateInterval(of: .year, for: now)?.start
        case .never:
            return nil
        }
    }
}

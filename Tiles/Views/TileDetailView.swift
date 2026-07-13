import SwiftUI
import Charts

struct TileDetailView: View {
    let tile: Tracker

    @Environment(StorageService.self) private var storage
    @State private var selectedRange: TimeRange = .week
    @State private var aiInsight: String?
    @State private var isLoadingInsight = false
    @State private var showingEntry = false
    @State private var expandedSessions: Set<UUID> = []

    enum TimeRange: String, CaseIterable {
        case week    = "detail.range.7d"
        case month   = "detail.range.30d"
        case quarter = "detail.range.3m"
        case year    = "detail.range.1y"

        var days: Int {
            switch self {
            case .week:    return 7
            case .month:   return 30
            case .quarter: return 90
            case .year:    return 365
            }
        }
    }

    private var tileColor: Color { Color(hex: tile.colorHex) }

    private var rangeEntries: [EntryTrackerValue] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: Date()) ?? Date()
        return tile.recentValues.filter { ($0.entry?.loggedAt ?? .distantPast) >= cutoff }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if tile.type == .sessionLog {
                    workoutHeroSection
                    rangeSelector
                    workoutChartSection
                    workoutSessionsSection
                } else {
                    heroSection
                    rangeSelector
                    chartSection
                    insightSection
                    historySection
                }
            }
            .padding(16)
        }
        .navigationTitle(tile.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("detail.action.log", systemImage: "plus") {
                    showingEntry = true
                }
            }
        }
        .sheet(isPresented: $showingEntry) {
            if tile.type == .sessionLog {
                ExerciseEntrySheet(tile: tile) { exercises, note in
                    storage.addWorkoutEntry(to: tile, exercises: exercises, note: note)
                    showingEntry = false
                } onCancel: {
                    showingEntry = false
                }
            } else {
                MeasurementEntrySheet(tile: tile) { value, note in
                    storage.addEntry(to: tile, value: value, note: note)
                    showingEntry = false
                } onCancel: {
                    showingEntry = false
                }
            }
        }
        .task { await loadInsight() }
    }

    // MARK: - Standard sections

    private var heroSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(tile.displayValue.formatted())
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(tileColor)
            Text(tile.unit)
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    private var rangeSelector: some View {
        Picker("", selection: $selectedRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(LocalizedStringKey(range.rawValue)).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var chartSection: some View {
        if tile.type == .counter || tile.type == .sessionLog {
            Chart(rangeEntries) { value in
                BarMark(
                    x: .value("Date", value.entry?.loggedAt ?? .distantPast, unit: .day),
                    y: .value(tile.unit, value.value)
                )
                .foregroundStyle(tileColor)
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5))
            }
        } else {
            Chart(rangeEntries) { value in
                LineMark(
                    x: .value("Date", value.entry?.loggedAt ?? .distantPast),
                    y: .value(tile.unit, value.value)
                )
                .foregroundStyle(tileColor)
                PointMark(
                    x: .value("Date", value.entry?.loggedAt ?? .distantPast),
                    y: .value(tile.unit, value.value)
                )
                .foregroundStyle(tileColor)
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5))
            }
        }
    }

    private var insightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("detail.section.insights", systemImage: "sparkles")
                .font(.headline)
            if isLoadingInsight {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let insight = aiInsight {
                Text(insight)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("detail.section.history", systemImage: "clock")
                .font(.headline)

            if tile.recentValues.isEmpty {
                Text("detail.empty.history")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(tile.recentValues.prefix(20))) { value in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text((value.entry?.loggedAt ?? .distantPast).formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(value.value.formatted()) \(value.unit)")
                                    .font(.subheadline.monospacedDigit())
                                if let note = value.entry?.notes {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if let entry = value.entry {
                            entryDetails(entry)
                        }
                    }
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private func entryDetails(_ entry: Entry) -> some View {
        let exerciseSets = (entry.exerciseSets ?? []).sorted { $0.order < $1.order }
        let mealItems = (entry.mealItems ?? []).sorted { $0.order < $1.order }

        if !exerciseSets.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(exerciseSets) { set in
                    Text(exerciseSummary(set))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        if !mealItems.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(mealItems) { item in
                    Text(mealSummary(item))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func exerciseSummary(_ set: ExerciseSet) -> String {
        let load = set.weightKg.map { "\($0.formatted()) kg " } ?? ""
        if let reps = set.reps { return "\(set.exerciseName): \(load)\(set.sets)x\(reps)" }
        if let dur = set.durationSec { return "\(set.exerciseName): \(load)\(set.sets)x\(dur)s" }
        return "\(set.exerciseName): \(load)\(set.sets) sets"
    }

    private func mealSummary(_ item: MealItem) -> String {
        var parts = [item.foodName]
        if let kcal = item.kcal { parts.append("~\(kcal.formatted()) kcal") }
        if let protein = item.proteinG { parts.append("P \(protein.formatted())g") }
        if let carbs = item.carbsG { parts.append("C \(carbs.formatted())g") }
        if let fat = item.fatG { parts.append("F \(fat.formatted())g") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Workout sections

    private var latestVolume: Double { tile.recentValues.first?.value ?? 0 }

    private var volumeDelta: Double? {
        guard tile.recentValues.count >= 2 else { return nil }
        return tile.recentValues[0].value - tile.recentValues[1].value
    }

    private var workoutHeroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(latestVolume.formatted())
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(tileColor)
                Text(tile.unit)
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Spacer()

                if let delta = volumeDelta {
                    let positive = delta >= 0
                    let color: Color = positive ? .green : .red
                    Text("\(positive ? "↑" : "↓") \(abs(delta).formatted()) \(tile.unit)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(color.opacity(0.12), in: Capsule())
                }
            }

            Text(workoutSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var workoutSubtitle: String {
        guard let loggedAt = tile.recentValues.first?.entry?.loggedAt else { return "" }
        let cal = Calendar.current
        let when: String
        if cal.isDateInToday(loggedAt) { when = "today" }
        else if cal.isDateInYesterday(loggedAt) { when = "yesterday" }
        else { when = loggedAt.formatted(.dateTime.weekday(.abbreviated).day()) }
        let monthInterval = cal.dateInterval(of: .month, for: Date())
        let countThisMonth = tile.recentValues.filter {
            guard let d = $0.entry?.loggedAt else { return false }
            return monthInterval?.contains(d) ?? false
        }.count
        return "last session · \(when) · \(countThisMonth) total this month"
    }

    private var workoutChartSection: some View {
        let sorted = rangeEntries.sorted { ($0.entry?.loggedAt ?? .distantPast) < ($1.entry?.loggedAt ?? .distantPast) }
        return Chart(sorted) { value in
            BarMark(
                x: .value("Date", value.entry?.loggedAt ?? .distantPast, unit: .day),
                y: .value("Volume", value.value)
            )
            .foregroundStyle(tileColor.gradient)
        }
        .frame(height: 180)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisValueLabel(format: .dateTime.month(.twoDigits).day())
                AxisGridLine()
            }
        }
    }

    private var workoutSessionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("detail.workout.sessions")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
                .padding(.bottom, 12)

            if tile.recentValues.isEmpty {
                Text("detail.empty.history")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(tile.recentValues.prefix(20))) { tv in
                    WorkoutSessionRow(
                        trackerValue: tv,
                        unit: tile.unit,
                        isExpanded: tv.entry.map { expandedSessions.contains($0.id) } ?? false
                    ) {
                        if let id = tv.entry?.id {
                            if expandedSessions.contains(id) {
                                expandedSessions.remove(id)
                            } else {
                                expandedSessions.insert(id)
                            }
                        }
                    }
                    Divider()
                }
            }
        }
    }

    // MARK: - AI insight

    private func loadInsight() async {
        guard tile.type != .sessionLog, !tile.recentValues.isEmpty else { return }
        isLoadingInsight = true
        let question = "Give a brief 1-2 sentence insight about my \(tile.name) data over the last \(selectedRange.days) days."
        aiInsight = try? await Config.ai.answer(question: question, trackers: [tile])
        isLoadingInsight = false
    }
}

// MARK: - WorkoutSessionRow

private struct WorkoutSessionRow: View {
    let trackerValue: EntryTrackerValue
    let unit: String
    let isExpanded: Bool
    let onToggle: () -> Void

    private var entry: Entry? { trackerValue.entry }
    private var allSets: [ExerciseSet] {
        (entry?.exerciseSets ?? []).sorted { $0.order < $1.order }
    }

    private var groupedExercises: [(name: String, records: [ExerciseSet])] {
        var result: [(name: String, records: [ExerciseSet])] = []
        var nameIndex: [String: Int] = [:]
        for set in allSets {
            if let idx = nameIndex[set.exerciseName] {
                result[idx].records.append(set)
            } else {
                nameIndex[set.exerciseName] = result.count
                result.append((name: set.exerciseName, records: [set]))
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(dateLabel)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(subtitleLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(trackerValue.value.formatted()) \(unit)")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("detail.workout.volume")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 3)
                    }
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded && !groupedExercises.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(groupedExercises, id: \.name) { group in
                        HStack {
                            Text(group.name)
                                .font(.subheadline)
                            Spacer()
                            Text(exerciseSummaryText(records: group.records))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.bottom, 12)
            }
        }
    }

    private var dateLabel: String {
        guard let date = entry?.loggedAt else { return "" }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter.string(from: date)
    }

    private var subtitleLabel: String {
        guard let date = entry?.loggedAt else { return "" }
        let time = date.formatted(.dateTime.hour().minute())
        let uniqueCount = Set(allSets.map { $0.exerciseName }).count
        return "\(time) · \(uniqueCount == 1 ? "1 exercise" : "\(uniqueCount) exercises")"
    }

    private func exerciseSummaryText(records: [ExerciseSet]) -> String {
        if records.count == 1 {
            let r = records[0]
            var parts: [String] = []
            if let w = r.weightKg { parts.append("\(w.formatted()) kg") }
            if let reps = r.reps { parts.append("\(r.sets)×\(reps)") }
            else if let dur = r.durationSec { parts.append("\(r.sets)×\(dur)s") }
            else { parts.append("\(r.sets) sets") }
            return parts.joined(separator: " · ")
        }

        let weights = records.compactMap { $0.weightKg }
        let allReps = records.compactMap { $0.reps }
        let allSameWeight = weights.count == records.count
            && weights.dropFirst().allSatisfy { abs($0 - weights[0]) < 0.01 }
        let allSameReps = allReps.count == records.count && Set(allReps).count == 1

        if allSameWeight && allSameReps {
            let w = weights.first.map { "\($0.formatted()) kg · " } ?? ""
            return "\(w)\(records.count)×\(allReps[0])"
        }

        return records.map { r in
            let w = r.weightKg.map { $0.formatted() } ?? "BW"
            let rep = r.reps.map { "×\($0)" } ?? (r.durationSec.map { "×\($0)s" } ?? "")
            return "\(w)\(rep)"
        }.joined(separator: " · ")
    }
}

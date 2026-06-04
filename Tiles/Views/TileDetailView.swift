import SwiftUI
import Charts

struct TileDetailView: View {
    let tile: Tile

    @State private var selectedRange: TimeRange = .week
    @State private var aiInsight: String?
    @State private var isLoadingInsight = false
    @State private var showingEntry = false

    enum TimeRange: String, CaseIterable {
        case week  = "detail.range.7d"
        case month = "detail.range.30d"
        case quarter = "detail.range.3m"
        case year  = "detail.range.1y"

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

    private var rangeEntries: [TileEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: Date()) ?? Date()
        return tile.recentEntries.filter { $0.loggedAt >= cutoff }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroSection
                rangeSelector
                chartSection
                insightSection
                historySection
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
            MeasurementEntrySheet(tile: tile) { value, note in
                let entry = TileEntry(value: value, note: note, tile: tile)
                tile.entries.append(entry)
                showingEntry = false
            } onCancel: {
                showingEntry = false
            }
        }
        .task { await loadInsight() }
    }

    // MARK: - Sections

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

    private var chartSection: some View {
        Chart(rangeEntries) { entry in
            if tile.type == .counter {
                BarMark(
                    x: .value("Date", entry.loggedAt, unit: .day),
                    y: .value(tile.unit, entry.value)
                )
                .foregroundStyle(tileColor)
            } else {
                LineMark(
                    x: .value("Date", entry.loggedAt),
                    y: .value(tile.unit, entry.value)
                )
                .foregroundStyle(tileColor)
                PointMark(
                    x: .value("Date", entry.loggedAt),
                    y: .value(tile.unit, entry.value)
                )
                .foregroundStyle(tileColor)
            }
        }
        .frame(height: 180)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5))
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

            if tile.recentEntries.isEmpty {
                Text("detail.empty.history")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(tile.recentEntries.prefix(20))) { entry in
                    HStack {
                        Text(entry.loggedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(entry.value.formatted()) \(tile.unit)")
                                .font(.subheadline.monospacedDigit())
                            if let note = entry.note {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
        guard !tile.recentEntries.isEmpty else { return }
        isLoadingInsight = true
        let question = "Give a brief 1–2 sentence insight about my \(tile.name) data over the last \(selectedRange.days) days."
        aiInsight = try? await ClaudeService.shared.answer(question: question, tiles: [tile])
        isLoadingInsight = false
    }
}

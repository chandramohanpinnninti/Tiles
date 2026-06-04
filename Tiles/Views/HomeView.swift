import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var tiles: [Tile]

    @State private var chatText = ""
    @State private var isProcessing = false
    @State private var pendingDebrief: DebriefPreview?
    @State private var pendingAnswer: String?
    @State private var errorMessage: String?
    @State private var measurementTarget: Tile?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    if tiles.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(tiles) { tile in
                                NavigationLink(destination: TileDetailView(tile: tile)) {
                                    TileCardView(tile: tile) { quickLog(tile) }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
                Divider()
                ChatInputBar(text: $chatText, isProcessing: isProcessing) {
                    Task { await handleSubmit() }
                }
            }
            .navigationTitle("home.title")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $pendingDebrief) { preview in
            DebriefPreviewSheet(preview: preview) { confirmed in
                if confirmed { applyDebrief(preview) }
                pendingDebrief = nil
            }
        }
        .sheet(item: $measurementTarget) { tile in
            MeasurementEntrySheet(tile: tile) { value, note in
                addEntry(to: tile, value: value, note: note)
                measurementTarget = nil
            } onCancel: {
                measurementTarget = nil
            }
        }
        .alert("error.title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("error.action.ok") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("detail.section.insights", isPresented: Binding(
            get: { pendingAnswer != nil },
            set: { if !$0 { pendingAnswer = nil } }
        )) {
            Button("error.action.ok") { pendingAnswer = nil }
        } message: {
            Text(pendingAnswer ?? "")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.square.dashed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("home.empty.title")
                .font(.headline)
            Text("home.empty.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(48)
    }

    // MARK: - Chat handler

    private func handleSubmit() async {
        let text = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chatText = ""
        isProcessing = true
        defer { isProcessing = false }

        do {
            let intent = try await classifyIntent(text)
            switch intent {
            case .buildTile(let prompt):
                let spec = try await ClaudeService.shared.buildTile(from: prompt)
                await MainActor.run { insertTile(from: spec) }

            case .logDebrief(let log):
                let result = try await ClaudeService.shared.parseDebrief(text: log, tiles: tiles)
                await MainActor.run {
                    pendingDebrief = DebriefPreview(result: result, tiles: tiles)
                }

            case .askQuestion(let question):
                let answer = try await ClaudeService.shared.answer(question: question, tiles: tiles)
                await MainActor.run { pendingAnswer = answer }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    // MARK: - Tile creation

    private func insertTile(from spec: ClaudeService.TileSpec) {
        let tile = Tile(
            name: spec.name,
            type: TileType(rawValue: spec.type) ?? .counter,
            unit: spec.unit,
            icon: spec.icon,
            colorHex: spec.color,
            goal: spec.goal,
            resetCadence: spec.resetCadence.flatMap { ResetCadence(rawValue: $0) },
            trendDirection: spec.trendDirection.flatMap { TrendDirection(rawValue: $0) }
        )
        context.insert(tile)
    }

    // MARK: - Logging

    private func quickLog(_ tile: Tile) {
        if tile.type == .counter {
            addEntry(to: tile, value: 1, note: nil)
        } else {
            measurementTarget = tile
        }
    }

    private func addEntry(to tile: Tile, value: Double, note: String?) {
        let entry = TileEntry(value: value, note: note, tile: tile)
        tile.entries.append(entry)
    }

    private func applyDebrief(_ preview: DebriefPreview) {
        for item in preview.updates {
            guard let tile = tiles.first(where: { $0.id.uuidString == item.tileId }) else { continue }
            addEntry(to: tile, value: item.value, note: item.note)
        }
    }
}

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(StorageService.self) private var storage
    @Query(sort: \Tracker.sortOrder) private var trackers: [Tracker]

    @State private var isProcessing = false
    @State private var reply: ChatReply?
    @State private var measurementTarget: Tracker?
    @State private var workoutTarget: Tracker?
    @State private var isEditing = false
    @State private var trackerToDelete: Tracker?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var activeTrackers: [Tracker] {
        trackers.filter { $0.archivedAt == nil }
    }

    private var trackerSections: [TrackerSection] {
        var sections: [TrackerSection] = []
        for tracker in activeTrackers {
            if let index = sections.firstIndex(where: { $0.title == tracker.group }) {
                sections[index].trackers.append(tracker)
            } else {
                sections.append(TrackerSection(title: tracker.group, trackers: [tracker]))
            }
        }
        return sections
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if activeTrackers.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(trackerSections) { section in
                            trackerSection(section)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 14)
                    .padding(.bottom, 104)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Tiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("common.done") {
                            withAnimation(.easeInOut(duration: 0.2)) { isEditing = false }
                        }
                        .bold()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                ChatInputBar(isProcessing: isProcessing, reply: reply) { text in
                    Task { await handleSubmit(text) }
                } onDismissReply: {
                    reply = nil
                } onSpeechError: { message in
                    reply = ChatReply(
                        icon: "mic.slash.fill",
                        title: "Voice input unavailable",
                        message: message,
                        isError: true
                    )
                }
            }
        }
        .alert("tile.delete.title", isPresented: Binding(
            get: { trackerToDelete != nil },
            set: { if !$0 { trackerToDelete = nil } }
        ), presenting: trackerToDelete) { tracker in
            Button("tile.action.delete", role: .destructive) {
                withAnimation { storage.deleteTile(tracker) }
                trackerToDelete = nil
            }
            Button("common.cancel", role: .cancel) { trackerToDelete = nil }
        } message: { tracker in
            Text(String(format: NSLocalizedString("tile.delete.message", comment: ""), tracker.name))
        }
        .sheet(item: $measurementTarget) { tracker in
            MeasurementEntrySheet(tile: tracker) { value, note in
                addEntry(to: tracker, value: value, note: note)
                measurementTarget = nil
            } onCancel: {
                measurementTarget = nil
            }
        }
        .sheet(item: $workoutTarget) { tracker in
            ExerciseEntrySheet(tile: tracker) { exercises, note in
                storage.addWorkoutEntry(to: tracker, exercises: exercises, note: note)
                workoutTarget = nil
            } onCancel: {
                workoutTarget = nil
            }
        }
    }

    // MARK: - Sections

    private func trackerSection(_ section: TrackerSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(section.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                Text("· \(section.caption)")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .frame(width: 30, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("section.actions"))
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(section.trackers) { tracker in
                    tileGridItem(tracker)
                }
            }
        }
    }

    // MARK: - Tile grid item

    @ViewBuilder
    private func tileGridItem(_ tracker: Tracker) -> some View {
        Group {
            if isEditing {
                TileCardView(tile: tracker, isEditing: true, onDelete: { trackerToDelete = tracker }) {
                    quickLog(tracker)
                }
            } else {
                NavigationLink(destination: TileDetailView(tile: tracker)) {
                    TileCardView(tile: tracker) { quickLog(tracker) }
                }
                .buttonStyle(.plain)
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                if !isEditing {
                    withAnimation(.easeInOut(duration: 0.2)) { isEditing = true }
                }
            }
        )
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

    private func handleSubmit(_ text: String) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            let intent = try await classifyIntent(text)
            switch intent {
            case .buildTile(let prompt):
                let spec = try await Config.ai.buildTile(from: prompt)
                await MainActor.run {
                    storage.insertTile(from: spec)
                    reply = ChatReply(
                        title: "Created \(spec.name)",
                        message: "Added a new \(spec.name) tile to your home screen.",
                        chips: [ChatReply.Chip(
                            name: spec.name,
                            icon: spec.icon,
                            emoji: spec.emoji,
                            colorHex: spec.color,
                            delta: "New"
                        )]
                    )
                }

            case .logDebrief(let log):
                let result = try await Config.ai.parseDebrief(text: log, trackers: trackers)
                await MainActor.run {
                    let preview = DebriefPreview(result: result, trackers: trackers)
                    storage.applyDebrief(result, rawText: log, trackers: trackers)
                    reply = makeLogReply(preview)
                }

            case .askQuestion(let question):
                let answer = try await Config.ai.answer(question: question, trackers: trackers)
                await MainActor.run {
                    reply = ChatReply(icon: "lightbulb.fill", title: "Here's what I found", message: answer)
                }
            }
        } catch {
            await MainActor.run {
                reply = ChatReply(
                    icon: "exclamationmark.triangle.fill",
                    title: "Something went wrong",
                    message: error.localizedDescription,
                    isError: true
                )
            }
        }
    }

    private func makeLogReply(_ preview: DebriefPreview) -> ChatReply {
        let chips = preview.updates.map { item in
            ChatReply.Chip(
                name: item.tileName,
                icon: item.tileIcon,
                emoji: item.tileEmoji,
                colorHex: item.tileColorHex,
                delta: "+\(item.value.formatted())"
            )
        }
        let summary: String
        if preview.updates.isEmpty {
            summary = "I couldn't find a matching tracker for that."
        } else {
            let parts = preview.updates.map { "\($0.value.formatted()) \($0.unit) \($0.tileName.lowercased())" }
            summary = "Logged " + parts.joined(separator: ", ") + "."
        }
        return ChatReply(title: "Logged it", message: summary, chips: chips)
    }

    // MARK: - Logging

    private func quickLog(_ tracker: Tracker) {
        switch tracker.type {
        case .sessionLog:
            workoutTarget = tracker
        case .counter:
            addEntry(to: tracker, value: 1, note: nil)
        case .measurement:
            measurementTarget = tracker
        }
    }

    private func addEntry(to tracker: Tracker, value: Double, note: String?) {
        storage.addEntry(to: tracker, value: value, note: note)
    }
}

private struct TrackerSection: Identifiable {
    let id = UUID()
    let title: String
    var trackers: [Tracker]

    var caption: String {
        let period = trackers.map(\.period).mostCommon
        switch period {
        case .daily:
            return "\(trackers.count)"
        case .weekly:
            return "\(trackers.count) days"
        case .monthly:
            return "\(trackers.count) months"
        case .yearly:
            return "\(trackers.count) years"
        case .never:
            return "\(trackers.count)"
        case nil:
            return "\(trackers.count)"
        }
    }
}

private extension Array where Element: Hashable {
    var mostCommon: Element? {
        Dictionary(grouping: self, by: { $0 })
            .max { lhs, rhs in lhs.value.count < rhs.value.count }?
            .key
    }
}

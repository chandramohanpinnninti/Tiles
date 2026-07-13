import SwiftUI

/// A reply from the agent, shown above the input field when present.
struct ChatReply: Identifiable, Equatable {
    let id = UUID()
    var icon: String = "sparkles"
    var title: String
    var message: String
    var chips: [Chip] = []
    var isError: Bool = false

    struct Chip: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let icon: String
        let emoji: String
        let colorHex: String
        let delta: String
    }

    static func == (lhs: ChatReply, rhs: ChatReply) -> Bool { lhs.id == rhs.id }
}

private struct VoiceWaveformView: View {
    let isActive: Bool

    private let barCount = 36

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: !isActive)) { context in
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(barColor(for: index))
                        .frame(width: 3, height: barHeight(for: index, at: context.date))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func barHeight(for index: Int, at date: Date) -> CGFloat {
        guard isActive else { return index.isMultiple(of: 4) ? 12 : 6 }
        let phase = date.timeIntervalSinceReferenceDate * 5.5
        let wave = abs(sin(phase + Double(index) * 0.45))
        let emphasis = index > 22 && index < 29 ? 1.0 : 0.62
        return 5 + CGFloat(wave * 23 * emphasis)
    }

    private func barColor(for index: Int) -> Color {
        index > 22 && index < 29 ? .primary : .secondary.opacity(0.35)
    }
}

/// Floating chat bar pinned to the bottom of the screen. Collapsed it is just a
/// text field + send button; when a reply is present it expands upward to show it.
struct ChatInputBar: View {
    let isProcessing: Bool
    let reply: ChatReply?
    let onSubmit: (String) -> Void
    let onDismissReply: () -> Void
    let onSpeechError: (String) -> Void

    @StateObject private var speechRecognition = SpeechRecognitionService()
    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isVoiceMode: Bool {
        speechRecognition.isRecording
    }

    var body: some View {
        VStack(spacing: 10) {
            if let reply {
                replyCard(reply)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            inputRow
                .chatInputGlass()
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: reply)
        .onChange(of: speechRecognition.transcript) { _, transcript in
            guard speechRecognition.isRecording else { return }
            text = transcript
        }
        .onChange(of: speechRecognition.errorMessage) { _, message in
            guard let message else { return }
            onSpeechError(message)
        }
        .onDisappear {
            speechRecognition.stopRecording(cancelRecognition: true)
        }
    }

    // MARK: - Input row

    @ViewBuilder
    private var inputRow: some View {
        if isVoiceMode {
            voiceInputRow
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            textInputRow
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    private var textInputRow: some View {
        HStack(spacing: 10) {
            Button {
                isFocused = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(.primary.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .chatControlGlass()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("tile.action.add"))

            TextField("Log, build, or ask...", text: $text)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit(submit)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.primary)
                .tint(.primary)

            if isProcessing {
                ProgressView()
                    .frame(width: 38, height: 38)
            } else if isEmpty {
                Button {
                    isFocused = false
                    Task { await speechRecognition.startRecording() }
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("chat.voice.start"))
            } else {
                sendButton(style: .accent)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var voiceInputRow: some View {
        HStack(spacing: 12) {
            Button {
                speechRecognition.stopRecording()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .chatControlGlass()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("chat.voice.stop"))

            VoiceWaveformView(isActive: speechRecognition.isRecording)
                .frame(height: 28)
                .frame(maxWidth: .infinity)

            if isProcessing {
                ProgressView()
                    .frame(width: 44, height: 44)
            } else {
                sendButton(style: .dark)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
    }

    private enum SendButtonStyle {
        case accent
        case dark

        var background: Color {
            switch self {
            case .accent: Color.accentColor
            case .dark: Color.primary
            }
        }
    }

    private func sendButton(style: SendButtonStyle) -> some View {
        Button(action: submit) {
            Image(systemName: "arrow.up")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(.systemBackground))
                .frame(width: style == .dark ? 44 : 38, height: style == .dark ? 44 : 38)
                .background(isEmpty ? Color.gray.opacity(0.5) : style.background, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(isEmpty)
        .accessibilityLabel(Text("chat.action.send"))
    }

    // MARK: - Reply card

    private func replyCard(_ reply: ChatReply) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: reply.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(reply.isError ? Color.orange : Color.accentColor)
                    .frame(width: 30, height: 30)
                    .background((reply.isError ? Color.orange : Color.accentColor).opacity(0.15), in: Circle())
                Text(reply.title)
                    .font(.headline)
                Spacer()
                Button {
                    onDismissReply()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .chatControlGlass()
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Dismiss reply"))
            }

            Text(reply.message)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(reply.chips) { chip in
                HStack(spacing: 12) {
                    TileGlyph(icon: chip.icon, emoji: chip.emoji, color: Color(hex: chip.colorHex), font: .body)
                        .frame(width: 28, height: 28)
                        .background(Color(hex: chip.colorHex).opacity(0.15), in: Circle())
                    Text(chip.name)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(chip.delta)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .chatChipGlass()
            }
        }
        .padding(16)
        .chatReplyGlass()
    }

    // MARK: - Actions

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        speechRecognition.stopRecording()
        text = ""
        isFocused = false
        onSubmit(trimmed)
    }
}
private extension View {
    @ViewBuilder
    func chatInputGlass() -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 18, y: 6)
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.55), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.1), radius: 16, y: 5)
        }
    }

    @ViewBuilder
    func chatReplyGlass() -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.55), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.1), radius: 16, y: 6)
        }
    }

    @ViewBuilder
    func chatControlGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Circle())
        } else {
            self
                .background(.thinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.45), lineWidth: 0.7))
        }
    }

    @ViewBuilder
    func chatChipGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            self.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}


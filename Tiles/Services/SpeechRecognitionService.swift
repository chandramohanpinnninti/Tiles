import AVFAudio
import Combine
import Foundation
import Speech

@MainActor
final class SpeechRecognitionService: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isRecording = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionSessionID = UUID()

    func toggleRecording() async {
        if isRecording {
            stopRecording()
        } else {
            await startRecording()
        }
    }

    func startRecording() async {
        guard !isRecording else { return }
        errorMessage = nil

        guard await requestSpeechAuthorization() else {
            errorMessage = "Speech recognition permission is required to use voice input."
            return
        }

        guard await requestMicrophoneAuthorization() else {
            errorMessage = "Microphone permission is required to use voice input."
            return
        }

        guard let speechRecognizer = availableSpeechRecognizer() else {
            errorMessage = "Speech recognition is not available for your current language right now."
            return
        }

        do {
            try configureAudioSession()
            try beginRecognition(with: speechRecognizer)
            isRecording = true
        } catch {
            stopRecording(cancelRecognition: true)
            errorMessage = "Voice input could not start: \(error.localizedDescription)"
        }
    }

    func stopRecording(cancelRecognition: Bool = false) {
        guard isRecording || recognitionTask != nil || audioEngine.isRunning else { return }
        recognitionSessionID = UUID()

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.reset()

        if cancelRecognition {
            recognitionTask?.cancel()
        } else {
            recognitionRequest?.endAudio()
        }

        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func beginRecognition(with speechRecognizer: SFSpeechRecognizer) throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionSessionID = UUID()
        let sessionID = recognitionSessionID
        transcript = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        recognitionRequest = request

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.recognitionSessionID == sessionID else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }

                if let error {
                    self.stopRecording(cancelRecognition: true)
                    self.errorMessage = "Voice input stopped: \(error.localizedDescription)"
                } else if result?.isFinal == true {
                    self.stopRecording()
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func availableSpeechRecognizer() -> SFSpeechRecognizer? {
        let recognizers = [
            SFSpeechRecognizer(locale: Locale(identifier: "en_US")),
            SFSpeechRecognizer(locale: Locale.current)
        ]

        return recognizers.compactMap { $0 }.first { $0.isAvailable }
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { isGranted in
                continuation.resume(returning: isGranted)
            }
        }
    }
}

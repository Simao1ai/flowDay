// SpeechRecognizer.swift
// FlowDay
//
// Real SFSpeechRecognizer implementation.
// REPLACES the mock SpeechRecognizer class in AIAssistantView.swift.
// The existing VoiceInputView in AIAssistantView.swift uses this class
// via @State — no changes needed in AIAssistantView.

import Foundation
import Speech
import AVFoundation
import Observation

@Observable @MainActor
class SpeechRecognizer {
    var transcribedText: String = ""
    var isListening: Bool = false
    var isAvailable: Bool = false
    var errorMessage: String?

    private var speechRecognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioSession = AVAudioSession.sharedInstance()

    init() {
        checkAvailability()
    }

    // MARK: - Availability Check

    private func checkAvailability() {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        isAvailable = recognizer?.isAvailable ?? false
        self.speechRecognizer = recognizer
    }

    // MARK: - Permissions

    @MainActor
    func requestPermission() async -> Bool {
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechStatus else {
            self.errorMessage = "Speech recognition permission denied"
            return false
        }

        // Request microphone permission
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            self.errorMessage = "Microphone permission denied"
            return false
        }
        return true
    }

    // MARK: - Recognition

    @MainActor
    func startListening() {
        // Reset state
        errorMessage = nil
        transcribedText = ""

        // Verify availability
        guard isAvailable else {
            errorMessage = "Speech recognition not available on this device"
            return
        }

        // Verify speech recognizer exists
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer unavailable"
            return
        }

        // Configure audio session
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }

        // Cancel existing recognition task
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }

        // Create recognition request
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true

        // Prefer on-device recognition if available
        if #available(iOS 17.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        self.recognitionRequest = recognitionRequest

        // Get audio input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on input node
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Prepare and start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Audio engine error: \(error.localizedDescription)"
            return
        }

        // Start recognition task
        // The SFSpeechRecognizer callback arrives on a background thread, so all
        // @MainActor-isolated mutations are dispatched back to the main actor.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let errorMsg = error?.localizedDescription

            Task { @MainActor [weak self] in
                if let text { self?.transcribedText = text }
                if let errorMsg {
                    self?.errorMessage = errorMsg
                    self?.stopListening()
                } else if isFinal {
                    self?.stopListening()
                }
            }
        }

        isListening = true
    }

    @MainActor
    func stopListening() {
        isListening = false

        // Stop audio recording
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Deactivate audio session
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session deactivation error: \(error.localizedDescription)"
        }
    }

    // deinit cannot access @MainActor-isolated properties.
    // AVAudioEngine, SFSpeechAudioBufferRecognitionRequest, and
    // SFSpeechRecognitionTask all perform cleanup on deallocation via ARC.
}


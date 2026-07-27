import Foundation
import Speech
import AVFoundation

enum VoiceLogProblem: Equatable {
    case speechUnavailable
    case speechDenied
    case speechRestricted
    case speechUnknown
    case microphoneDenied
    case audioSessionFailed
    case recognitionRequestFailed
    case recognitionStoppedBeforeTranscript
    case noTranscript
    case microphoneStartFailed

    var message: String {
        switch self {
        case .speechUnavailable:
            return "Speech recognition is not available right now."
        case .speechDenied:
            return "Speech recognition access is off. Open iOS Settings, allow Speech Recognition for My Fatness Tracker, then try again."
        case .speechRestricted:
            return "Speech recognition is restricted on this device, so voice logging cannot run here."
        case .speechUnknown:
            return "The app could not confirm speech recognition access. Open iOS Settings and check the permission before trying again."
        case .microphoneDenied:
            return "Microphone access is off. Open iOS Settings, allow Microphone for My Fatness Tracker, then try again."
        case .audioSessionFailed:
            return "The microphone could not start. Try again after closing other audio apps."
        case .recognitionRequestFailed:
            return "The app could not start a voice recognition request."
        case .recognitionStoppedBeforeTranscript:
            return "Voice logging stopped before the app could understand that confession."
        case .noTranscript:
            return "Voice logging did not catch any food. Try speaking closer to the mic."
        case .microphoneStartFailed:
            return "The microphone failed to start. Try again in a moment."
        }
    }

    var shouldOfferSettings: Bool {
        switch self {
        case .speechDenied, .speechUnknown, .microphoneDenied:
            return true
        case .speechUnavailable, .speechRestricted, .audioSessionFailed, .recognitionRequestFailed, .recognitionStoppedBeforeTranscript, .noTranscript, .microphoneStartFailed:
            return false
        }
    }
}

enum VoiceMicrophonePermissionState: Equatable {
    case granted
    case denied
    case undetermined
}

enum VoicePermissionPreflight {
    static func speechProblem(for status: SFSpeechRecognizerAuthorizationStatus) -> VoiceLogProblem? {
        switch status {
        case .authorized:
            return nil
        case .denied:
            return .speechDenied
        case .restricted:
            return .speechRestricted
        case .notDetermined:
            return .speechUnknown
        @unknown default:
            return .speechUnknown
        }
    }

    static func microphoneProblem(for permission: VoiceMicrophonePermissionState) -> VoiceLogProblem? {
        switch permission {
        case .granted:
            return nil
        case .denied:
            return .microphoneDenied
        case .undetermined:
            return .speechUnknown
        }
    }
}

class VoiceService: ObservableObject {
    static let shared = VoiceService()
    @Published private(set) var isListening = false
    @Published private(set) var currentTranscript = ""
    
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var hasInstalledInputTap = false
    private var latestTranscript = ""
    private var completionHandler: ((String) -> Void)?
    private var errorHandler: ((VoiceLogProblem) -> Void)?
    private var autoStopWorkItem: DispatchWorkItem?
    private var didDeliverTranscript = false
    
    private init() {}
    
    func startListening(
        completion: @escaping (String) -> Void,
        onError: @escaping (VoiceLogProblem) -> Void = { _ in }
    ) {
        if isListening {
            finishListeningWithCurrentTranscript()
            return
        }

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            onError(.speechUnavailable)
            return
        }

        let currentSpeechStatus = SFSpeechRecognizer.authorizationStatus()
        if currentSpeechStatus != .notDetermined,
           let problem = VoicePermissionPreflight.speechProblem(for: currentSpeechStatus) {
            onError(problem)
            return
        }

        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if let problem = VoicePermissionPreflight.speechProblem(for: authStatus) {
                    onError(problem)
                    return
                }

                self.requestMicrophoneAccess {
                    self.startRecording(completion: completion, onError: onError)
                } onDenied: {
                    onError(.microphoneDenied)
                }
            }
        }
    }

    func stopListening() {
        finishListeningWithCurrentTranscript()
    }
    
    private func requestMicrophoneAccess(onAllowed: @escaping () -> Void, onDenied: @escaping () -> Void) {
        #if os(iOS)
        switch currentMicrophonePermissionState() {
        case .granted:
            onAllowed()
            return
        case .denied:
            onDenied()
            return
        case .undetermined:
            break
        }

        let permissionHandler: (Bool) -> Void = { allowed in
            DispatchQueue.main.async {
                allowed ? onAllowed() : onDenied()
            }
        }

        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: permissionHandler)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(permissionHandler)
        }
        #else
        onAllowed()
        #endif
    }

    #if os(iOS)
    private func currentMicrophonePermissionState() -> VoiceMicrophonePermissionState {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return .granted
            case .denied:
                return .denied
            case .undetermined:
                return .undetermined
            @unknown default:
                return .denied
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                return .granted
            case .denied:
                return .denied
            case .undetermined:
                return .undetermined
            @unknown default:
                return .denied
            }
        }
    }
    #endif

    private func startRecording(
        completion: @escaping (String) -> Void,
        onError: @escaping (VoiceLogProblem) -> Void
    ) {
        // Cancel previous task
        stopRecording()
        latestTranscript = ""
        currentTranscript = ""
        didDeliverTranscript = false
        completionHandler = completion
        errorHandler = onError
        
        // Configure audio session (iOS only)
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            #if DEBUG
            print("Audio session setup failed: \(error)")
            #endif
            onError(.audioSessionFailed)
            return
        }
        #endif
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            #if DEBUG
            print("Unable to create recognition request")
            #endif
            onError(.recognitionRequestFailed)
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let transcript = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.latestTranscript = transcript
                    self.currentTranscript = transcript
                }

                if result.isFinal {
                    DispatchQueue.main.async {
                        self.deliverTranscript(transcript)
                    }
                }
            }
            
            if let error = error {
                #if DEBUG
                print("Speech recognition error: \(error)")
                #endif
                DispatchQueue.main.async {
                    guard self.isListening else { return }
                    if self.latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.errorHandler?(.recognitionStoppedBeforeTranscript)
                    } else {
                        self.finishListeningWithCurrentTranscript()
                        return
                    }
                    self.stopRecording()
                }
            }
        }
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        hasInstalledInputTap = true
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            #if DEBUG
            print("Audio engine failed to start: \(error)")
            #endif
            onError(.microphoneStartFailed)
            stopRecording()
        }
        
        // Auto-stop after 10 seconds
        let autoStopWorkItem = DispatchWorkItem { [weak self] in
            self?.finishListeningWithCurrentTranscript()
        }
        self.autoStopWorkItem = autoStopWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: autoStopWorkItem)
    }

    private func finishListeningWithCurrentTranscript() {
        let transcript = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if transcript.isEmpty {
            errorHandler?(.noTranscript)
            stopRecording()
            return
        }

        deliverTranscript(transcript)
    }

    private func deliverTranscript(_ transcript: String) {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !didDeliverTranscript, !trimmedTranscript.isEmpty else {
            stopRecording()
            return
        }

        didDeliverTranscript = true
        completionHandler?(trimmedTranscript)
        stopRecording()
    }
    
    private func stopRecording() {
        autoStopWorkItem?.cancel()
        autoStopWorkItem = nil
        isListening = false
        audioEngine.stop()
        if hasInstalledInputTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledInputTap = false
        }
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        completionHandler = nil
        errorHandler = nil
        
        // Deactivate audio session (iOS only)
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            #if DEBUG
            print("Failed to deactivate audio session: \(error)")
            #endif
        }
        #endif
    }
}

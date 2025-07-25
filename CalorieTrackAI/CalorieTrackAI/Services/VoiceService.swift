import Foundation
import Speech
import AVFoundation

class VoiceService: ObservableObject {
    static let shared = VoiceService()
    
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private init() {}
    
    func startListening(completion: @escaping (String) -> Void) {
        // Request permission
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.startRecording(completion: completion)
                case .denied, .restricted, .notDetermined:
                    #if DEBUG
                    print("Speech recognition not authorized")
                    #endif
                @unknown default:
                    #if DEBUG
                    print("Unknown speech recognition authorization status")
                    #endif
                }
            }
        }
    }
    
    private func startRecording(completion: @escaping (String) -> Void) {
        // Cancel previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
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
            return
        }
        #endif
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            #if DEBUG
            print("Unable to create recognition request")
            #endif
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let transcript = result.bestTranscription.formattedString
                if result.isFinal {
                    completion(transcript)
                    self.stopRecording()
                }
            }
            
            if let error = error {
                #if DEBUG
                print("Speech recognition error: \(error)")
                #endif
                self.stopRecording()
            }
        }
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            #if DEBUG
            print("Audio engine failed to start: \(error)")
            #endif
        }
        
        // Auto-stop after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.stopRecording()
        }
    }
    
    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
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
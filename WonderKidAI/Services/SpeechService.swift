import Foundation
import Speech
import AVFoundation
import AudioToolbox

enum SpeechPermissionState {
    case authorized
    case denied
    case notDetermined
}

class SpeechService: NSObject {
    static let shared = SpeechService()
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // 回調
    var onSpeechDetected: ((String, Bool) -> Void)?
    var onRecordingStarted: (() -> Void)?
    
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 1.5
    
    override private init() {
        super.init()
        // 初始化時預設語言
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW"))
    }

    func permissionState() -> SpeechPermissionState {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let recordStatus = AVAudioSession.sharedInstance().recordPermission
        
        if speechStatus == .authorized && recordStatus == .granted {
            return .authorized
        }
        
        if speechStatus == .denied || speechStatus == .restricted || recordStatus == .denied {
            return .denied
        }
        
        return .notDetermined
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var speechGranted = false
        var recordGranted = false
        
        group.enter()
        SFSpeechRecognizer.requestAuthorization { status in
            speechGranted = (status == .authorized)
            group.leave()
        }
        
        group.enter()
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            recordGranted = granted
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(speechGranted && recordGranted)
        }
    }
    
    // MARK: - 🔥 核心修正：統一的 AudioSession 設定
    // (這就是 Xcode 說找不到的那個功能，現在補上了！)
    func configureAudioSession(isRecording: Bool) {
        do {
            let session = AVAudioSession.sharedInstance()
            if isRecording {
                // 錄音模式：同時允許播放與錄音，並強制聲音從喇叭出來
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            } else {
                // 播放模式：專注於播放
                try session.setCategory(.playback, mode: .default)
            }
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Audio Session 設定失敗: \(error)")
        }
    }
    
    func startRecording(language: AppLanguage) throws {
        stopRecording() // 先確保之前的清理乾淨
        
        // 1. 設定音訊環境
        configureAudioSession(isRecording: true)
        
        #if DEBUG
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        print("[STT] authStatus=\(authStatus.rawValue)")
        #endif
        
        // 2. 播放提示音 (1113: Begin Recording)
        AudioServicesPlaySystemSound(1113)
        
        // 🇯🇵 支援三種語言
        let localeID: String
        switch language {
        case .chinese:
            localeID = "zh-TW"
        case .english:
            localeID = "en-US"
        case .japanese:
            localeID = "ja-JP"
        }
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID))
        #if DEBUG
        if speechRecognizer?.isAvailable == false {
            print("[STT] recognizer unavailable for locale=\(localeID)")
        }
        #endif
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        // 模擬器防呆與格式設定
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        var formatToUse = recordingFormat
        if recordingFormat.sampleRate == 0 {
            if let fallbackFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) {
                formatToUse = fallbackFormat
            }
        }
        
        // 3. 設定辨識任務
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            var isFinal = false
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                // 確保回調在主線程
                DispatchQueue.main.async {
                    self.onSpeechDetected?(text, false)
                    self.resetSilenceTimer()
                }
                isFinal = result.isFinal
            }
            
            if let error = error {
                #if DEBUG
                print("[STT] recognition error: \(error)")
                #endif
            }
            
            if error != nil || isFinal {
                self.stopRecording()
            }
        }
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: formatToUse) { (buffer, _) in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        print("🎙️ 麥克風已啟動")
        DispatchQueue.main.async {
            self.onRecordingStarted?()
        }
    }
    
    func stopRecording() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            AudioServicesPlaySystemSound(1114) // End Recording Sound
        }
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil // 釋放請求
        
        print("🛑 錄音結束")
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        DispatchQueue.main.async {
            self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceThreshold, repeats: false) { [weak self] _ in
                // 時間到，視為一句話結束 (True)
                self?.onSpeechDetected?("", true)
                self?.stopRecording()
            }
        }
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }
}

import SwiftUI
import AVFoundation

struct ContentView: View {
    // MARK: - 狀態變數
    @State private var selectedLanguage: AppLanguage = .chinese
    @State private var aiResponse: String = "嗨！我是安安老師～\n小朋友你想知道什麼呢？"
    
    // 狀態機
    @State private var isRecording: Bool = false
    @State private var isPreparingRecording: Bool = false
    @State private var isThinking: Bool = false
    @State private var userSpokenText: String = ""
    
    // 連線狀態 (nil=檢查中, true=成功, false=失敗)
    @State private var isServerConnected: Bool? = nil
    
    @State private var audioPlayer: AVAudioPlayer?
    @State private var textTimer: Timer?
    @State private var currentWordIndex: Int = 0
    @State private var characterData: [(char: String, bopomofo: String)] = []
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.CreamWhite, Color.SoftBlue]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // --- 頂部導覽列 ---
                HStack {
                    // ✅ 修改：可愛版連線狀態膠囊
                    Button(action: {
                        // 點擊可以手動喚醒/重新檢查
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        checkServerStatus()
                    }) {
                        HStack(spacing: 6) {
                            // 動態圖示
                            Image(systemName: isServerConnected == true ? "person.wave.2.fill" : (isServerConnected == false ? "moon.zzz.fill" : "antenna.radiowaves.left.and.right"))
                                .font(.system(size: 14))
                                .foregroundColor(isServerConnected == true ? .green : (isServerConnected == false ? .gray : .orange))
                            
                            // 擬人化文字
                            Text(statusText)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(isServerConnected == true ? .DarkText : .gray)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                    
                    Spacer()
                    
                    // 語言切換按鈕
                    HStack(spacing: 0) {
                        LanguageButton(title: "中", isSelected: selectedLanguage == .chinese) {
                            selectedLanguage = .chinese
                        }
                        LanguageButton(title: "En", isSelected: selectedLanguage == .english) {
                            selectedLanguage = .english
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                Spacer()
                
                // --- 中間視覺區 ---
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 160, height: 160)
                        .shadow(color: Color.white.opacity(0.5), radius: 20)
                    
                    // 思考光環 (轉圈圈)
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(LinearGradient(gradient: Gradient(colors: [.purple, .blue]), startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 140, height: 140)
                        .rotationEffect(Angle(degrees: isThinking ? 360 : 0))
                        .animation(isThinking ? Animation.linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: isThinking)
                        .opacity(isThinking ? 1 : 0)
                    
                    // 聆聽光環 (放大縮小)
                    Circle()
                        .stroke(Color.ButtonRed.opacity(0.5), lineWidth: 8)
                        .frame(width: 140, height: 140)
                        .scaleEffect(isRecording ? 1.1 : 1.0)
                        .opacity(isRecording ? 1 : 0)
                        .animation(isRecording ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isRecording)
                    
                    // 中央圖示
                    Image(systemName: isThinking ? "book.fill" : (isRecording ? "mic.circle.fill" : "book.closed.fill"))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .foregroundColor(isRecording ? Color.ButtonRed : Color.MagicBlue)
                        .shadow(radius: 5)
                }
                .padding(.vertical, 20)
                
                // --- 底部區 ---
                VStack(spacing: 20) {
                    
                    // 📝 字幕區
                    ScrollViewReader { proxy in
                        ScrollView {
                            // 🅰️ 錄音模式
                            if isRecording || isPreparingRecording {
                                Text(userSpokenText)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(isPreparingRecording ? .gray : .ButtonRed)
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(10)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("UserText")
                                
                            } else {
                                // 🅱️ AI 回答模式 (注音方塊)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 38), spacing: 2)], alignment: .leading, spacing: 10) {
                                    ForEach(Array(characterData.enumerated()), id: \.offset) { index, item in
                                        VStack(spacing: 0) {
                                            if !item.bopomofo.isEmpty {
                                                Text(item.bopomofo)
                                                    .font(.system(size: 10, weight: .regular))
                                                    .foregroundColor(index < currentWordIndex ? .MagicBlue : .gray.opacity(0.5))
                                                    .fixedSize()
                                            }
                                            Text(item.char)
                                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                                .foregroundColor(index < currentWordIndex ? .MagicBlue : .gray.opacity(0.4))
                                        }
                                        .id(index)
                                        .frame(minWidth: 38)
                                        .scaleEffect(index == currentWordIndex - 1 ? 1.2 : 1.0)
                                        .animation(.spring(response: 0.3), value: currentWordIndex)
                                    }
                                }
                                .padding()
                            }
                        }
                        // iOS 17+ 寫法
                        .onChange(of: currentWordIndex) { _, newIndex in
                            if newIndex > 0 {
                                withAnimation { proxy.scrollTo(newIndex, anchor: .center) }
                            }
                        }
                        .onChange(of: userSpokenText) { _, _ in
                            if isRecording {
                                withAnimation { proxy.scrollTo("UserText", anchor: .bottom) }
                            }
                        }
                    }
                    .frame(height: 300)
                    .background(Color.white)
                    .cornerRadius(25)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 24)
                    
                    // 麥克風按鈕
                    Button(action: {
                        if isRecording {
                            manualStop()
                        } else {
                            startListening()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(gradient: Gradient(colors: isThinking ? [Color.gray] : [Color.ButtonOrange, Color.ButtonRed]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 90, height: 90)
                                .shadow(color: isThinking ? Color.gray.opacity(0.4) : Color.ButtonRed.opacity(0.4), radius: 15, x: 0, y: 8)
                                .scaleEffect(isRecording ? 1.1 : 1.0)
                            
                            Image(systemName: isThinking ? "ellipsis" : (isRecording ? "square.fill" : "mic.fill"))
                                .font(.system(size: 35))
                                .foregroundColor(.white)
                                .animation(.spring(), value: isRecording)
                        }
                    }
                    .disabled(isThinking || isPreparingRecording)
                    
                    Text(isPreparingRecording ? "準備中..." : (isRecording ? "安安老師在聽囉..." : "點一下，開始說話"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.gray.opacity(0.8))
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            SpeechService.shared.requestAuthorization()
            characterData = aiResponse.toBopomofoCharacter()
            checkServerStatus() // 啟動檢查
        }
    }
    
    // MARK: - 輔助邏輯
    
    // 狀態文字顯示邏輯
    var statusText: String {
        switch isServerConnected {
        case true:
            return "安安老師上線中"
        case false:
            return "老師休息中 (點我叫醒)"
        default:
            return "正在找老師..."
        }
    }
    
    func checkServerStatus() {
        isServerConnected = nil // 設定為檢查中(橘色)
        Task {
            let result = await OpenAIService.shared.checkConnection()
            await MainActor.run {
                withAnimation {
                    isServerConnected = result
                }
            }
        }
    }
    
    func startListening() {
        guard !isThinking && !isPreparingRecording else { return }
        
        stopAudio()
        
        isPreparingRecording = true
        isRecording = false
        userSpokenText = "..."
        currentWordIndex = 0
        
        SpeechService.shared.onRecordingStarted = {
            self.isPreparingRecording = false
            self.isRecording = true
            self.userSpokenText = "👂"
        }
        
        SpeechService.shared.onSpeechDetected = { text, isFinished in
            if isFinished {
                self.finishRecording()
            } else {
                if !text.isEmpty {
                    self.userSpokenText = text
                }
            }
        }
        
        do {
            try SpeechService.shared.startRecording(language: selectedLanguage)
        } catch {
            userSpokenText = "❌ 啟動失敗"
            isPreparingRecording = false
            isRecording = false
        }
    }
    
    func manualStop() {
        SpeechService.shared.stopRecording()
        finishRecording()
    }
    
    func finishRecording() {
        guard isRecording else { return }
        isRecording = false
        isPreparingRecording = false
        
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        if userSpokenText == "👂" || userSpokenText.isEmpty || userSpokenText == "..." {
            userSpokenText = "🤔 太小聲囉～"
            return
        }
        
        Task { await sendToAI(question: userSpokenText) }
    }
    
    func sendToAI(question: String) async {
        isThinking = true
        do {
            let answer = try await OpenAIService.shared.processMessage(
                userMessage: question,
                language: selectedLanguage
            )
            
            await MainActor.run {
                aiResponse = answer
                currentWordIndex = 0
                characterData = answer.toBopomofoCharacter()
            }
            
            let audioData = try await OpenAIService.shared.generateAudio(from: answer)
            await playAudio(data: audioData, textToRead: answer)
            
        } catch {
            await MainActor.run {
                aiResponse = "❌ 連線錯誤: \(error.localizedDescription)"
                isThinking = false
            }
        }
    }
    
    @MainActor
    func playAudio(data: Data, textToRead: String) async {
        do {
            stopAudio()
            SpeechService.shared.configureAudioSession(isRecording: false)
            
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
            
            isThinking = false
            
            let duration = audioPlayer?.duration ?? 0
            guard duration > 0 else { return }
            
            let charCount = Double(textToRead.count)
            let timePerChar = (duration / charCount)
            
            textTimer = Timer.scheduledTimer(withTimeInterval: timePerChar, repeats: true) { timer in
                if currentWordIndex < textToRead.count {
                    currentWordIndex += 1
                } else {
                    timer.invalidate()
                }
            }
        } catch {
            print("❌ 播放失敗: \(error)")
            isThinking = false
        }
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        textTimer?.invalidate()
        textTimer = nil
    }
}

// MARK: - 輔助元件與擴充
struct LanguageButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .foregroundColor(isSelected ? .white : Color.gray.opacity(0.8))
                .background(isSelected ? Color.MagicBlue : Color.clear)
                .cornerRadius(20)
        }
    }
}

extension Color {
    static let CreamWhite = Color(red: 1.0, green: 0.99, blue: 0.96)
    static let SoftBlue = Color(red: 0.92, green: 0.96, blue: 1.0)
    static let MagicBlue = Color(red: 0.3, green: 0.5, blue: 0.9)
    static let ButtonOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let ButtonRed = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let DarkText = Color(red: 0.2, green: 0.2, blue: 0.3)
}

extension String {
    func toBopomofoCharacter() -> [(char: String, bopomofo: String)] {
        var result: [(String, String)] = []
        for char in self {
            let text = String(char)
            if text.rangeOfCharacter(from: .whitespacesAndNewlines) != nil ||
               text.rangeOfCharacter(from: .punctuationCharacters) != nil {
                result.append((text, ""))
                continue
            }
            let mutableString = NSMutableString(string: text)
            CFStringTransform(mutableString, nil, kCFStringTransformMandarinLatin, false)
            CFStringTransform(mutableString, nil, "Latin-Bopomofo" as CFString, false)
            let bopomofo = String(mutableString)
            result.append((text, bopomofo))
        }
        return result
    }
}

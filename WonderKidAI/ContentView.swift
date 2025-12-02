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
    @State private var isPlaying: Bool = false
    @State private var userSpokenText: String = ""
    
    // 連線狀態
    @State private var isServerConnected: Bool? = nil
    
    // 播放與文字進度
    @State private var audioPlayer: AVAudioPlayer?
    @State private var textTimer: Timer?
    @State private var currentWordIndex: Int = 0
    @State private var currentSentenceIndex: Int = 0
    @State private var isUserScrolling: Bool = false
    
    // 資料源
    @State private var characterData: [(char: String, bopomofo: String)] = []
    @State private var englishSentences: [String] = []
    
    let aiListeningSymbol = "✨🤖✨"
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MARK: - 1. 背景層
                Image("KnowledgeBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()
                    .opacity(0.3)
                
                LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.85), Color.SoftBlue.opacity(0.6)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // MARK: - 2. 前景內容層
                VStack(spacing: 0) {
                    
                    // --- A. 頂部導覽列 ---
                    HStack {
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            checkServerStatus()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: isServerConnected == true ? "person.wave.2.fill" : (isServerConnected == false ? "moon.zzz.fill" : "antenna.radiowaves.left.and.right"))
                                    .font(.system(size: 14))
                                    .foregroundColor(isServerConnected == true ? .green : (isServerConnected == false ? .gray : .orange))
                                
                                Text(statusText)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(isServerConnected == true ? .DarkText : .gray)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 0) {
                            LanguageButton(title: "中", isSelected: selectedLanguage == .chinese) {
                                switchLanguage(to: .chinese)
                            }
                            LanguageButton(title: "En", isSelected: selectedLanguage == .english) {
                                switchLanguage(to: .english)
                            }
                        }
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // --- B. 中間視覺區 ---
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: geometry.size.width * 0.45, height: geometry.size.width * 0.45)
                            .shadow(color: Color.white.opacity(0.6), radius: 20)
                        
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(LinearGradient(gradient: Gradient(colors: [.purple, .blue]), startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: geometry.size.width * 0.4, height: geometry.size.width * 0.4)
                            .rotationEffect(Angle(degrees: isThinking ? 360 : 0))
                            .animation(isThinking ? Animation.linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: isThinking)
                            .opacity(isThinking ? 1 : 0)
                        
                        Circle()
                            .stroke(Color.ButtonRed.opacity(0.5), lineWidth: 8)
                            .frame(width: geometry.size.width * 0.4, height: geometry.size.width * 0.4)
                            .scaleEffect(isRecording ? 1.1 : 1.0)
                            .opacity(isRecording ? 1 : 0)
                            .animation(isRecording ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isRecording)
                        
                        Image(systemName: isThinking ? "book.fill" : (isRecording ? "waveform.circle.fill" : "book.closed.fill"))
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width * 0.2)
                            .foregroundColor(isRecording ? Color.ButtonRed : Color.MagicBlue)
                            .shadow(radius: 5)
                    }
                    .padding(.vertical, 10)
                    
                    Spacer()
                    
                    // --- C. 底部區 (重點修改) ---
                    VStack(spacing: 20) {
                        
                        // 1. 字幕框
                        ZStack(alignment: .bottom) {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    if isThinking {
                                        ThinkingAnimationView(language: selectedLanguage)
                                            .frame(maxWidth: .infinity, minHeight: 120)
                                    } else if isRecording || isPreparingRecording {
                                        Text(userSpokenText)
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                            .foregroundColor(isPreparingRecording ? .gray : .ButtonRed)
                                            .multilineTextAlignment(.center)
                                            .lineSpacing(10)
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .id("UserText")
                                    } else {
                                        if selectedLanguage == .chinese {
                                            // 🇹🇼 中文模式
                                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 38), spacing: 2)], alignment: .leading, spacing: 10) {
                                                ForEach(Array(characterData.enumerated()), id: \.offset) { index, item in
                                                    VStack(spacing: 0) {
                                                        if !item.bopomofo.isEmpty {
                                                            Text(item.bopomofo)
                                                                .font(.system(size: 10, weight: .regular))
                                                                .foregroundColor(index < currentWordIndex ? .MagicBlue : .gray.opacity(0.6))
                                                                .fixedSize()
                                                        }
                                                        Text(item.char)
                                                            .font(.system(size: 26, weight: .bold, design: .rounded))
                                                            .foregroundColor(index < currentWordIndex ? .MagicBlue : .gray.opacity(0.5))
                                                    }
                                                    .id(index)
                                                    .frame(minWidth: 38)
                                                    .scaleEffect(index == currentWordIndex - 1 ? 1.2 : 1.0)
                                                    .animation(.spring(response: 0.3), value: currentWordIndex)
                                                }
                                            }
                                            .padding()
                                        } else {
                                            // 🇺🇸 英文模式：卡片式列表 (Story Cards)
                                            VStack(spacing: 12) {
                                                ForEach(Array(englishSentences.enumerated()), id: \.offset) { index, sentence in
                                                    let isActive = (index == currentSentenceIndex)
                                                    
                                                    Text(sentence)
                                                        .font(.system(size: isActive ? 20 : 18, weight: isActive ? .bold : .regular, design: .rounded))
                                                        .foregroundColor(isActive ? .DarkText : .gray.opacity(0.7))
                                                        .multilineTextAlignment(.leading)
                                                        .padding()
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                        .background(isActive ? Color.white : Color.white.opacity(0.5))
                                                        .cornerRadius(16)
                                                        .shadow(color: Color.black.opacity(isActive ? 0.1 : 0), radius: 4, x: 0, y: 2)
                                                        .scaleEffect(isActive ? 1.02 : 1.0) // 唸到的卡片稍微放大
                                                        .animation(.spring(), value: isActive)
                                                        .id("Sentence-\(index)")
                                                        .onTapGesture {
                                                            // 小朋友手動點擊卡片時
                                                            isUserScrolling = true
                                                        }
                                                }
                                            }
                                            .padding()
                                            // 預留底部空間，讓最後一張卡片能被完整看到
                                            .padding(.bottom, 40)
                                        }
                                    }
                                }
                                // 偵測手指滑動
                                .simultaneousGesture(DragGesture().onChanged { _ in
                                    isUserScrolling = true
                                })
                                .onChange(of: currentWordIndex) { _, newIndex in
                                    if selectedLanguage == .chinese && newIndex > 0 && !isUserScrolling {
                                        withAnimation { proxy.scrollTo(newIndex, anchor: .center) }
                                    }
                                }
                                .onChange(of: currentSentenceIndex) { _, newIndex in
                                    // 英文：只有當不是手動滑動時，才自動聚焦
                                    if selectedLanguage == .english && !isUserScrolling {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            proxy.scrollTo("Sentence-\(newIndex)", anchor: .center)
                                        }
                                    }
                                }
                                .onChange(of: userSpokenText) { _, _ in
                                    if isRecording { withAnimation { proxy.scrollTo("UserText", anchor: .bottom) } }
                                }
                            }
                            
                            // 🔥 滑動提示 (Scroll Hint)
                            // 如果是英文版、文章較長、且還沒捲到底，顯示這個可愛的跳動箭頭
                            if selectedLanguage == .english && englishSentences.count > 2 && currentSentenceIndex < englishSentences.count - 1 && !isUserScrolling {
                                VStack {
                                    Spacer()
                                    Image(systemName: "chevron.down.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.MagicBlue.opacity(0.6))
                                        .padding(.bottom, 10)
                                        .opacity(isPlaying ? 0 : 1) // 播放時隱藏，暫停閱讀時顯示
                                }
                                .transition(.opacity)
                            }
                            
                            // 🔥 找回進度按鈕 (當小朋友自己滑走時顯示)
                            if isUserScrolling && isPlaying {
                                Button(action: {
                                    isUserScrolling = false // 點擊後恢復自動追蹤
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "location.fill")
                                        Text(selectedLanguage == .chinese ? "唸到這" : "Focus")
                                            .font(.caption).bold()
                                    }
                                    .padding(8)
                                    .background(Color.MagicBlue)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                                    .shadow(radius: 3)
                                }
                                .padding(12)
                            }
                        }
                        .frame(height: geometry.size.height * 0.33)
                        .background(Color.white.opacity(0.8)) // 背景稍微透明一點，讓卡片更明顯
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 24)
                        
                        // 2. 按鈕區
                        ZStack {
                            if isPlaying {
                                HStack {
                                    Button(action: { interruptAndListen() }) {
                                        ZStack {
                                            Circle().fill(Color.ButtonRed).frame(width: 60, height: 60)
                                                .shadow(color: Color.ButtonRed.opacity(0.4), radius: 10, x: 0, y: 5)
                                            Image(systemName: "hand.raised.fill").font(.system(size: 24)).foregroundColor(.white)
                                        }
                                    }
                                    .padding(.leading, 30)
                                    .transition(.scale)
                                    Spacer()
                                }
                            }
                            
                            Button(action: {
                                if isRecording { manualStop() } else { startListening() }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(gradient: Gradient(colors: isThinking ? [Color.gray] : [Color.ButtonOrange, Color.ButtonRed]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 80, height: 80)
                                        .shadow(color: isThinking ? Color.gray.opacity(0.4) : Color.ButtonRed.opacity(0.4), radius: 15, x: 0, y: 8)
                                        .scaleEffect(isRecording ? 1.1 : 1.0)
                                    
                                    Image(systemName: isThinking ? "ellipsis" : (isRecording ? "square.fill" : "mic.fill"))
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                        .animation(.spring(), value: isRecording)
                                }
                            }
                            .disabled(isThinking || isPreparingRecording)
                            
                            if !isRecording && !isThinking && !isPreparingRecording && aiResponse.count > 20 && !isPlaying {
                                HStack {
                                    Spacer()
                                    Button(action: { askExplainAgain() }) {
                                        VStack(spacing: 4) {
                                            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 20))
                                            Text(selectedLanguage == .chinese ? "聽不懂" : "Again").font(.system(size: 10, weight: .bold))
                                        }
                                        .foregroundColor(.white).padding(10).background(Color.MagicBlue).clipShape(Circle()).shadow(radius: 3)
                                    }
                                    .padding(.trailing, 40)
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .animation(.spring(), value: isPlaying)
                        
                        Text(hintText)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.gray.opacity(0.9))
                        
                        Text(selectedLanguage == .chinese ? "資料來源：維基百科" : "Data Source: Wikipedia")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.bottom, 60)
                    }
                    .padding(.bottom, 10)
                }
            }
        }
        .onAppear {
            SpeechService.shared.requestAuthorization()
            updateContentData()
            checkServerStatus()
        }
    }
    
    // MARK: - 邏輯區
    
    func updateContentData() {
        if selectedLanguage == .chinese {
            characterData = aiResponse.toBopomofoCharacter()
        } else {
            // 英文斷句邏輯：用標點符號切割，保留完整句子結構
            let rawSentences = aiResponse
                .replacingOccurrences(of: ". ", with: ".|")
                .replacingOccurrences(of: "? ", with: "?|")
                .replacingOccurrences(of: "! ", with: "!|")
                .split(separator: "|")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            englishSentences = rawSentences.isEmpty ? [aiResponse] : rawSentences
        }
    }
    
    func calculateCurrentSentence(charIndex: Int) {
        var count = 0
        for (index, sentence) in englishSentences.enumerated() {
            count += sentence.count + 1 // +1 是因為原本有空格
            if count >= charIndex {
                if currentSentenceIndex != index {
                    currentSentenceIndex = index
                }
                return
            }
        }
    }
    
    func interruptAndListen() {
        stopAudio()
        isThinking = false
        userSpokenText = "..."
        startListening()
    }
    
    func askExplainAgain() {
        let prompt = selectedLanguage == .chinese ?
            "請用更簡單、更生動的比喻，再解釋一次剛剛的內容，就像講故事給 5 歲小朋友聽一樣。" :
            "Please explain that again in a much simpler way, use analogies, like telling a story to a 5-year-old."
        userSpokenText = selectedLanguage == .chinese ? "🔄 老師，可以講簡單一點嗎？" : "🔄 Teacher, simpler please?"
        Task { await sendToAI(question: prompt) }
    }
    
    func switchLanguage(to lang: AppLanguage) {
        selectedLanguage = lang
        if lang == .chinese {
            aiResponse = "嗨！我是安安老師～\n小朋友你想知道什麼呢？"
        } else {
            aiResponse = "Hi! I am Teacher An-An.\nWhat would you like to know?"
        }
        updateContentData()
    }
    
    var statusText: String {
        if selectedLanguage == .chinese {
            switch isServerConnected {
            case true: return "安安老師上線中"
            case false: return "老師休息中 (點我叫醒)"
            default: return "正在找老師..."
            }
        } else {
            switch isServerConnected {
            case true: return "Teacher An-An is Online"
            case false: return "Teacher is Sleeping (Tap)"
            default: return "Connecting..."
            }
        }
    }
    
    var hintText: String {
        if isPlaying {
            return selectedLanguage == .chinese ? "點紅色手手可以打斷老師喔！" : "Tap the red hand to interrupt!"
        }
        if selectedLanguage == .chinese {
            return isPreparingRecording ? "準備中..." : (isRecording ? "安安老師在聽囉..." : "點一下，開始說話")
        } else {
            return isPreparingRecording ? "Preparing..." : (isRecording ? "I'm listening..." : "Tap to speak")
        }
    }
    
    func checkServerStatus() {
        isServerConnected = nil
        Task {
            let result = await OpenAIService.shared.checkConnection()
            await MainActor.run { withAnimation { isServerConnected = result } }
        }
    }
    
    func startListening() {
        guard !isThinking && !isPreparingRecording else { return }
        stopAudio()
        isPreparingRecording = true
        isRecording = false
        userSpokenText = "..."
        currentWordIndex = 0
        currentSentenceIndex = 0
        isUserScrolling = false
        
        SpeechService.shared.onRecordingStarted = {
            self.isPreparingRecording = false
            self.isRecording = true
            self.userSpokenText = self.aiListeningSymbol
        }
        
        SpeechService.shared.onSpeechDetected = { text, isFinished in
            if isFinished {
                self.finishRecording()
            } else {
                if !text.isEmpty { self.userSpokenText = text }
            }
        }
        
        do {
            try SpeechService.shared.startRecording(language: selectedLanguage)
        } catch {
            userSpokenText = selectedLanguage == .chinese ? "❌ 啟動失敗" : "❌ Start Failed"
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
        if userSpokenText == aiListeningSymbol || userSpokenText.isEmpty || userSpokenText == "..." {
            userSpokenText = selectedLanguage == .chinese ? "🤔 太小聲囉～" : "🤔 Too quiet~"
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
                currentSentenceIndex = 0
                isUserScrolling = false
                updateContentData()
            }
            let audioData = try await OpenAIService.shared.generateAudio(from: answer)
            await playAudio(data: audioData, textToRead: answer)
        } catch {
            await MainActor.run {
                aiResponse = selectedLanguage == .chinese ? "❌ 連線錯誤: \(error.localizedDescription)" : "❌ Connection Error"
                isThinking = false
                updateContentData()
            }
        }
    }
    
    @MainActor
    func playAudio(data: Data, textToRead: String) async {
        do {
            stopAudio()
            isPlaying = true
            isUserScrolling = false
            SpeechService.shared.configureAudioSession(isRecording: false)
            
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
            
            isThinking = false
            
            let totalChars = textToRead.count
            
            textTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                guard let player = self.audioPlayer else {
                    timer.invalidate()
                    return
                }
                
                if player.isPlaying {
                    let percentage = player.currentTime / player.duration
                    let charIndex = Int(Double(totalChars) * percentage)
                    self.currentWordIndex = min(charIndex, totalChars)
                    
                    if self.selectedLanguage == .english {
                        calculateCurrentSentence(charIndex: charIndex)
                    }
                } else {
                    timer.invalidate()
                    self.currentWordIndex = totalChars
                    self.isPlaying = false
                }
            }
        } catch {
            print("❌ Playback failed: \(error)")
            isThinking = false
            isPlaying = false
        }
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        textTimer?.invalidate()
        textTimer = nil
        isPlaying = false
    }
}

// MARK: - 輔助元件 (無需變動)
struct ThinkingAnimationView: View {
    let language: AppLanguage
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.MagicBlue.opacity(0.6))
                        .frame(width: 12, height: 12)
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .opacity(isAnimating ? 1.0 : 0.3)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            Text(language == .chinese ? "安安老師正在翻書找答案..." : "Checking the magic book...")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.gray.opacity(0.8))
        }
        .onAppear { isAnimating = true }
    }
}

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
            let finalBopomofo = (bopomofo == text) ? "" : bopomofo
            result.append((text, finalBopomofo))
        }
        return result
    }
}

import SwiftUI
import AVFoundation
import RevenueCat
import RevenueCatUI

struct ContentView: View {
    // MARK: - 系統環境變數
    @Environment(\.scenePhase) var scenePhase
    
    // MARK: - 狀態變數
    @State private var selectedLanguage: AppLanguage = Locale.current.identifier.hasPrefix("zh") ? .chinese : .english
    @State private var aiResponse: String = "嗨！我是安安老師～\n小朋友你想知道什麼呢？"
    
    // 記憶介紹狀態
    @State private var hasPlayedChineseIntro: Bool = false
    @State private var hasPlayedEnglishIntro: Bool = false
    
    // 付費牆控制
    @State private var showPaywall: Bool = false
    @State private var isPro: Bool = false
    
    // 狀態機
    @State private var isRecording: Bool = false
    @State private var isPreparingRecording: Bool = false
    @State private var isThinking: Bool = false
    @State private var isPlaying: Bool = false
    @State private var userSpokenText: String = ""
    @State private var lastQuestion: String = ""
    
    // 任務與頁面控制
    @State private var currentTask: Task<Void, Never>?
    @State private var isServerConnected: Bool? = nil
    @State private var showHistory: Bool = false
    @State private var showPrivacy: Bool = false
    @State private var showEULA: Bool = false
    
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
                // 背景層
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
               
                // 前景內容層
                VStack(spacing: 0) {
                    // --- 頂部導覽列 ---
                    HStack {
                        // 足跡按鈕
                        Button(action: { showHistory = true }) {
                            VStack(spacing: 2) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 18))
                                Text(selectedLanguage == .chinese ? "足跡" : "History")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.9))
                            .foregroundColor(.MagicBlue)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        }
                        
                        Spacer()
                        
                        // 連線狀態
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            withAnimation { isServerConnected = nil }
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
                       
                        // 語言切換
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
                   
                    // --- 中間視覺區 ---
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
                   
                    // --- 底部區 ---
                    VStack(spacing: 20) {
                        // 字幕框
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
                                                        .scaleEffect(isActive ? 1.02 : 1.0)
                                                        .animation(.spring(), value: isActive)
                                                        .id("Sentence-\(index)")
                                                        .onTapGesture { isUserScrolling = true }
                                                }
                                            }
                                            .padding()
                                            .padding(.bottom, 40)
                                        }
                                    }
                                }
                                .simultaneousGesture(DragGesture().onChanged { _ in isUserScrolling = true })
                                .onChange(of: currentWordIndex) { _, newIndex in
                                    if selectedLanguage == .chinese && newIndex > 0 && !isUserScrolling {
                                        withAnimation { proxy.scrollTo(newIndex, anchor: .center) }
                                    }
                                }
                                .onChange(of: currentSentenceIndex) { _, newIndex in
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
                           
                            if selectedLanguage == .english && englishSentences.count > 2 && currentSentenceIndex < englishSentences.count - 1 && !isUserScrolling {
                                VStack {
                                    Spacer()
                                    Image(systemName: "chevron.down.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.MagicBlue.opacity(0.6))
                                        .padding(.bottom, 10)
                                        .opacity(isPlaying ? 0 : 1)
                                }
                                .transition(.opacity)
                            }
                           
                            if isUserScrolling && isPlaying {
                                Button(action: { isUserScrolling = false }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "location.fill")
                                        Text(selectedLanguage == .chinese ? "唸到這" : "Focus").font(.caption).bold()
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
                        .background(Color.white.opacity(0.95))
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 24)
                       
                        // 按鈕區
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
                           
                            // 主按鈕 (整合 Paywall 檢查)
                            Button(action: {
                                if isThinking {
                                    cancelThinking()
                                } else if isRecording {
                                    manualStop()
                                } else {
                                    startListening()
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(gradient: Gradient(colors: isThinking ? [Color.ButtonRed] : (isRecording ? [Color.ButtonRed] : [Color.ButtonOrange, Color.ButtonRed])), startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 80, height: 80)
                                        .shadow(color: (isThinking || isRecording) ? Color.ButtonRed.opacity(0.4) : Color.ButtonRed.opacity(0.4), radius: 15, x: 0, y: 8)
                                        .scaleEffect(isRecording ? 1.1 : 1.0)
                                   
                                    Image(systemName: isThinking ? "xmark" : (isRecording ? "square.fill" : "mic.fill"))
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                        .animation(.spring(), value: isRecording)
                                        .animation(.spring(), value: isThinking)
                                }
                            }
                            .disabled(isPreparingRecording)
                           
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
                       
                        // 資料來源與法律條款
                        VStack(spacing: 10) {
                            Text(selectedLanguage == .chinese ? "資料來源：維基百科" : "Data Source: Wikipedia")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red.opacity(0.8))
                            
                            HStack(spacing: 15) {
                                Button(action: { showPrivacy = true }) {
                                    Text(selectedLanguage == .chinese ? "隱私權政策" : "Privacy Policy")
                                        .font(.system(size: 11, weight: .medium))
                                        .underline()
                                        .foregroundColor(.MagicBlue)
                                }
                                Text("|").font(.system(size: 11)).foregroundColor(.MagicBlue.opacity(0.5))
                                Button(action: { showEULA = true }) {
                                    Text("EULA")
                                        .font(.system(size: 11, weight: .medium))
                                        .underline()
                                        .foregroundColor(.MagicBlue)
                                }
                            }
                        }
                        .padding(.bottom, 50)
                    }
                    .padding(.bottom, 10)
                }
                .blur(radius: isServerConnected == nil ? 5 : 0)
               
                // 載入遮罩
                if isServerConnected == nil {
                    LoadingCoverView()
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                        .zIndex(100)
                }
            }
            .sheet(isPresented: $showHistory) { HistoryView(isPresented: $showHistory, language: selectedLanguage) }
            .sheet(isPresented: $showPrivacy) { LegalView(type: .privacy, language: selectedLanguage, isPresented: $showPrivacy) }
            .sheet(isPresented: $showEULA) { LegalView(type: .eula, language: selectedLanguage, isPresented: $showEULA) }
            
            // 🔥 付費牆 (Paywall)
            .sheet(isPresented: $showPaywall) {
                PaywallView(displayCloseButton: true)
                    .onPurchaseCompleted { customerInfo in
                        self.isPro = customerInfo.entitlements["pro"]?.isActive == true
                        self.showPaywall = false
                        print("🎉 購買成功！")
                    }
                    .onRestoreCompleted { customerInfo in
                        self.isPro = customerInfo.entitlements["pro"]?.isActive == true
                        if self.isPro {
                            self.showPaywall = false
                            print("🎉 恢復購買成功！")
                        }
                    }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                print("💤 App 進入背景，重置自我介紹記憶")
                hasPlayedChineseIntro = false
                hasPlayedEnglishIntro = false
            }
        }
        .onAppear {
            SpeechService.shared.requestAuthorization()
            updateContentData()
            checkServerStatus()

            Purchases.shared.getCustomerInfo { (info, error) in
                if let info = info {
                    self.isPro = info.entitlements["pro"]?.isActive == true
                    print("👀 current entitlements:", info.entitlements.all.keys)
                }
            }
        }
    }
    
    // MARK: - 邏輯區
    
    func updateContentData() {
        if selectedLanguage == .chinese {
            characterData = aiResponse.toBopomofoCharacter()
        } else {
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
            count += sentence.count + 1
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
    
    func cancelThinking() {
        print("🛑 使用者手動取消思考")
        currentTask?.cancel()
        isThinking = false
        aiResponse = selectedLanguage == .chinese ? "好喔！那我先暫停～" : "Okay! Cancelled."
        updateContentData()
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    func askExplainAgain() {
        let needsIntro = (selectedLanguage == .chinese && !hasPlayedChineseIntro) ||
                         (selectedLanguage == .english && !hasPlayedEnglishIntro)
        
        if needsIntro {
            playIntroMessage()
            return
        }
        
        let questionToAsk = lastQuestion.isEmpty ? (selectedLanguage == .chinese ? "這個" : "this") : lastQuestion
        let prompt = selectedLanguage == .chinese ?
            "小朋友剛剛問：「\(questionToAsk)」。但他聽不懂剛才的解釋。請你換個方式，用更簡單、更生動的比喻，再解釋一次這個問題，就像講故事給 3-5 歲幼童聽一樣。" :
            "The child previously asked: \"\(questionToAsk)\". They didn't understand the explanation. Please explain this question again using much simpler analogies, like telling a story to a 3-5 year old."
        
        userSpokenText = selectedLanguage == .chinese ? "🔄 老師，可以講簡單一點嗎？" : "🔄 Teacher, simpler please?"
        sendToAI(question: prompt)
    }
    
    func playIntroMessage() {
        isThinking = true
        let introText: String
        if selectedLanguage == .chinese {
            introText = "嗨！我是安安老師，你的第一本 AI 百科全書。如果有自然、數學、地理、天文、語文、歷史，或是日常生活的問題，都可以問我喔！"
        } else {
            introText = "Hello! I am Teacher An-An, your first AI encyclopedia. You can ask me about nature, math, geography, space, history, or anything in your daily life. I am here to help you!"
        }
        
        userSpokenText = selectedLanguage == .chinese ? "👋 初次見面！" : "👋 Hello!"
        
        currentTask = Task {
            do {
                await MainActor.run {
                    aiResponse = introText
                    updateContentData()
                    isThinking = false
                }
                
                let cleanText = introText.cleanForTTS()
                let audioData = try await OpenAIService.shared.generateAudio(from: cleanText)
                await playAudio(data: audioData, textToRead: introText)
                
                if selectedLanguage == .chinese { hasPlayedChineseIntro = true }
                else { hasPlayedEnglishIntro = true }
                
            } catch {
                print("Intro TTS failed")
                isThinking = false
            }
        }
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
        if isThinking {
            return selectedLanguage == .chinese ? "點一下取消" : "Tap to cancel"
        }
        if selectedLanguage == .chinese {
            return isPreparingRecording ? "準備中..." : (isRecording ? "安安老師在聽囉..." : "點一下，開始說話")
        } else {
            return isPreparingRecording ? "Preparing..." : (isRecording ? "I'm listening..." : "Tap to speak")
        }
    }
    
    func checkServerStatus() {
        Task {
            let result = await OpenAIService.shared.checkConnection()
            await MainActor.run { withAnimation { isServerConnected = result } }
        }
    }
    
    func startListening() {
        // 🔥 檢查付費
        if !isPro {
            showPaywall = true
            return
        }
        
        guard !isThinking && !isPreparingRecording else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        
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
        lastQuestion = userSpokenText
        sendToAI(question: userSpokenText)
    }
    
    func sendToAI(question: String) {
        currentTask?.cancel()
        isThinking = true
        
        currentTask = Task {
            do {
                if Task.isCancelled { return }
                
                let answer = try await OpenAIService.shared.processMessage(
                    userMessage: question,
                    language: selectedLanguage
                )
                
                if Task.isCancelled { return }

                await MainActor.run {
                    HistoryManager.shared.addRecord(
                        question: question,
                        answer: answer,
                        language: selectedLanguage == .chinese ? "zh-TW" : "en-US"
                    )
                    
                    aiResponse = answer
                    currentWordIndex = 0
                    currentSentenceIndex = 0
                    isUserScrolling = false
                    updateContentData()
                }
                
                if Task.isCancelled { return }
                
                let cleanText = answer.cleanForTTS()
                let audioData = try await OpenAIService.shared.generateAudio(from: cleanText)
                
                if Task.isCancelled { return }
                
                await playAudio(data: audioData, textToRead: answer)
                
            } catch {
                if (error as? URLError)?.code == .cancelled || (error is CancellationError) {
                    print("🚫 任務已取消，不顯示錯誤")
                } else {
                    await MainActor.run {
                        aiResponse = selectedLanguage == .chinese ? "❌ 連線錯誤: \(error.localizedDescription)" : "❌ Connection Error"
                        isThinking = false
                        updateContentData()
                    }
                }
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

// 🔥🔥 補回被遺漏的結構 🔥🔥

struct LoadingCoverView: View {
    @State private var isRotating = false
    var body: some View {
        ZStack {
            Image("KnowledgeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.3)
            LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.95), Color.SoftBlue.opacity(0.8)]), startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 30) {
                Image(systemName: "book.circle.fill").font(.system(size: 90)).foregroundColor(.MagicBlue).rotationEffect(Angle(degrees: isRotating ? 360 : 0)).animation(Animation.linear(duration: 3.0).repeatForever(autoreverses: false), value: isRotating).onAppear { isRotating = true }.shadow(color: .MagicBlue.opacity(0.3), radius: 10)
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .MagicBlue)).scaleEffect(1.8)
                VStack(spacing: 10) {
                    Text("安安老師準備中...").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.DarkText)
                    Text("正在連接神奇魔法書櫃 📖").font(.system(size: 16, weight: .medium, design: .rounded)).foregroundColor(.gray)
                }
            }
        }
    }
}

struct ThinkingAnimationView: View {
    let language: AppLanguage
    @State private var isAnimating = false
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle().fill(Color.MagicBlue.opacity(0.6)).frame(width: 12, height: 12).scaleEffect(isAnimating ? 1.0 : 0.5).opacity(isAnimating ? 1.0 : 0.3).animation(Animation.easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2), value: isAnimating)
                }
            }
            Text(language == .chinese ? "安安老師正在翻書找答案..." : "Checking the magic book...").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.gray.opacity(0.8))
        }.onAppear { isAnimating = true }
    }
}

struct LanguageButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 16, weight: .bold, design: .rounded)).padding(.vertical, 8).padding(.horizontal, 16).foregroundColor(isSelected ? .white : Color.gray.opacity(0.8)).background(isSelected ? Color.MagicBlue : Color.clear).cornerRadius(20)
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
            if text.rangeOfCharacter(from: .whitespacesAndNewlines) != nil || text.rangeOfCharacter(from: .punctuationCharacters) != nil {
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
    
    func cleanForTTS() -> String {
        var text = self
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "#", with: "")
        text = text.replacingOccurrences(of: "`", with: "")
        text = text.unicodeScalars.filter { !($0.properties.isEmoji && $0.properties.isEmojiPresentation) }.reduce("") { $0 + String($1) }
        text = text.replacingOccurrences(of: "\n", with: "，")
        return text
    }
}

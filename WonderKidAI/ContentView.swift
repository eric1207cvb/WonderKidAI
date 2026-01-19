import SwiftUI
import AVFoundation
import RevenueCat
import RevenueCatUI

// MARK: - 主畫面 ContentView
struct ContentView: View {
    // MARK: - 系統環境變數
    @Environment(\.scenePhase) var scenePhase
    
    // MARK: - 狀態變數
    @ObservedObject private var subManager = SubscriptionManager.shared
    
    @State private var selectedLanguage: AppLanguage = .chinese
    @State private var aiResponse: String = ""
    
    // 預熱標記
    @State private var didPrewarm = false
    
    // 新增 isLandscape 狀態
    @State private var isLandscape: Bool = false
    
    // 初始化語言設定
    init() {
        let preferredLang = Locale.preferredLanguages.first ?? Locale.current.identifier
        let isChinese = preferredLang.hasPrefix("zh")
        _selectedLanguage = State(initialValue: isChinese ? .chinese : .english)
        _aiResponse = State(initialValue: isChinese ?
            "嗨！我是安安老師～\n小朋友你想知道什麼呢？" :
            "Hi! I am Teacher An-An.\nWhat would you like to know?")
    }
    
    // 記憶介紹狀態
    @State private var hasPlayedChineseIntro: Bool = false
    @State private var hasPlayedEnglishIntro: Bool = false
    
    // 視窗控制
    @State private var showPaywall: Bool = false
    @State private var showParentalGate: Bool = false
    
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
            // 計算當前佈局方向
            let computedIsLandscape = geometry.size.width > geometry.size.height
            
            // 當幀大小變化時更新 isLandscape 狀態，使用動畫
            Color.clear
                .onAppear {
                    isLandscape = computedIsLandscape
                }
                .onChange(of: geometry.size) { newSize in
                    let newIsLandscape = newSize.width > newSize.height
                    if newIsLandscape != isLandscape {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            isLandscape = newIsLandscape
                        }
                    }
                }
            
            // 🔥 2. 判斷是否為 iPad
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            
            // --- 背景層 (共用) ---
            ZStack {
                Image("KnowledgeBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()
                    .opacity(0.3)
                    .zIndex(0)
                
                LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.85), Color.SoftBlue.opacity(0.6)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .zIndex(0)
            }
            
            Group {
                if isLandscape {
                    // 🟢 橫向模式 (iPhone & iPad)
                    HStack(spacing: 0) {
                        
                        // 左側欄：視覺動畫 + 麥克風 (iPad佔40%, iPhone佔35%)
                        let leftColumnRatio = isPad ? 0.4 : 0.35
                        
                        VStack {
                            Spacer()
                            
                            // 視覺區
                            visualAnimationArea(geometry: geometry, isLandscape: true, isPad: isPad)
                            
                            Spacer()
                            
                            // 控制區
                            controlsArea(isLandscape: true, isPad: isPad)
                            
                            // 提示文字
                            Text(hintText)
                                .font(.system(size: isPad ? 18 : 14, weight: .bold, design: .rounded))
                                .foregroundColor(.gray.opacity(0.9))
                                .padding(.bottom, 20)
                            
                            Spacer()
                        }
                        .frame(width: geometry.size.width * leftColumnRatio)
                        
                        // 右側欄：內容 + 功能列
                        VStack(spacing: isPad ? 16 : 8) {
                            // 頂部導覽列
                            topNavigationBar(geometry: geometry)
                                .padding(.top, isPad ? 20 : 10)
                            
                            // 文字閱讀區
                            conversationArea(geometry: geometry, isLandscape: true)
                            
                            // 底部法律條款 (iPhone 橫向緊湊模式)
                            footerArea(safeAreaBottom: geometry.safeAreaInsets.bottom, isCompact: !isPad)
                        }
                        .frame(width: geometry.size.width * (1 - leftColumnRatio))
                        .padding(.trailing, 20)
                        
                    }
                } else {
                    // 🔵 直向模式 (iPhone & iPad Portrait)
                    VStack(spacing: 0) {
                        topNavigationBar(geometry: geometry)
                            .padding(.top, 10)
                        
                        Spacer(minLength: 10)
                        
                        visualAnimationArea(geometry: geometry, isLandscape: false, isPad: isPad)
                            .padding(.vertical, 10)
                        
                        Spacer(minLength: 10)
                        
                        VStack(spacing: 20) {
                            conversationArea(geometry: geometry, isLandscape: false)
                            
                            controlsArea(isLandscape: false, isPad: isPad)
                            
                            Text(hintText)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.gray.opacity(0.9))
                            
                            footerArea(safeAreaBottom: geometry.safeAreaInsets.bottom, isCompact: false)
                        }
                        .padding(.bottom, 10)
                    }
                }
            }
            .transition(.opacity.combined(with: .scale))
            .blur(radius: (isServerConnected == nil || showParentalGate) ? 5 : 0)
            // Group 不設 zIndex，保持在背景上
            
            // 預熱用隱藏組件
            if !didPrewarm {
                VStack(spacing: 0) {
                    // 預熱圖片（decode）for both orientations
                    Image("KnowledgeBackground").resizable().frame(width: 1, height: 1).hidden()
                    // 預熱 LazyVGrid (橫式/直式)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 38))], spacing: 2) {
                        Text("PrewarmZH").font(.system(size: 18)).foregroundColor(.clear).frame(width: 38, height: 38)
                    }.frame(height: 1).hidden()
                    // 預熱大 VStack (直式)
                    VStack {
                        Text("DummyZH").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(.clear)
                        HStack {
                            Text("DummyEN1").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.clear)
                            Text("DummyEN2").font(.system(size: 18)).foregroundColor(.clear)
                        }
                    }.frame(width: 300, height: 200).hidden()
                    // 預熱 HStack (橫式)
                    HStack {
                        Rectangle().fill(Color.clear).frame(width: 200, height: 70)
                        Spacer(minLength: 30)
                        Text("hstack").foregroundColor(.clear)
                    }.frame(width: 400).hidden()
                }
                .onAppear {
                    didPrewarm = true
                }
            }
            
            // 載入遮罩
            if isServerConnected == nil {
                LoadingCoverView()
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                    .zIndex(100)
            }
            
            // 家長鎖視窗
            if showParentalGate {
                ParentalGateView(isPresented: $showParentalGate) {
                    showPaywall = true
                }
                .zIndex(200)
            }
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(isPresented: $showHistory, language: selectedLanguage)
                .navigationViewStyle(.stack)
        }
        .sheet(isPresented: $showPrivacy) {
            LegalView(type: .privacy, language: selectedLanguage, isPresented: $showPrivacy)
                .navigationViewStyle(.stack)
        }
        .sheet(isPresented: $showEULA) {
            LegalView(type: .eula, language: selectedLanguage, isPresented: $showEULA)
                .navigationViewStyle(.stack)
        }
        .sheet(isPresented: $showPaywall) {
            paywallContent()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                hasPlayedChineseIntro = false
                hasPlayedEnglishIntro = false
            }
        }
        .onAppear {
            SpeechService.shared.requestAuthorization()
            updateContentData()
            checkServerStatus()
            subManager.checkSubscriptionStatus()
            
            if !didPrewarm {
                // 預熱圖片 decode (will happen by loading Image above)
                // 預熱文字與 LazyVGrid layout pipeline由body中hidden組件觸發
                didPrewarm = true
            }
        }
    }
    
    // MARK: - UI 組件拆分 (ViewBuilders)
    
    @ViewBuilder
    func topNavigationBar(geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            ZStack {
                HStack {
                    Button(action: { showHistory = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 16, weight: .semibold))
                            if geometry.size.width > 380 {
                                Text(selectedLanguage == .chinese ? "足跡" : "History")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.9))
                        .foregroundColor(.MagicBlue)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                    Spacer()
                }
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
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                HStack {
                    Spacer()
                    Button(action: {
                        if !subManager.isPro {
                            showParentalGate = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: subManager.isPro ? "crown.fill" : "crown")
                                .font(.system(size: 16))
                                .foregroundColor(subManager.isPro ? .yellow : .gray)
                            if geometry.size.width > 380 {
                                Text(subManager.isPro ? "VIP" : "PRO")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(subManager.isPro ? .ButtonOrange : .gray)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation { isServerConnected = nil }
                checkServerStatus()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isServerConnected == true ? "person.wave.2.fill" : (isServerConnected == false ? "moon.zzz.fill" : "antenna.radiowaves.left.and.right"))
                        .font(.system(size: 12))
                        .foregroundColor(isServerConnected == true ? .green : (isServerConnected == false ? .gray : .orange))
                    Text(statusText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(isServerConnected == true ? .DarkText : .gray)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.6))
                .clipShape(Capsule())
            }
        }
    }
    
    @ViewBuilder
    func visualAnimationArea(geometry: GeometryProxy, isLandscape: Bool, isPad: Bool) -> some View {
        ZStack {
            let iPhoneLandscapeScale: CGFloat = (isLandscape && !isPad) ? 0.7 : 1.0
            let baseScale: CGFloat = (isLandscape && isPad) ? 1.2 : 1.0
            let finalScale = baseScale * iPhoneLandscapeScale
            
            let baseSize = min(geometry.size.width * 0.45, isLandscape ? geometry.size.height * 0.6 : 300)
            
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: baseSize * finalScale, height: baseSize * finalScale)
                .shadow(color: Color.white.opacity(0.6), radius: 20)
            
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(LinearGradient(gradient: Gradient(colors: [.purple, .blue]), startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: baseSize * 0.9 * finalScale, height: baseSize * 0.9 * finalScale)
                .rotationEffect(Angle(degrees: isThinking ? 360 : 0))
                .animation(isThinking ? Animation.linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: isThinking)
                .opacity(isThinking ? 1 : 0)
            
            Circle()
                .stroke(Color.ButtonRed.opacity(0.5), lineWidth: 8)
                .frame(width: baseSize * 0.9 * finalScale, height: baseSize * 0.9 * finalScale)
                .scaleEffect(isRecording ? 1.1 : 1.0)
                .opacity(isRecording ? 1 : 0)
                .animation(isRecording ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isRecording)
            
            Image(systemName: isThinking ? "book.fill" : (isRecording ? "waveform.circle.fill" : "book.closed.fill"))
                .resizable()
                .scaledToFit()
                .frame(width: baseSize * 0.5 * finalScale)
                .foregroundColor(isRecording ? Color.ButtonRed : Color.MagicBlue)
                .shadow(radius: 5)
        }
    }
    
    @ViewBuilder
    func conversationArea(geometry: GeometryProxy, isLandscape: Bool) -> some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
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
                        VStack(alignment: .leading, spacing: 12) {
                            if !lastQuestion.isEmpty {
                                HStack(spacing: 6) {
                                    Text(selectedLanguage == .chinese ? "問：" : "Q:")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                    
                                    Text(lastQuestion)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal)
                                .padding(.top, 10)
                                Divider().padding(.horizontal)
                            }
                            
                            // 🔥 修改：呼叫新的獨立組件
                            if selectedLanguage == .chinese {
                                ChineseContentView(
                                    characterData: characterData,
                                    isPlaying: isPlaying,
                                    currentWordIndex: currentWordIndex,
                                    isUserScrolling: isUserScrolling,
                                    onScrollTo: { index in
                                        withAnimation { proxy.scrollTo(index, anchor: .center) }
                                    }
                                )
                            } else {
                                EnglishContentView(
                                    englishSentences: englishSentences,
                                    isPlaying: isPlaying,
                                    currentSentenceIndex: currentSentenceIndex,
                                    isUserScrolling: isUserScrolling,
                                    onScrollTo: { index in
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            proxy.scrollTo("Sentence-\(index)", anchor: .center)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .simultaneousGesture(DragGesture().onChanged { _ in isUserScrolling = true })
                
                if isUserScrolling && isPlaying {
                    focusButton(proxy: proxy)
                }
            }
            .frame(height: isLandscape ? .infinity : geometry.size.height * 0.33)
            .background(Color.white.opacity(0.95))
            .cornerRadius(25)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding(.horizontal, isLandscape ? 0 : 24)
        }
    }
    
    @ViewBuilder
    func controlsArea(isLandscape: Bool, isPad: Bool) -> some View {
        let sidePadding: CGFloat = (isLandscape && !isPad) ? 10 : 30
        
        ZStack {
            if isPlaying {
                HStack {
                    Button(action: { stopSpeaking() }) {
                        ZStack {
                            Circle().fill(Color.ButtonRed).frame(width: 60, height: 60)
                                .shadow(color: Color.ButtonRed.opacity(0.4), radius: 10, x: 0, y: 5)
                            Image(systemName: "hand.raised.fill").font(.system(size: 24)).foregroundColor(.white)
                        }
                    }
                    .padding(.leading, sidePadding)
                    .transition(.scale)
                    Spacer()
                }
            }
            
            Button(action: {
                if isThinking { cancelThinking() }
                else if isRecording { manualStop() }
                else { startListening() }
            }) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(gradient: Gradient(colors: isThinking ? [Color.ButtonRed] : (isRecording ? [Color.ButtonRed] : [Color.ButtonOrange, Color.ButtonRed])), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.ButtonRed.opacity(0.4), radius: 15, x: 0, y: 8)
                        .scaleEffect(isRecording ? 1.1 : 1.0)
                    
                    Image(systemName: isThinking ? "xmark" : (isRecording ? "square.fill" : "mic.fill"))
                        .font(.system(size: 30))
                        .foregroundColor(.white)
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
                    .padding(.trailing, sidePadding)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
    
    @ViewBuilder
    func footerArea(safeAreaBottom: CGFloat, isCompact: Bool) -> some View {
        if isCompact {
            HStack(spacing: 10) {
                Text(selectedLanguage == .chinese ? "來源：維基百科" : "Source: Wikipedia")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red.opacity(0.8))
                Text("|").font(.system(size: 10)).foregroundColor(.gray)
                Button(action: { showPrivacy = true }) {
                    Text(selectedLanguage == .chinese ? "隱私" : "Privacy")
                        .font(.system(size: 10, weight: .medium))
                        .underline()
                        .foregroundColor(.MagicBlue)
                }
                Text("|").font(.system(size: 10)).foregroundColor(.gray)
                Button(action: { showEULA = true }) {
                    Text("EULA")
                        .font(.system(size: 10, weight: .medium))
                        .underline()
                        .foregroundColor(.MagicBlue)
                }
            }
            .padding(.bottom, max(safeAreaBottom, 10))
        } else {
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
            .padding(.bottom, safeAreaBottom > 0 ? 0 : 20)
            .layoutPriority(1)
        }
    }
    
    @ViewBuilder
    func paywallContent() -> some View {
        VStack(spacing: 0) {
            PaywallView(displayCloseButton: true)
                .onPurchaseCompleted { customerInfo in
                    subManager.checkSubscriptionStatus()
                    self.showPaywall = false
                }
                .onRestoreCompleted { customerInfo in
                    subManager.checkSubscriptionStatus()
                    if subManager.isPro {
                        self.showPaywall = false
                    }
                }
            HStack(spacing: 20) {
                Link("Privacy Policy", destination: URL(string: "https://github.com/eric1207cvb/WonderKidAI/blob/main/PRIVACY.md")!)
                    .font(.caption)
                Text("|")
                Link("Terms of Use (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .font(.caption)
            }
            .padding()
            .foregroundColor(.gray)
        }
    }
    
    // MARK: - 邏輯 Function
    
    func switchLanguage(to lang: AppLanguage) {
        // 設定長版 intro，清空內容資料及相關狀態
        let cnIntro = "嗨！我是安安老師，你的第一本 AI 百科全書。如果有自然、數學、地理、天文、語文、歷史，或是日常生活的問題，都可以問我喔！"
        let enIntro = "Hello! I am Teacher An-An, your first AI encyclopedia. You can ask me about nature, math, geography, space, history, or anything in your daily life. I am here to help you!"
        
        aiResponse = (lang == .chinese) ? cnIntro : enIntro
        characterData = []
        englishSentences = []
        userSpokenText = ""
        lastQuestion = ""
        isThinking = false
        isRecording = false
        isPreparingRecording = false
        isPlaying = false
        stopAudio()
        currentTask?.cancel()
        currentTask = nil
        currentWordIndex = 0
        currentSentenceIndex = 0
        selectedLanguage = lang
        
        updateContentData()
    }
    
    func triggerPaywall() {
        if selectedLanguage == .chinese {
            userSpokenText = "🔒 今天的免費次數用完囉！\n請爸爸媽媽幫忙解鎖～"
        } else {
            userSpokenText = "🔒 Free quota used up today!\nAsk parents to unlock."
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showParentalGate = true
        }
    }
    
    func askExplainAgain() {
        if !subManager.isPro && !checkFreeQuota() {
            triggerPaywall()
            return
        }
        
        if lastQuestion.isEmpty {
            let needsIntro = (selectedLanguage == .chinese && !hasPlayedChineseIntro) ||
                             (selectedLanguage == .english && !hasPlayedEnglishIntro)
            
            if needsIntro {
                playIntroMessage()
            } else {
                aiResponse = selectedLanguage == .chinese ? "請按麥克風問我問題喔！" : "Please tap the mic to ask a question!"
                updateContentData()
            }
            return
        }
        
        let questionToAsk = lastQuestion
        
        let prompt = selectedLanguage == .chinese ?
        """
        針對小朋友剛剛的問題：「\(questionToAsk)」。
        他表示「聽不懂」剛才的解釋。
        請你執行以下任務：
        1. 絕對不要重複剛才的答案。
        2. 請改用「生活中的例子」或「童話故事的比喻」來解釋。
        3. 語氣要更慢、更像在跟 3 歲小孩說話。
        4. 開頭可以說：「沒關係，我們想像一下...」
        """ :
        """
        Regarding the child's previous question: "\(questionToAsk)".
        They did not understand the previous explanation.
        Please:
        1. Do NOT repeat the previous answer.
        2. Use a simple real-life analogy or a story metaphor.
        3. Speak as if to a 3-year-old.
        4. Start with "That's okay, let's imagine..."
        """
        
        userSpokenText = selectedLanguage == .chinese ? "🔄 老師，可以講簡單一點嗎？" : "🔄 Teacher, simpler please?"
        sendToAI(question: prompt)
    }
    
    func checkFreeQuota() -> Bool {
        return subManager.checkUserQuota()
    }
    
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
    
    func stopSpeaking() {
        stopAudio()
        isThinking = false
    }
    
    func interruptAndListen() {
        stopSpeaking()
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
        if !subManager.isPro && !checkFreeQuota() {
            triggerPaywall()
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
                    
                    aiResponse = ""
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
                    print("🚫 任務已取消，靜默處理")
                } else {
                    await MainActor.run {
                        if selectedLanguage == .chinese {
                            aiResponse = "🥤 安安老師去喝口水，馬上回來～\n(請檢查網路，再試一次喔！)"
                        } else {
                            aiResponse = "🥤 Teacher An-An is taking a water break.\n(Please check connection and try again!)"
                        }
                        print("❌ 真實錯誤原因: \(error.localizedDescription)")
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
                    self.currentWordIndex = totalChars // 播放結束時顯示所有字
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
    
    func focusButton(proxy: ScrollViewProxy) -> some View {
        Button(action: {
            isUserScrolling = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring()) {
                    if selectedLanguage == .english {
                        proxy.scrollTo("Sentence-\(currentSentenceIndex)", anchor: .center)
                    } else {
                        proxy.scrollTo(currentWordIndex, anchor: .center)
                    }
                }
            }
        }) {
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
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - 新增獨立中文內容視圖
struct ChineseContentView: View {
    let characterData: [(char: String, bopomofo: String)]
    let isPlaying: Bool
    let currentWordIndex: Int
    let isUserScrolling: Bool
    let onScrollTo: (Int) -> Void
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 38), spacing: 2)], alignment: .leading, spacing: 10) {
            ForEach(Array(characterData.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 0) {
                    let shouldShow = !isPlaying || index < currentWordIndex
                    
                    if !item.bopomofo.isEmpty {
                        Text(item.bopomofo)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(shouldShow ? .MagicBlue : .gray.opacity(0.6))
                            .fixedSize()
                    }
                    Text(item.char)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(shouldShow ? .MagicBlue : .gray.opacity(0.5))
                }
                .id(index)
                .frame(minWidth: 38)
                .scaleEffect(isPlaying && index == currentWordIndex - 1 ? 1.2 : 1.0)
                .animation(isPlaying && index == currentWordIndex - 1 ? .spring(response: 0.3) : .none, value: isPlaying ? currentWordIndex : 0)
            }
        }
        .padding()
        .onChange(of: currentWordIndex) { newIndex in
            if newIndex > 0 && !isUserScrolling {
                onScrollTo(newIndex)
            }
        }
    }
}

// MARK: - 新增獨立英文內容視圖
struct EnglishContentView: View {
    let englishSentences: [String]
    let isPlaying: Bool
    let currentSentenceIndex: Int
    let isUserScrolling: Bool
    let onScrollTo: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(englishSentences.enumerated()), id: \.offset) { index, sentence in
                let isActive = isPlaying && (index == currentSentenceIndex)
                
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
                    .animation(isActive ? .spring() : .none, value: isPlaying ? currentSentenceIndex : 0)
                    .id("Sentence-\(index)")
                    .onTapGesture {  }
            }
            
            if englishSentences.count > 2 && currentSentenceIndex < englishSentences.count - 1 && !isUserScrolling {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.MagicBlue.opacity(0.6))
                    .padding(.bottom, 10)
                    .opacity(isPlaying ? 0 : 1)
            }
        }
        .padding()
        .padding(.bottom, 40)
        .onChange(of: currentSentenceIndex) { newIndex in
            if !isUserScrolling {
                onScrollTo(newIndex)
            }
        }
    }
}

// MARK: - 輔助元件與擴充

struct ParentalGateView: View {
    @Binding var isPresented: Bool
    var onSuccess: () -> Void
    
    @State private var num1 = Int.random(in: 1...5)
    @State private var num2 = Int.random(in: 1...5)
    @State private var answer = ""
    @State private var showError = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.MagicBlue)
                
                Text("家長確認 (Parent Gate)")
                    .font(.headline)
                    .foregroundColor(.black)
                
                Text("請回答：\(num1) + \(num2) = ?")
                    .font(.title2).bold()
                    .foregroundColor(.black)
                
                TextField("答案", text: $answer)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .frame(width: 100)
                    .foregroundColor(.black)
                
                if showError {
                    Text("答案錯誤，請再試一次")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                HStack {
                    Button("取消") { isPresented = false }
                        .foregroundColor(.gray)
                    
                    Spacer().frame(width: 40)
                    
                    Button("確認") {
                        let input = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                        if Int(input) == (num1 + num2) {
                            onSuccess()
                            isPresented = false
                        } else {
                            showError = true
                            answer = ""
                        }
                    }
                    .bold()
                    .foregroundColor(.MagicBlue)
                }
            }
            .padding(30)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding(40)
        }
    }
}

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


import SwiftUI
import AVFoundation
import RevenueCat
import RevenueCatUI
import NaturalLanguage

// MARK: - 主畫面 ContentView
struct ContentView: View {
    // MARK: - 系統環境變數
    @Environment(\.scenePhase) var scenePhase
    
    // MARK: - 狀態變數
    @ObservedObject private var subManager = SubscriptionManager.shared
    
    @State private var selectedLanguage: AppLanguage = .chinese
    @State private var aiResponse: String = ""
    @State private var localizedText: LocalizedStrings = LocalizedStrings(language: .chinese)
    
    // 預熱標記
    @State private var didPrewarm = false
    
    // 新增 isLandscape 狀態
    @State private var isLandscape: Bool = false
    
    // 🎬 過場動畫控制
    @State private var isAppearing: Bool = false
    @State private var orientationTransitionID: UUID = UUID()
    
    // 初始化語言設定
    init() {
        let preferredLang = Locale.preferredLanguages.first ?? Locale.current.identifier
        
        // 🇯🇵 支援三語：中文、英文、日文
        let detectedLanguage: AppLanguage
        if preferredLang.hasPrefix("zh") {
            detectedLanguage = .chinese
        } else if preferredLang.hasPrefix("ja") {
            detectedLanguage = .japanese
        } else {
            detectedLanguage = .english
        }
        
        _selectedLanguage = State(initialValue: detectedLanguage)
        _localizedText = State(initialValue: LocalizedStrings(language: detectedLanguage))
        _aiResponse = State(initialValue: LocalizedStrings(language: detectedLanguage).welcomeMessage)
    }
    
    // 記憶介紹狀態（每種語言獨立）
    @State private var hasPlayedChineseIntro: Bool = false
    @State private var hasPlayedEnglishIntro: Bool = false
    @State private var hasPlayedJapaneseIntro: Bool = false
    
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
    @State private var wordTokens: [WordToken] = []
    
    // 🚀 音頻快取（加速自我介紹）
    @State private var cachedIntroAudio: [AppLanguage: Data] = [:]
    @State private var preloadingIntroLanguages: Set<AppLanguage> = []
    
    let aiListeningSymbol = "✨🤖✨"
    
    var body: some View {
        GeometryReader { geometry in
            // 計算當前佈局方向
            let computedIsLandscape = geometry.size.width > geometry.size.height
            
            // 當幀大小變化時更新 isLandscape 狀態，使用動畫
            Color.clear
                .onAppear {
                    isLandscape = computedIsLandscape
                    // 🎬 延遲顯示主畫面，創造平滑啟動體驗
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isAppearing = true
                        }
                    }
                }
                .onChange(of: geometry.size) { oldSize, newSize in
                    let newIsLandscape = newSize.width > newSize.height
                    guard newIsLandscape != isLandscape else { return }
                    
                    // 節流：延遲少許再套用，避免旋轉過程中多次觸發重排
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        withAnimation(.snappy(duration: 0.35, extraBounce: 0.0)) {
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
                    .opacity(isAppearing ? 0.3 : 0)
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
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
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
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
            }
            .animation(.snappy(duration: 0.35, extraBounce: 0.0), value: isLandscape)
            .opacity(isAppearing ? 1.0 : 0.0)
            .scaleEffect(isAppearing ? 1.0 : 0.95)
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
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
                    .animation(.easeOut(duration: 0.5), value: isServerConnected)
                    .zIndex(100)
            }
            
            // 家長鎖視窗
            if showParentalGate {
                ParentalGateView(isPresented: $showParentalGate, language: selectedLanguage) {
                    showPaywall = true
                }
                .transition(.scale.combined(with: .opacity))
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // 退出程式時重置所有介紹狀態
                hasPlayedChineseIntro = false
                hasPlayedEnglishIntro = false
                hasPlayedJapaneseIntro = false
            }
        }
        .onAppear {
            SpeechService.shared.requestAuthorization()
            updateContentData()
            checkServerStatus()
            subManager.checkSubscriptionStatus()
            
            // 🚀 預載當前語言的自我介紹音頻（背景執行）
            preloadAllIntroAudio()
            
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
                                Text(localizedText.historyButton)
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
                    LanguageButton(title: "日", isSelected: selectedLanguage == .japanese) {
                        switchLanguage(to: .japanese)
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
            
            let statusIconName: String = {
                if isServerConnected == nil && !isThinking && !isRecording {
                    return "globe.asia.australia.fill"
                }
                if isThinking {
                    return "book.fill"
                }
                if isRecording {
                    return "waveform.circle.fill"
                }
                return "book.closed.fill"
            }()
            
            Image(systemName: statusIconName)
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
            let scrollToUserText = {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo("UserText", anchor: .center)
                    }
                }
            }
            ZStack(alignment: .bottom) {
                ScrollView {
                    Color.clear.frame(height: 0).id("ScrollTop")
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
                                    Text(localizedText.questionLabel)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                    
                                    Text(lastQuestion)
                                        .font(.body)
                                        .foregroundColor(.DarkText)
                                }
                                .padding(.horizontal)
                                .padding(.top, 10)
                                Divider().padding(.horizontal)
                            }
                            
                            // 🔥 修改：呼叫新的獨立組件
                            if selectedLanguage == .chinese {
                                ChineseContentView(
                                    characterData: aiResponse.toBopomofoCharacter(),
                                    isPlaying: isPlaying,
                                    currentWordIndex: currentWordIndex,
                                    isUserScrolling: isUserScrolling,
                                    onScrollTo: { index in
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            proxy.scrollTo(index, anchor: .center)
                                        }
                                    }
                                )
                            } else if selectedLanguage == .japanese {
                                JapaneseContentView(
                                    japaneseSentences: englishSentences,
                                    isPlaying: isPlaying,
                                    currentSentenceIndex: currentSentenceIndex,
                                    isUserScrolling: isUserScrolling,
                                    onScrollTo: { index in
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            proxy.scrollTo(index, anchor: .center)
                                        }
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
                                            proxy.scrollTo(index, anchor: .center)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .simultaneousGesture(DragGesture().onChanged { _ in isUserScrolling = true })
                .onChange(of: aiResponse) { _, _ in
                    guard !isUserScrolling else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo("ScrollTop", anchor: .top)
                        }
                    }
                }
                .onChange(of: isPreparingRecording) { _, newValue in
                    guard newValue, !isUserScrolling else { return }
                    scrollToUserText()
                }
                .onChange(of: isRecording) { _, newValue in
                    guard newValue, !isUserScrolling else { return }
                    scrollToUserText()
                }
                .onChange(of: userSpokenText) { _, _ in
                    guard (isRecording || isPreparingRecording), !isUserScrolling else { return }
                    scrollToUserText()
                }
                
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
            
            let canShowAgain = !isRecording && !isThinking && !isPreparingRecording && !isPlaying && !aiResponse.isEmpty
            if canShowAgain {
                HStack {
                    Spacer()
                    Button(action: { askExplainAgain() }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 20))
                            // 🔥 根據介紹狀態顯示不同文字
                            Text(getAgainButtonText()).font(.system(size: 10, weight: .bold))
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
                Text(localizedText.dataSourceCompact)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red.opacity(0.8))
                Text("|").font(.system(size: 10)).foregroundColor(.gray)
                Button(action: { showPrivacy = true }) {
                    Text(localizedText.privacyPolicy)
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
                Text(localizedText.dataSource)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.red.opacity(0.8))
                HStack(spacing: 15) {
                    Button(action: { showPrivacy = true }) {
                        Text(localizedText.privacyPolicy)
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
                Button("Privacy Policy") {
                    showPrivacy = true
                }
                .font(.caption)
                Text("|")
                Button("Terms of Use (EULA)") {
                    showEULA = true
                }
                .font(.caption)
            }
            .padding()
            .foregroundColor(.gray)
        }
    }
    
    // MARK: - 邏輯 Function
    
    func switchLanguage(to lang: AppLanguage) {
        // 更新本地化文字
        localizedText = LocalizedStrings(language: lang)
        
        // 設定長版 intro，清空內容資料及相關狀態
        aiResponse = localizedText.introMessage
        characterData = []
        englishSentences = []
        userSpokenText = ""
        lastQuestion = ""
        isThinking = false
        isRecording = false
        isPreparingRecording = false
        isPlaying = false
        stopAudio()
        SpeechService.shared.stopRecording()
        currentTask?.cancel()
        currentTask = nil
        currentWordIndex = 0
        currentSentenceIndex = 0
        selectedLanguage = lang

        updateContentData()
        
        // 🚀 切換語言後，預載新語言的自我介紹
        preloadIntroAudio(for: lang)
    }
    
    func triggerPaywall() {
        userSpokenText = localizedText.quotaExceeded
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showParentalGate = true
        }
    }
    
    // MARK: - 按鈕文字邏輯
    
    /// 判斷當前語言是否還沒播放過介紹
    func needsIntro() -> Bool {
        switch selectedLanguage {
        case .chinese:
            return !hasPlayedChineseIntro
        case .english:
            return !hasPlayedEnglishIntro
        case .japanese:
            return !hasPlayedJapaneseIntro
        }
    }
    
    /// 取得按鈕顯示文字（介紹或聽不懂）
    func getAgainButtonText() -> String {
        if needsIntro() {
            // 還沒播放過介紹，顯示「介紹」
            switch selectedLanguage {
            case .chinese: return "介紹"
            case .english: return "Intro"
            case .japanese: return "紹介"
            }
        } else {
            // 已經播放過介紹，顯示「聽不懂/Again/もう一度」
            switch selectedLanguage {
            case .chinese: return "聽不懂"
            case .english: return "Again"
            case .japanese: return "もう一度"
            }
        }
    }
    
    func askExplainAgain() {
        if !subManager.isPro {
            if !subManager.isSubscriptionLoaded {
                userSpokenText = localizedText.statusConnecting
                return
            }
            if !subManager.hasServerTime {
                userSpokenText = localizedText.errorNetwork
                return
            }
            if !checkFreeQuota() {
                triggerPaywall()
                return
            }
        }
        
        // 🔥 優先判斷：如果還沒播放過介紹，就播放介紹
        if needsIntro() {
            playIntroMessage()
            return
        }
        
        // 已經播放過介紹，執行原本的「聽不懂」邏輯
        if lastQuestion.isEmpty {
            // 如果沒有問題，就再播一次介紹
            playIntroMessage()
            return
        }
        
        let questionToAsk = lastQuestion
        let prompt = localizedText.simplerExplanationPrompt(for: questionToAsk)
        userSpokenText = localizedText.simplerExplanationRequest
        sendToAI(question: prompt)
    }
    
    func checkFreeQuota() -> Bool {
        return subManager.checkUserQuota()
    }
    
    func updateContentData() {
        if selectedLanguage == .chinese {
            // 中文：以句子為單位顯示卡片
            let rawSentences = aiResponse
                .replacingOccurrences(of: "。", with: "。|")
                .replacingOccurrences(of: "？", with: "？|")
                .replacingOccurrences(of: "！", with: "！|")
                .replacingOccurrences(of: ". ", with: ".|")
                .replacingOccurrences(of: "? ", with: "?|")
                .replacingOccurrences(of: "! ", with: "!|")
                .split(separator: "|")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            englishSentences = rawSentences.isEmpty ? [aiResponse] : rawSentences
            characterData = []
            wordTokens = []
        } else if selectedLanguage == .japanese {
            // 🇯🇵 日文使用句子顯示（按句號、問號、驚嘆號分割）
            let rawSentences = aiResponse
                .replacingOccurrences(of: "。", with: "。|")
                .replacingOccurrences(of: "？", with: "？|")
                .replacingOccurrences(of: "！", with: "！|")
                .split(separator: "|")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            englishSentences = rawSentences.isEmpty ? [aiResponse] : rawSentences
            wordTokens = buildWordTokens(for: aiResponse)
        } else {
            // 英文
            let rawSentences = aiResponse
                .replacingOccurrences(of: ". ", with: ".|")
                .replacingOccurrences(of: "? ", with: "?|")
                .replacingOccurrences(of: "! ", with: "!|")
                .split(separator: "|")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            englishSentences = rawSentences.isEmpty ? [aiResponse] : rawSentences
            wordTokens = buildWordTokens(for: aiResponse)
        }
    }

    func buildWordTokens(for text: String) -> [WordToken] {
        guard !text.isEmpty else { return [] }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var wordRanges: [Range<String.Index>] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            wordRanges.append(range)
            return true
        }

        var tokens: [WordToken] = []
        var lastIndex = text.startIndex
        var id = 0

        for range in wordRanges {
            if lastIndex < range.lowerBound {
                let gapRange = lastIndex..<range.lowerBound
                let gapText = String(text[gapRange])
                let display = gapText.filter { !$0.isWhitespace }
                if !display.isEmpty {
                    let start = text.distance(from: text.startIndex, to: gapRange.lowerBound)
                    let length = text.distance(from: gapRange.lowerBound, to: gapRange.upperBound)
                    tokens.append(WordToken(id: id, text: display, start: start, length: length, isWord: false))
                    id += 1
                }
            }

            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            let length = text.distance(from: range.lowerBound, to: range.upperBound)
            let wordText = String(text[range])
            tokens.append(WordToken(id: id, text: wordText, start: start, length: length, isWord: true))
            id += 1
            lastIndex = range.upperBound
        }

        if lastIndex < text.endIndex {
            let gapRange = lastIndex..<text.endIndex
            let gapText = String(text[gapRange])
            let display = gapText.filter { !$0.isWhitespace }
            if !display.isEmpty {
                let start = text.distance(from: text.startIndex, to: gapRange.lowerBound)
                let length = text.distance(from: gapRange.lowerBound, to: gapRange.upperBound)
                tokens.append(WordToken(id: id, text: display, start: start, length: length, isWord: false))
            }
        }

        return tokens
    }

    func wordTokenIndex(for charIndex: Int, tokens: [WordToken]) -> Int {
        var lastWordIndex: Int?
        for (index, token) in tokens.enumerated() {
            guard token.isWord else { continue }
            let start = token.start
            let end = token.start + max(1, token.length)
            if charIndex < start {
                return lastWordIndex ?? index
            }
            if charIndex < end {
                return index
            }
            lastWordIndex = index
        }
        return lastWordIndex ?? 0
    }

    func lastWordTokenIndex(in tokens: [WordToken]) -> Int {
        if let index = tokens.lastIndex(where: { $0.isWord }) {
            return index
        }
        return max(tokens.count - 1, 0)
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
    
    // MARK: - 中文有效字數權重模型
    func makeChineseWeights(for text: String) -> ([Double], [Double], Double) {
        // 為每個字元建立權重，空白與無聲標點給 0，常見停頓標點給較高權重
        let chars = Array(text)
        var weights: [Double] = Array(repeating: 0.0, count: chars.count)

        // 定義類別
        let silentSet: Set<Character> = [" ", "\t", "\n"]
        let lightPunct: Set<Character> = [",", ":", ";", "，", "：", "；"]
        let midPausePunct: Set<Character> = ["、"]
        // 🔥 優化 2: 更精細的標點權重
        let periodSet: Set<Character> = [".", "。"]       // 句號停頓較長
        let questionSet: Set<Character> = ["?", "？"]     // 問號中等停頓
        let exclamationSet: Set<Character> = ["!", "！"]  // 驚嘆號停頓較短

        for i in 0..<chars.count {
            let c = chars[i]
            if silentSet.contains(c) { weights[i] = 0.0; continue }
            if lightPunct.contains(c) { weights[i] = 0.25; continue }
            if midPausePunct.contains(c) { weights[i] = 0.5; continue }
            
            // 🔥 優化 2: 細分標點權重
            if periodSet.contains(c) { weights[i] = 0.9; continue }      // 句號
            if questionSet.contains(c) { weights[i] = 0.8; continue }    // 問號
            if exclamationSet.contains(c) { weights[i] = 0.7; continue } // 驚嘆號
            
            // CJK 統一漢字或一般可發音字
            if let scalar = c.unicodeScalars.first {
                let v = scalar.value
                let isCJK = (0x4E00...0x9FFF).contains(v)
                let isLetterOrNumber = CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar)
                weights[i] = (isCJK || isLetterOrNumber) ? 1.0 : 0.2
            } else {
                weights[i] = 0.2
            }
        }

        // 前綴和
        var cumulative: [Double] = Array(repeating: 0.0, count: weights.count + 1)
        for i in 0..<weights.count {
            cumulative[i + 1] = cumulative[i] + weights[i]
        }
        let total = cumulative.last ?? 0.0
        return (weights, cumulative, total)
    }

    func indexForChineseProgress(progress: Double, cumulative: [Double]) -> Int {
        // 將進度(0..1)映射到累積權重中的位置，回傳字元索引
        guard let total = cumulative.last, total > 0 else { return 0 }
        let target = progress * total
        // 二分搜尋
        var low = 0
        var high = cumulative.count - 1
        while low < high {
            let mid = (low + high) / 2
            if cumulative[mid] < target {
                low = mid + 1
            } else {
                high = mid
            }
        }
        // cumulative 的索引比字元索引多 1
        return max(0, min(low - 1, cumulative.count - 2))
    }

    func isSpeakableChineseCharacter(_ c: Character) -> Bool {
        guard let scalar = c.unicodeScalars.first else { return false }
        let v = scalar.value
        let isCJK = (0x4E00...0x9FFF).contains(v)
        let isLetterOrNumber = CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar)
        return isCJK || isLetterOrNumber
    }

    func nearestSpeakableIndex(from index: Int, speakableMask: [Bool]) -> Int {
        guard !speakableMask.isEmpty else { return index }
        let clampedIndex = max(0, min(index, speakableMask.count - 1))
        if speakableMask[clampedIndex] { return clampedIndex }
        var backward = clampedIndex - 1
        while backward >= 0 {
            if speakableMask[backward] { return backward }
            backward -= 1
        }
        var forward = clampedIndex + 1
        while forward < speakableMask.count {
            if speakableMask[forward] { return forward }
            forward += 1
        }
        return clampedIndex
    }
    
    // MARK: - 🔥 優化 5: 檢測是否接近標點符號
    func isNearPunctuation(text: String, index: Int, weights: [Double]) -> Bool {
        guard index >= 0 && index < weights.count else { return false }
        
        // 檢查當前字符及前後各 1 個字符
        let range = max(0, index - 1)...min(weights.count - 1, index + 1)
        
        for i in range {
            // 權重 >= 0.7 表示是重要標點（句號、問號、驚嘆號）
            if weights[i] >= 0.7 && weights[i] < 1.0 {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - 🔥 優化 6: 音訊波形分析（檢測靜音區域）
    func detectSilenceRegions(audioData: Data) -> (leadingSilence: TimeInterval, trailingSilence: TimeInterval) {
        // 快速啟發式檢測：避免完整波形分析的複雜度
        // 使用 AVAudioPlayer 的特性進行估算
        
        do {
            let player = try AVAudioPlayer(data: audioData)
            player.prepareToPlay()
            
            let duration = player.duration
            
            // 🎯 基於 OpenAI TTS 的經驗值
            // 中文 TTS 通常有以下特性：
            // - 開頭靜音：0.15-0.35 秒（平均 0.25 秒）
            // - 結尾靜音：0.1-0.3 秒（平均 0.2 秒）
            
            // 根據音訊長度動態調整
            let leadingSilence: TimeInterval
            let trailingSilence: TimeInterval
            
            if duration < 2.0 {
                // 短音訊：靜音較少
                leadingSilence = 0.15
                trailingSilence = 0.1
            } else if duration < 5.0 {
                // 中等長度：使用標準值
                leadingSilence = 0.25
                trailingSilence = 0.2
            } else {
                // 長音訊：靜音可能較多
                leadingSilence = 0.35
                trailingSilence = 0.3
            }
            
            #if DEBUG
            print("[TTS][Silence] duration=\(String(format: "%.2f", duration))s, leading=\(String(format: "%.2f", leadingSilence))s, trailing=\(String(format: "%.2f", trailingSilence))s")
            #endif
            
            return (leadingSilence, trailingSilence)
            
        } catch {
            print("[TTS][Silence] Failed to analyze audio: \(error)")
            // 發生錯誤時使用保守的預設值
            return (0.25, 0.2)
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
        aiResponse = localizedText.cancelled
        updateContentData()
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    func playIntroMessage() {
        let introText = localizedText.introMessage
        userSpokenText = localizedText.firstMeeting
        
        // 立即更新 UI
        aiResponse = introText
        
        // 新增：重置播放狀態相關索引與滾動狀態
        currentWordIndex = 0
        currentSentenceIndex = 0
        isUserScrolling = false
        
        updateContentData()
        
        currentTask = Task {
            do {
                let audioData: Data
                
                // 🚀 檢查是否有快取的音頻
                if let cached = cachedIntroAudio[selectedLanguage] {
                    print("⚡️ 使用快取的自我介紹音頻")
                    audioData = cached
                } else if let diskCached = loadIntroAudioFromDisk(for: selectedLanguage) {
                    print("⚡️ 使用磁碟快取的自我介紹音頻")
                    audioData = diskCached
                    await MainActor.run {
                        cachedIntroAudio[selectedLanguage] = diskCached
                    }
                } else {
                    // 沒有快取，生成新的
                    print("🎤 生成自我介紹音頻...")
                    let cleanText = introText.cleanForTTS(language: selectedLanguage)
                    audioData = try await OpenAIService.shared.generateAudio(from: cleanText, language: selectedLanguage)
                    
                    // 快取音頻以供下次使用
                    saveIntroAudioToDisk(audioData, for: selectedLanguage)
                    await MainActor.run {
                        cachedIntroAudio[selectedLanguage] = audioData
                    }
                }
                
                await playAudio(data: audioData, textToRead: introText)
                
                // 根據當前語言設定對應的介紹狀態
                await MainActor.run {
                    switch selectedLanguage {
                    case .chinese:
                        hasPlayedChineseIntro = true
                    case .english:
                        hasPlayedEnglishIntro = true
                    case .japanese:
                        hasPlayedJapaneseIntro = true
                    }
                }
                
            } catch {
                print("❌ Intro TTS failed: \(error)")
                await MainActor.run {
                    userSpokenText = localizedText.errorNetwork
                }
            }
        }
    }
    
    // 🚀 預載自我介紹音頻（背景執行）
    func preloadIntroAudio(for language: AppLanguage) {
        if cachedIntroAudio[language] == nil, let diskCached = loadIntroAudioFromDisk(for: language) {
            cachedIntroAudio[language] = diskCached
            return
        }
        
        // 避免重複預載
        guard cachedIntroAudio[language] == nil, !preloadingIntroLanguages.contains(language) else { return }
        
        preloadingIntroLanguages.insert(language)
        
        Task {
            do {
                let introText = LocalizedStrings(language: language).introMessage
                let cleanText = introText.cleanForTTS(language: language)
                
                print("🚀 開始預載 \(language.rawValue) 自我介紹音頻...")
                let audioData = try await OpenAIService.shared.generateAudio(from: cleanText, language: language)
                saveIntroAudioToDisk(audioData, for: language)
                
                await MainActor.run {
                    cachedIntroAudio[language] = audioData
                    preloadingIntroLanguages.remove(language)
                    print("✅ \(language.rawValue) 自我介紹音頻預載完成")
                }
            } catch {
                print("❌ 預載自我介紹失敗: \(error)")
                await MainActor.run {
                    preloadingIntroLanguages.remove(language)
                }
            }
        }
    }

    func preloadAllIntroAudio() {
        for language in AppLanguage.allCases {
            preloadIntroAudio(for: language)
        }
    }

    private func introAudioURL(for language: AppLanguage) -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let filename = "intro-\(language.rawValue).m4a"
        return caches.appendingPathComponent(filename)
    }
    
    private func loadIntroAudioFromDisk(for language: AppLanguage) -> Data? {
        guard let url = introAudioURL(for: language),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }
    
    private func saveIntroAudioToDisk(_ data: Data, for language: AppLanguage) {
        guard let url = introAudioURL(for: language) else { return }
        try? data.write(to: url, options: [.atomic])
    }
    
    var statusText: String {
        switch isServerConnected {
        case true: return localizedText.statusOnline
        case false: return localizedText.statusOffline
        default: return localizedText.statusConnecting
        }
    }
    
    var hintText: String {
        if isPlaying {
            return localizedText.hintInterrupt
        }
        if isThinking {
            return localizedText.hintCancel
        }
        return isPreparingRecording ? localizedText.hintPreparing :
               (isRecording ? localizedText.hintListening : localizedText.hintTapToSpeak)
    }
    
    func checkServerStatus() {
        Task {
            let result = await OpenAIService.shared.checkConnection()
            await MainActor.run { withAnimation { isServerConnected = result } }
        }
    }
    
    func startListening() {
        if !subManager.isPro {
            if !subManager.isSubscriptionLoaded {
                userSpokenText = localizedText.statusConnecting
                return
            }
            if !subManager.hasServerTime {
                userSpokenText = localizedText.errorNetwork
                return
            }
            if !checkFreeQuota() {
                triggerPaywall()
                return
            }
        }
        
        guard !isThinking && !isPreparingRecording else { return }

        let permissionState = SpeechService.shared.permissionState()
        switch permissionState {
        case .authorized:
            beginRecording()
        case .notDetermined:
            isPreparingRecording = true
            userSpokenText = localizedText.permissionRequest
            SpeechService.shared.requestPermissions { granted in
                self.isPreparingRecording = false
                if granted {
                    self.startListening()
                } else {
                    self.userSpokenText = self.localizedText.permissionDenied
                    self.isRecording = false
                }
            }
        case .denied:
            userSpokenText = localizedText.permissionDenied
            isPreparingRecording = false
            isRecording = false
        }
    }

    private func beginRecording() {
        #if DEBUG
        print("[STT] startListening language=\(selectedLanguage.rawValue)")
        #endif
        
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
            #if DEBUG
            print("[STT] recording started")
            #endif
            self.isPreparingRecording = false
            self.isRecording = true
            self.userSpokenText = self.aiListeningSymbol
        }
        
        SpeechService.shared.onSpeechDetected = { text, isFinished in
            #if DEBUG
            print("[STT] partial len=\(text.count) isFinished=\(isFinished)")
            #endif
            if isFinished {
                self.finishRecording()
            } else {
                if !text.isEmpty { self.userSpokenText = text }
            }
        }
        
        do {
            try SpeechService.shared.startRecording(language: selectedLanguage)
        } catch {
            userSpokenText = localizedText.errorStart
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
        #if DEBUG
        print("[STT] finishRecording textLen=\(userSpokenText.count)")
        #endif
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        if userSpokenText == aiListeningSymbol || userSpokenText.isEmpty || userSpokenText == "..." {
            userSpokenText = localizedText.errorTooQuiet
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
                        language: localizedText.historyLanguageCode
                    )
                    subManager.recordUsage()
                    
                    aiResponse = ""
                    aiResponse = answer
                    currentWordIndex = 0
                    currentSentenceIndex = 0
                    isUserScrolling = false
                    markIntroAsUsed(for: selectedLanguage)
                    updateContentData()
                }
                
                if Task.isCancelled { return }
                
                let cleanText = answer.cleanForTTS(language: selectedLanguage)
                let audioData = try await OpenAIService.shared.generateAudio(from: cleanText, language: selectedLanguage)
                
                if Task.isCancelled { return }
                
                await playAudio(data: audioData, textToRead: answer)
                
            } catch {
                if (error as? URLError)?.code == .cancelled || (error is CancellationError) {
                    print("🚫 任務已取消，靜默處理")
                } else {
                    await MainActor.run {
                        aiResponse = localizedText.errorNetwork
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
            
            // 檢查合理的時長，避免字幕瞬間刷完
            let duration = audioPlayer?.duration ?? 0
            #if DEBUG
            print("[TTS] duration=\(String(format: "%.2f", duration))s, textLen=\(textToRead.count)")
            #endif
            if duration <= 0.2 {
                // 不合理的音訊長度：停用字幕同步，只做最基本播放
                audioPlayer?.play()
                isThinking = false
                currentWordIndex = 0
                isPlaying = true
                // 直接在一秒後結束字幕同步
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.currentWordIndex = (self.selectedLanguage == .chinese) ? (textToRead.count) : (textToRead.count)
                    self.isPlaying = false
                }
                return
            }
            
            // 延後字幕同步，直到確實開始播放
            var didStartPlayback = false
            
            audioPlayer?.play()
            
            isThinking = false
            
            // 🔥 計算實際會發音的字符數量
            let totalChars: Int
            let displayCharsCount = textToRead.count
            if selectedLanguage == .chinese {
                // 中文：只計算漢字和字母數字，排除標點符號和空白
                totalChars = textToRead.filter { char in
                    // 保留漢字（Unicode 範圍）、字母和數字
                    let scalar = char.unicodeScalars.first!
                    let isCJK = (0x4E00...0x9FFF).contains(scalar.value) // CJK 統一漢字
                    let isAlphanumeric = char.isLetter || char.isNumber
                    return isCJK || isAlphanumeric
                }.count
                
                // print("🎵 中文字幕同步：原始文字 \(textToRead.count) 字 → 實際發音 \(totalChars) 字")
            } else {
                // 英文/日文：使用原始字數
                totalChars = textToRead.count
            }
            
            // 準備中文權重（僅中文使用）
            var zhCumulative: [Double] = []
            var zhTotal: Double = 0
            var zhSpeakableMask: [Bool] = []
            if selectedLanguage == .chinese {
                let (_, cumulative, total) = makeChineseWeights(for: textToRead)
                zhCumulative = cumulative
                zhTotal = total
                if total <= 0 {
                    print("[TTS][ZH] cumulative total is 0, fallback to uniform mapping. Text length: \(textToRead.count)")
                }
                let textChars = Array(textToRead)
                zhSpeakableMask = textChars.map { isSpeakableChineseCharacter($0) }
            }
            
            // 🔥 優化 4: 動態計算 alpha 值（根據語速）
            let speedPerChar = duration / Double(max(totalChars, 1))  // 每字時間
            let dynamicAlpha: Double
            if speedPerChar < 0.1 {
                dynamicAlpha = 0.15  // 快速語音：更快響應
            } else if speedPerChar > 0.2 {
                dynamicAlpha = 0.35  // 慢速語音：更平滑
            } else {
                dynamicAlpha = 0.25  // 中速語音：預設值
            }
            
            #if DEBUG
            print("[TTS][ZH] speedPerChar=\(String(format: "%.3f", speedPerChar))s, alpha=\(String(format: "%.2f", dynamicAlpha))")
            #endif
            
            // 🔥 優化 6: 音訊波形分析（檢測實際發音時間點）
            let silenceDetection = detectSilenceRegions(audioData: data)
            let leadingSilence = silenceDetection.leadingSilence
            let trailingSilence = silenceDetection.trailingSilence
            
            #if DEBUG
            print("[TTS][ZH] leadingSilence=\(String(format: "%.2f", leadingSilence))s, trailingSilence=\(String(format: "%.2f", trailingSilence))s")
            #endif
            
            var smoothedProgress = 0.0
            textTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                guard let player = self.audioPlayer else {
                    timer.invalidate()
                    return
                }
                
                if player.isPlaying {
                    // 等待播放器確實開始
                    if !didStartPlayback {
                        if player.currentTime <= 0 {
                            #if DEBUG
                            print("[TTS] waiting for playback start...")
                            #endif
                            return
                        }
                        didStartPlayback = true
                    }
                    
                    // 🔥 優化 6: 使用波形分析結果調整時間軸
                    let adjustedCurrentTime = max(0, player.currentTime - leadingSilence)
                    let adjustedDuration = max(0.001, player.duration - leadingSilence - trailingSilence)
                    
                    // Base percentage from player（使用調整後的時間）
                    let raw = max(0.0, min(1.0, adjustedCurrentTime / adjustedDuration))
                    
                    if self.selectedLanguage == .chinese {
                        // 以句子為單位的進度（與英/日一致）
                        var adjustedPercentage = raw
                        if raw < 0.03 {
                            adjustedPercentage = 0.0
                        } else if raw > 0.95 {
                            adjustedPercentage = 1.0
                        } else {
                            adjustedPercentage = (raw - 0.03) / 0.92
                        }

                        smoothedProgress = smoothedProgress * (1.0 - dynamicAlpha) + adjustedPercentage * dynamicAlpha
                        let progress = max(0.0, min(1.0, smoothedProgress))
                        let charIndex: Int
                        if zhTotal > 0 {
                            charIndex = indexForChineseProgress(progress: progress, cumulative: zhCumulative)
                        } else {
                            charIndex = Int(Double(displayCharsCount) * progress)
                        }
                        let alignedIndex = nearestSpeakableIndex(from: charIndex, speakableMask: zhSpeakableMask)
                        self.currentWordIndex = min(alignedIndex, displayCharsCount)
                        self.calculateCurrentSentence(charIndex: alignedIndex)
                    } else if self.selectedLanguage == .english {
                        // 🇺🇸 英文時間校正
                        var adjustedPercentage = raw
                        if raw < 0.03 {
                            adjustedPercentage = 0.0
                        } else if raw > 0.95 {
                            adjustedPercentage = 1.0
                        } else {
                            adjustedPercentage = (raw - 0.03) / 0.92
                        }

                        smoothedProgress = smoothedProgress * (1.0 - dynamicAlpha) + adjustedPercentage * dynamicAlpha
                        let progress = max(0.0, min(1.0, smoothedProgress))
                        let charIndex = Int(Double(displayCharsCount) * progress)
                        self.currentWordIndex = charIndex
                        self.calculateCurrentSentence(charIndex: charIndex)
                    } else if self.selectedLanguage == .japanese {
                        // 🇯🇵 日文時間校正
                        var adjustedPercentage = raw
                        if raw < 0.03 {
                            adjustedPercentage = 0.0
                        } else if raw > 0.95 {
                            adjustedPercentage = 1.0
                        } else {
                            adjustedPercentage = (raw - 0.03) / 0.92
                        }

                        smoothedProgress = smoothedProgress * (1.0 - dynamicAlpha) + adjustedPercentage * dynamicAlpha
                        let progress = max(0.0, min(1.0, smoothedProgress))
                        let charIndex = Int(Double(displayCharsCount) * progress)
                        self.currentWordIndex = charIndex
                        self.calculateCurrentSentence(charIndex: charIndex)
                    }
                    
                } else {
                    timer.invalidate()
                    let endIndex: Int
                    if self.selectedLanguage == .chinese {
                        endIndex = displayCharsCount
                    } else {
                        endIndex = displayCharsCount
                    }
                    self.currentWordIndex = endIndex
                    self.currentSentenceIndex = max(0, self.englishSentences.count - 1)
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

    func markIntroAsUsed(for language: AppLanguage) {
        switch language {
        case .chinese:
            hasPlayedChineseIntro = true
        case .english:
            hasPlayedEnglishIntro = true
        case .japanese:
            hasPlayedJapaneseIntro = true
        }
    }
    
    func focusButton(proxy: ScrollViewProxy) -> some View {
        Button(action: {
            isUserScrolling = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring()) {
                    let targetIndex = (selectedLanguage == .chinese) ? currentWordIndex : currentSentenceIndex
                    proxy.scrollTo(targetIndex, anchor: .center)
                }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                Text(localizedText.focusButton).font(.caption).bold()
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

// MARK: - 新增獨立中文內容視圖（卡拉OK效果）
struct ChineseContentView: View {
    let characterData: [(char: String, bopomofo: String)]
    let isPlaying: Bool
    let currentWordIndex: Int
    let isUserScrolling: Bool
    let onScrollTo: (Int) -> Void
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 38), spacing: 2)], alignment: .leading, spacing: 10) {
            ForEach(Array(characterData.enumerated()), id: \.offset) { index, item in
                ChineseCharacterView(
                    character: item.char,
                    bopomofo: item.bopomofo,
                    index: index,
                    currentIndex: currentWordIndex,
                    isPlaying: isPlaying
                )
                .id(index)
            }
        }
        .padding()
        .onChange(of: currentWordIndex) { _, newIndex in
            if newIndex > 0 && !isUserScrolling {
                onScrollTo(newIndex)
            }
        }
    }
}

// MARK: - 🎤 中文單字卡拉OK組件
struct ChineseCharacterView: View {
    let character: String
    let bopomofo: String
    let index: Int
    let currentIndex: Int
    let isPlaying: Bool
    
    var body: some View {
        let isCurrent = index == currentIndex  // 正在唸
        
        VStack(spacing: 0) {
            // 注音符號
            if !bopomofo.isEmpty {
                Text(bopomofo)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(getBopomofoColor())
                    .opacity(getBopomofoOpacity())
                    .fixedSize()
            }
            
            // 漢字
            Text(character)
                .font(.system(size: 26, weight: isCurrent ? .heavy : .bold, design: .rounded))
                .foregroundColor(getCharacterColor())
                .shadow(color: isCurrent && isPlaying ? Color.MagicBlue.opacity(0.5) : .clear, radius: 8)
        }
        .frame(minWidth: 38)
        .scaleEffect(isCurrent && isPlaying ? 1.25 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isCurrent)
    }
    
    // 🎨 注音符號顏色
    private func getBopomofoColor() -> Color {
        if !isPlaying {
            return .gray.opacity(0.6)
        }
        
        if index < currentIndex {
            return .MagicBlue.opacity(0.8)  // 已唸過：藍色半透明
        } else if index == currentIndex {
            return .ButtonRed  // 正在唸：紅色
        } else {
            return .gray.opacity(0.5)  // 未唸：灰色
        }
    }
    
    // 🎨 注音符號透明度
    private func getBopomofoOpacity() -> Double {
        if !isPlaying {
            return 1.0
        }
        
        if index == currentIndex {
            return 1.0  // 正在唸：完全不透明
        } else {
            return 0.7  // 其他：稍微透明
        }
    }
    
    // 🎨 漢字顏色（卡拉OK漸變效果）
    private func getCharacterColor() -> Color {
        if !isPlaying {
            return .gray.opacity(0.5)
        }
        
        if index < currentIndex {
            return .MagicBlue  // 已唸過：藍色
        } else if index == currentIndex {
            return .ButtonRed  // 正在唸：紅色（卡拉OK效果）
        } else {
            return .gray.opacity(0.4)  // 未唸：淺灰色
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
                    .foregroundColor(isActive ? .MagicBlue : .gray.opacity(0.7))
                    .multilineTextAlignment(.leading)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isActive ? Color.white : Color.white.opacity(0.5))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(isActive ? 0.1 : 0), radius: 4, x: 0, y: 2)
                    .scaleEffect(isActive ? 1.02 : 1.0)
                    .animation(isActive ? .spring() : .none, value: isPlaying ? currentSentenceIndex : 0)
                    .id(index)
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
        .onChange(of: currentSentenceIndex) { _, newIndex in
            if !isUserScrolling {
                onScrollTo(newIndex)
            }
        }
    }
}

// MARK: - 新增獨立日文內容視圖（使用振假名）
struct JapaneseContentView: View {
    let japaneseSentences: [String]
    let isPlaying: Bool
    let currentSentenceIndex: Int
    let isUserScrolling: Bool
    let onScrollTo: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(japaneseSentences.enumerated()), id: \.offset) { index, sentence in
                let isActive = isPlaying && (index == currentSentenceIndex)
                
                // 🇯🇵 使用新的 FuriganaText 顯示振假名（漢字正上方）
                FuriganaText(
                    sentence,
                    fontSize: isActive ? 20 : 18,
                    fontWeight: isActive ? .bold : .regular,
                    textColor: isActive ? .MagicBlue : .gray.opacity(0.7)
                )
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isActive ? Color.white : Color.white.opacity(0.5))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(isActive ? 0.1 : 0), radius: 4, x: 0, y: 2)
                .scaleEffect(isActive ? 1.02 : 1.0)
                .animation(isActive ? .spring() : .none, value: isPlaying ? currentSentenceIndex : 0)
                .id(index)
                .onTapGesture {  }
            }
            
            if japaneseSentences.count > 2 && currentSentenceIndex < japaneseSentences.count - 1 && !isUserScrolling {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.MagicBlue.opacity(0.6))
                    .padding(.bottom, 10)
                    .opacity(isPlaying ? 0 : 1)
            }
        }
        .padding()
        .padding(.bottom, 40)
        .onChange(of: currentSentenceIndex) { _, newIndex in
            if !isUserScrolling {
                onScrollTo(newIndex)
            }
        }
    }
}

// MARK: - 中文卡片式內容視圖（每字上方顯示注音）
struct ChineseCardContentView: View {
    let sentences: [String]
    let isPlaying: Bool
    let currentSentenceIndex: Int
    let isUserScrolling: Bool
    let onScrollTo: (Int) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                let isActive = isPlaying && (index == currentSentenceIndex)
                // 將句子拆成 (字, 注音) 陣列
                let pairs = sentence.toBopomofoCharacter()

                // 逐字顯示：注音在上、漢字在下
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(pairs.enumerated()), id: \.offset) { _, item in
                            VStack(spacing: 2) {
                                if !item.bopomofo.isEmpty {
                                    Text(item.bopomofo)
                                        .font(.system(size: 10))
                                        .foregroundColor(isActive ? .MagicBlue : .gray.opacity(0.6))
                                        .fixedSize()
                                } else {
                                    // 佔位，讓無注音的標點/空白對齊
                                    Text(" ")
                                        .font(.system(size: 10))
                                        .foregroundColor(.clear)
                                }
                                Text(item.char)
                                    .font(.system(size: isActive ? 22 : 20, weight: isActive ? .bold : .regular, design: .rounded))
                                    .foregroundColor(isActive ? .ButtonRed : .DarkText.opacity(0.8))
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 2)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isActive ? Color.white : Color.white.opacity(0.5))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(isActive ? 0.1 : 0), radius: 4, x: 0, y: 2)
                .scaleEffect(isActive ? 1.02 : 1.0)
                .animation(isActive ? .spring() : .none, value: isPlaying ? currentSentenceIndex : 0)
                .id("Sentence-\(index)")
            }

            if sentences.count > 2 && currentSentenceIndex < sentences.count - 1 && !isUserScrolling {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.MagicBlue.opacity(0.6))
                    .padding(.bottom, 10)
                    .opacity(isPlaying ? 0 : 1)
            }
        }
        .padding()
        .padding(.bottom, 40)
        .onChange(of: currentSentenceIndex) { _, newIndex in
            if !isUserScrolling {
                onScrollTo(newIndex)
            }
        }
    }
}

// MARK: - 輔助元件與擴充

struct WordToken: Identifiable {
    let id: Int
    let text: String
    let start: Int
    let length: Int
    let isWord: Bool
}

struct EnglishWordFlowContentView: View {
    let tokens: [WordToken]
    let fullText: String
    let isPlaying: Bool
    let currentWordIndex: Int
    let isUserScrolling: Bool
    let onScrollTo: (Int) -> Void

    @ViewBuilder
    private var content: some View {
        if tokens.isEmpty {
            Text(fullText)
                .font(.system(size: 20, weight: .regular, design: .rounded))
                .foregroundColor(.gray.opacity(0.8))
                .multilineTextAlignment(.leading)
        } else {
            FlowLayout(spacing: 6) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                    let tokenIndex = token.id
                    let isCurrent = isPlaying && token.isWord && tokenIndex == currentWordIndex
                    let isPast = isPlaying && token.isWord && tokenIndex < currentWordIndex
                    let color: Color = {
                        if !isPlaying {
                            return .gray.opacity(0.7)
                        }
                        if token.isWord {
                            return isCurrent ? .ButtonRed : (isPast ? .MagicBlue : .gray.opacity(0.6))
                        }
                        return .gray.opacity(0.6)
                    }()

                    Text(token.text)
                        .font(.system(size: isCurrent ? 22 : 20, weight: isCurrent ? .bold : .regular, design: .rounded))
                        .foregroundColor(color)
                        .scaleEffect(isCurrent ? 1.08 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: currentWordIndex)
                        .id(token.id)
                }
            }
        }
    }

    var body: some View {
        content
            .padding()
            .padding(.bottom, 40)
            .onChange(of: currentWordIndex) { _, newIndex in
                if newIndex > 0 && !isUserScrolling {
                    onScrollTo(newIndex)
                }
            }
    }
}

struct JapaneseWordFlowContentView: View {
    let tokens: [WordToken]
    let fullText: String
    let isPlaying: Bool
    let currentWordIndex: Int
    let isUserScrolling: Bool
    let onScrollTo: (Int) -> Void

    @ViewBuilder
    private var content: some View {
        if tokens.isEmpty {
            FuriganaText(
                fullText,
                fontSize: 20,
                fontWeight: .regular,
                textColor: .gray.opacity(0.8)
            )
        } else {
            FlowLayout(spacing: 4) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                    let tokenIndex = token.id
                    let isCurrent = isPlaying && token.isWord && tokenIndex == currentWordIndex
                    let isPast = isPlaying && token.isWord && tokenIndex < currentWordIndex
                    let color: Color = {
                        if !isPlaying {
                            return .gray.opacity(0.7)
                        }
                        if token.isWord {
                            return isCurrent ? .ButtonRed : (isPast ? .MagicBlue : .gray.opacity(0.6))
                        }
                        return .gray.opacity(0.6)
                    }()

                    if token.isWord {
                        FuriganaText(
                            token.text,
                            fontSize: isCurrent ? 22 : 20,
                            fontWeight: isCurrent ? .bold : .regular,
                            textColor: color
                        )
                        .scaleEffect(isCurrent ? 1.06 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: currentWordIndex)
                        .id(token.id)
                    } else {
                        Text(token.text)
                            .font(.system(size: 18, weight: .regular, design: .rounded))
                            .foregroundColor(color)
                            .id(token.id)
                    }
                }
            }
        }
    }

    var body: some View {
        content
            .padding()
            .padding(.bottom, 40)
            .onChange(of: currentWordIndex) { _, newIndex in
                if newIndex > 0 && !isUserScrolling {
                    onScrollTo(newIndex)
                }
            }
    }
}

struct ParentalGateView: View {
    @Binding var isPresented: Bool
    let language: AppLanguage
    var onSuccess: () -> Void
    
    @State private var num1 = Int.random(in: 1...5)
    @State private var num2 = Int.random(in: 1...5)
    @State private var answer = ""
    @State private var showError = false
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .opacity(opacity)
            
            VStack(spacing: 20) {
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.MagicBlue)
                
                Text(titleText)
                    .font(.headline)
                    .foregroundColor(.black)
                
                Text(questionText)
                    .font(.title2).bold()
                    .foregroundColor(.black)
                
                TextField(answerPlaceholder, text: $answer)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .frame(width: 100)
                    .foregroundColor(.black)
                
                if showError {
                    Text(errorText)
                        .foregroundColor(.red)
                        .font(.caption)
                        .transition(.scale.combined(with: .opacity))
                }
                
                HStack {
                    Button(cancelText) {
                        withAnimation(.spring(response: 0.3)) {
                            isPresented = false
                        }
                    }
                    .foregroundColor(.gray)
                    
                    Spacer().frame(width: 40)
                    
                    Button(confirmText) {
                        let input = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                        if Int(input) == (num1 + num2) {
                            withAnimation(.spring(response: 0.3)) {
                                onSuccess()
                                isPresented = false
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                showError = true
                            }
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
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            // 🎬 彈出動畫
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }

    private var titleText: String {
        switch language {
        case .chinese:
            return "家長確認 (Parent Gate)"
        case .english:
            return "Parent Gate"
        case .japanese:
            return "保護者(ほごしゃ)確認"
        }
    }

    private var questionText: String {
        switch language {
        case .chinese:
            return "請回答：\(num1) + \(num2) = ?"
        case .english:
            return "Please answer: \(num1) + \(num2) = ?"
        case .japanese:
            return "こたえてね：\(num1) + \(num2) = ?"
        }
    }

    private var answerPlaceholder: String {
        switch language {
        case .chinese:
            return "答案"
        case .english:
            return "Answer"
        case .japanese:
            return "こたえ"
        }
    }

    private var errorText: String {
        switch language {
        case .chinese:
            return "答案錯誤，請再試一次"
        case .english:
            return "Wrong answer, try again."
        case .japanese:
            return "ちがうよ。もう一度(いちど)ためしてね"
        }
    }

    private var cancelText: String {
        switch language {
        case .chinese:
            return "取消"
        case .english:
            return "Cancel"
        case .japanese:
            return "キャンセル"
        }
    }

    private var confirmText: String {
        switch language {
        case .chinese:
            return "確認"
        case .english:
            return "Confirm"
        case .japanese:
            return "確認"
        }
    }
}

struct LoadingCoverView: View {
    @State private var isRotating = false
    @State private var isPulsing = false
    @State private var orbitRotation: Double = 0
    @State private var opacity: Double = 0
    @State private var layoutSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let currentSize = layoutSize == .zero ? geo.size : layoutSize
            let safeWidth = max(1, currentSize.width)
            let safeHeight = max(1, currentSize.height)
            let isLandscape = safeWidth > safeHeight
            // 以最短邊作為基準，確保直式也不會超出畫面
            let minSide = max(1, min(safeWidth, safeHeight))
            let baseScale: CGFloat = isLandscape ? 0.85 : 1.0
            let ringOuterSize = minSide * 0.50 * baseScale   // 外環尺寸
            let ringInnerSize = minSide * 0.43 * baseScale   // 中環尺寸
            let globeSize     = minSide * 0.28 * baseScale   // 地球尺寸
            let orbitRadius   = ringOuterSize * 0.43 // 星星軌道半徑

            ZStack {
                // 背景層
                Image("KnowledgeBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.3)

                LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.95), Color.SoftBlue.opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // 主要內容
                VStack(spacing: minSide * (isLandscape ? 0.05 : 0.08)) {
                    ZStack {
                        // 外圍光環 (象徵知識傳播)
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.MagicBlue.opacity(0.3), .purple.opacity(0.2)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: max(2, minSide * 0.008)
                            )
                            .frame(width: ringOuterSize, height: ringOuterSize)
                            .scaleEffect(isPulsing ? 1.08 : 1.0)
                            .opacity(isPulsing ? 0.35 : 0.6)
                            .animation(
                                Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                value: isPulsing
                            )

                        // 中層光環
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.green.opacity(0.3), .blue.opacity(0.2)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: max(1.5, minSide * 0.006)
                            )
                            .frame(width: ringInnerSize, height: ringInnerSize)
                            .scaleEffect(isPulsing ? 1.06 : 1.0)
                            .opacity(isPulsing ? 0.45 : 0.7)
                            .animation(
                                Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.25),
                                value: isPulsing
                            )

                        // 主要地球圖示（可替換為自家資產 Image("AppGlobe")）
                        Image(systemName: "globe.asia.australia.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: globeSize, height: globeSize)
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .MagicBlue, .green]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .rotationEffect(Angle(degrees: isRotating ? 360 : 0))
                            .animation(
                                Animation.linear(duration: 8.0).repeatForever(autoreverses: false),
                                value: isRotating
                            )
                            .shadow(color: .MagicBlue.opacity(0.35), radius: minSide * 0.03, x: 0, y: minSide * 0.01)

                        // 環繞的小星星 (象徵多語言、多文化)
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: "star.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: max(10, minSide * 0.04), height: max(10, minSide * 0.04))
                                .foregroundColor(.yellow.opacity(0.85))
                                .offset(x: orbitRadius)
                                .rotationEffect(Angle(degrees: orbitRotation + Double(index) * 120))
                                .animation(
                                    Animation.linear(duration: 4.0).repeatForever(autoreverses: false),
                                    value: orbitRotation
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .opacity(opacity)
                    .scaleEffect(opacity)

                    // 載入指示器
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .MagicBlue))
                        .scaleEffect(max(1.1, minSide * 0.0025))
                        .opacity(opacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, max(16, minSide * 0.05))
                .padding(.vertical, max(16, minSide * (isLandscape ? 0.03 : 0.05)))
            }
            .onAppear {
                // 淡入動畫
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 1.0
                }
                // 啟動動畫
                isRotating = true
                isPulsing = true
                withAnimation { orbitRotation = 360 }
            }
            .onAppear {
                layoutSize = geo.size
            }
            .onChange(of: geo.size) { _, newSize in
                let widthDelta = abs(layoutSize.width - newSize.width)
                let heightDelta = abs(layoutSize.height - newSize.height)
                guard widthDelta > 1 || heightDelta > 1 else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    layoutSize = newSize
                }
            }
        }
        .ignoresSafeArea() // 確保覆蓋到全畫面
    }
}

struct ThinkingAnimationView: View {
    let language: AppLanguage
    @State private var isAnimating = false
    var body: some View {
        let localizedText = LocalizedStrings(language: language)
        VStack(spacing: 15) {
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle().fill(Color.MagicBlue.opacity(0.6)).frame(width: 12, height: 12).scaleEffect(isAnimating ? 1.0 : 0.5).opacity(isAnimating ? 1.0 : 0.3).animation(Animation.easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2), value: isAnimating)
                }
            }
            Text(localizedText.thinkingText).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.gray.opacity(0.8))
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
    
    func cleanForTTS(language: AppLanguage = .chinese) -> String {
        var text = self
        
        print("🎤 原始文字（\(language.rawValue)）：\(text)")
        
        // 移除 Markdown 格式
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "#", with: "")
        text = text.replacingOccurrences(of: "`", with: "")
        
        // 🇯🇵 日文專用處理：移除振假名括號，避免奇怪發音
        if language == .japanese {
            // 1. 移除 Emoji（但保留日文字符）
            var cleanedText = ""
            for scalar in text.unicodeScalars {
                // 保留非 Emoji 的字符（包括日文、中文、標點等）
                if !scalar.properties.isEmoji || !scalar.properties.isEmojiPresentation {
                    cleanedText.append(Character(scalar))
                }
            }
            text = cleanedText
            print("🇯🇵 移除 Emoji 後：\(text)")
            
            // 2. 移除 ruby 標記（保留括號外的文字）
            do {
                let rubyRegex = try NSRegularExpression(pattern: "<ruby>(.*?)<rt>.*?</rt></ruby>", options: [.dotMatchesLineSeparators, .caseInsensitive])
                let range = NSRange(text.startIndex..., in: text)
                text = rubyRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1")
            } catch {
                print("❌ ruby 正則表達式錯誤：\(error)")
            }
            text = text.replacingOccurrences(of: "<ruby>", with: "")
            text = text.replacingOccurrences(of: "</ruby>", with: "")
            text = text.replacingOccurrences(of: "<rt>", with: "")
            text = text.replacingOccurrences(of: "</rt>", with: "")
            
            // 2. 移除振假名括號內容（保留括號外的文字）
            // 例如：動物(どうぶつ) → 動物
            // 例如：最初(さいしょ) → 最初
            do {
                // 匹配括號和裡面的平假名、片假名
                let regex = try NSRegularExpression(pattern: "\\([ぁ-んァ-ヴー]+\\)", options: [])
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
                print("🇯🇵 移除振假名括號後：\(text)")
            } catch {
                print("❌ 正則表達式錯誤：\(error)")
            }
            
            // 3. 移除波浪號（可能造成奇怪發音）
            text = text.replacingOccurrences(of: "〜", with: "")
            text = text.replacingOccurrences(of: "～", with: "")
            
            // 4. 統一標點後的停頓
            text = text.replacingOccurrences(of: "。", with: "。 ")
            text = text.replacingOccurrences(of: "、", with: "、 ")
            text = text.replacingOccurrences(of: "？", with: "？ ")
            text = text.replacingOccurrences(of: "！", with: "！ ")
            
            // 5. 移除換行符號
            text = text.replacingOccurrences(of: "\n", with: " ")
            
            // 6. 移除過多的連續空格
            while text.contains("  ") {
                text = text.replacingOccurrences(of: "  ", with: " ")
            }
            
            print("🇯🇵 日文 TTS 最終文字：\(text)")
        } else {
            // 中文和英文：先移除 Emoji，再處理換行
            text = text.unicodeScalars.filter { !($0.properties.isEmoji && $0.properties.isEmojiPresentation) }.reduce("") { $0 + String($1) }
            text = text.replacingOccurrences(of: "\n", with: "，")
        }
        
        let result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        print("✅ TTS 最終輸入（長度 \(result.count)）：\(result)")
        return result
    }
}

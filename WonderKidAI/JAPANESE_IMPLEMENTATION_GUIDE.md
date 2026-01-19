# 🇯🇵 日文版實施指南 (Japanese Version Implementation Guide)

## ✅ 已完成的修改

### 1. **OpenAIService.swift**
- ✅ 新增 `AppLanguage.japanese = "ja-JP"`
- ✅ 更新 AI 系統 Prompt 加入日文版人設
- ✅ 維基百科查詢支援日文 (`ja.wikipedia.org`)
- ✅ 錯誤訊息支援日文

### 2. **SpeechService.swift**
- ✅ 語音辨識支援日文 (`ja-JP`)

### 3. **LocalizedStrings.swift** (新檔案)
- ✅ 集中管理所有 UI 文字 (中/英/日)
- ✅ 包含所有按鈕、提示、錯誤訊息

---

## 📝 接下來要做的事

### **步驟 1：修改 ContentView.swift**

由於 ContentView 檔案很大，需要手動替換以下區域：

#### A. 在檔案開頭加入狀態變數
```swift
// 在 ContentView 的 @State 區域加入
@State private var localizedText: LocalizedStrings = LocalizedStrings(language: .chinese)
```

#### B. 在 `init()` 中初始化語言
```swift
init() {
    let preferredLang = Locale.preferredLanguages.first ?? Locale.current.identifier
    
    // 🇯🇵 新增日文判斷
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
```

#### C. 在 `switchLanguage()` 函數中更新
```swift
func switchLanguage(to lang: AppLanguage) {
    localizedText = LocalizedStrings(language: lang)  // 🔥 新增這行
    
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
    currentTask?.cancel()
    currentTask = nil
    currentWordIndex = 0
    currentSentenceIndex = 0
    selectedLanguage = lang
    
    updateContentData()
}
```

#### D. 替換所有硬編碼文字

**找到並替換（使用 Xcode 的 Find & Replace）：**

| 原本的程式碼 | 替換成 |
|------------|--------|
| `selectedLanguage == .chinese ? "足跡" : "History"` | `localizedText.historyButton` |
| `selectedLanguage == .chinese ? "問：" : "Q:"` | `localizedText.questionLabel` |
| `selectedLanguage == .chinese ? "聽不懂" : "Again"` | `localizedText.againButton` |
| `selectedLanguage == .chinese ? "來源：維基百科" : "Source: Wikipedia"` | `localizedText.dataSourceCompact` |
| `selectedLanguage == .chinese ? "資料來源：維基百科" : "Data Source: Wikipedia"` | `localizedText.dataSource` |

（共約 28 處需要替換）

#### E. 替換函數中的文字

**`triggerPaywall()` 函數：**
```swift
func triggerPaywall() {
    userSpokenText = localizedText.quotaExceeded
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        showParentalGate = true
    }
}
```

**`askExplainAgain()` 函數：**
```swift
let prompt = localizedText.simplerExplanationPrompt(for: questionToAsk)
userSpokenText = localizedText.simplerExplanationRequest
```

**`cancelThinking()` 函數：**
```swift
aiResponse = localizedText.cancelled
```

**`statusText` 計算屬性：**
```swift
var statusText: String {
    switch isServerConnected {
    case true: return localizedText.statusOnline
    case false: return localizedText.statusOffline
    default: return localizedText.statusConnecting
    }
}
```

**`hintText` 計算屬性：**
```swift
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
```

---

### **步驟 2：修改語言切換 UI**

在 `topNavigationBar()` 中加入第三個按鈕：

```swift
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
```

---

### **步驟 3：修改文字顯示邏輯**

#### 問題：日文如何顯示？

**選項 A：使用假名顯示（推薦）**

日文不需要注音符號（已經有平假名/片假名），所以可以直接顯示句子：

在 `updateContentData()` 中：
```swift
func updateContentData() {
    if selectedLanguage == .chinese {
        characterData = aiResponse.toBopomofoCharacter()
    } else if selectedLanguage == .japanese {
        // 🇯🇵 日文使用句子顯示（類似英文）
        let rawSentences = aiResponse
            .replacingOccurrences(of: "。", with: "。|")
            .replacingOccurrences(of: "？", with: "？|")
            .replacingOccurrences(of: "！", with: "！|")
            .split(separator: "|")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        englishSentences = rawSentences.isEmpty ? [aiResponse] : rawSentences
    } else {
        // 英文
        let rawSentences = aiResponse
            .replacingOccurrences(of: ". ", with: ".|")
            .replacingOccurrences(of: "? ", with: "?|")
            .replacingOccurrences(of: "! ", with: "!|")
            .split(separator: "|")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        englishSentences = rawSentences.isEmpty ? [aiResponse] : rawSentences
    }
}
```

在 `conversationArea()` 中：
```swift
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
    // 英文與日文共用同一個視圖
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
```

**選項 B：使用 RubyText 顯示振假名（進階）**

如果你想要漢字上方顯示假名（類似注音），需要：

1. 建立日文轉振假名的函數（類似 `toBopomofoCharacter()`）
2. 使用 `RubyText.swift` 組件
3. 這需要呼叫日文假名轉換 API 或本地字典

---

### **步驟 4：修改其他 UI 頁面**

#### **HistoryView.swift**
```swift
// 在顯示語言標籤的地方
Text(item.language == "zh-TW" ? "🇹🇼" : (item.language == "ja-JP" ? "🇯🇵" : "🇺🇸"))
```

#### **LegalView.swift**

在 `getContent()` 函數中加入日文版本：

```swift
if type == .privacy {
    switch language {
    case .chinese:
        return """【隱私權政策摘要】..."""
    case .english:
        return """[Privacy Policy Summary]..."""
    case .japanese:
        return """
        【プライバシーポリシー概要】
        
        最終更新日：2025年12月
        
        WonderKidAI（以下「本アプリ」）は、お客様のプライバシーを非常に重視しています。
        本アプリは子ども向けに設計されており、COPPA（児童オンラインプライバシー保護法）を遵守します。
        
        1. データ収集
        - 個人を特定できる情報（氏名、住所、電話番号）は一切収集しません。
        - 音声と画像データはリアルタイムAI分析のみに使用され、処理後は直ちに破棄されます。
        - 会話履歴はすべてお客様のデバイス内にのみ保存されます。
        
        2. AI技術の使用
        - 本アプリはOpenAI APIを使用しています。
        - すべてのデータ送信は暗号化されています。
        
        3. お問い合わせ
        - プライバシーに関するご質問は開発者までご連絡ください：eric1207cvb@msn.com
        """
    }
}
```

#### **LoadingCoverView**
```swift
// 替換固定文字為動態
VStack(spacing: 10) {
    Text(LocalizedStrings(language: selectedLanguage).loadingTitle)
        .font(.system(size: 22, weight: .bold, design: .rounded))
        .foregroundColor(.DarkText)
    Text(LocalizedStrings(language: selectedLanguage).loadingSubtitle)
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .foregroundColor(.gray)
}
```

#### **ThinkingAnimationView**
```swift
Text(LocalizedStrings(language: language).thinkingText)
    .font(.system(size: 16, weight: .bold, design: .rounded))
    .foregroundColor(.gray.opacity(0.8))
```

---

### **步驟 5：測試清單**

- [ ] 切換到日文時，所有 UI 文字正確顯示
- [ ] 日文語音辨識可以正常運作
- [ ] AI 用日文回答問題
- [ ] TTS 語音用日文播放
- [ ] 維基百科查詢切換到日文版
- [ ] 歷史紀錄正確標示語言 (🇯🇵)
- [ ] 免費額度限制訊息正確顯示
- [ ] 法律條款頁面有日文版本
- [ ] 初次啟動時，日本裝置會自動選擇日文

---

## 🎨 可選的進階優化

### 1. **字體優化**
日文建議使用 `Hiragino Sans` 或系統預設：
```swift
.font(.system(size: 18, weight: .regular, design: .default))
```

### 2. **TTS 聲音調整**
OpenAI TTS 的日文聲音選項：
- `alloy` - 中性
- `echo` - 男性
- `fable` - 女性（推薦給小朋友）
- `onyx` - 低沉男性
- `nova` - 溫柔女性（目前使用）
- `shimmer` - 活潑女性

### 3. **錯誤訊息本地化**
確保所有 `print()` 的 debug 訊息也有日文版：
```swift
print("🎙️ マイクが起動しました")
```

---

## 📦 需要的資源檔案

1. **圖片素材**（如果有）
   - 無需修改，emoji 與 SF Symbols 通用

2. **App Store 資訊**
   - 準備日文版的截圖
   - 日文版 App 名稱建議：「ワンダーキッズAI」
   - 日文版描述與關鍵字

3. **RevenueCat Paywall**
   - 在 RevenueCat 後台設定日文版訂閱說明

---

## 🚀 部署前檢查

- [ ] 在日本 iPhone 上測試（或模擬器設定日文）
- [ ] 確認 App Store 上傳時選擇「日本」市場
- [ ] 測試所有購買流程的日文顯示
- [ ] 確認隱私權政策與 EULA 有日文版

---

## 💡 常見問題

**Q: 需要支援漢字的振假名（ルビ）嗎？**
A: 如果目標是 4-10 歲，建議：
- 4-6 歲：全平假名
- 7-10 歲：簡單漢字 + 振假名

可以請 AI 回答時指定：
```
請用平假名和簡單漢字回答，並在漢字上標註振假名（例如：漢字(かんじ)）
```

**Q: 如何測試日文語音辨識？**
A: 在模擬器設定：
1. Settings > General > Language & Region
2. Add Language > 日本語
3. 重啟 App

**Q: 需要分開的日文版 App 嗎？**
A: 不需要！同一個 App 可以支援多語言，使用者會根據裝置語言自動選擇。

---

## ✅ 完成後的功能

使用者可以在同一個 App 中：
- 🇹🇼 用中文問問題，看注音
- 🇺🇸 用英文問問題，看句子
- 🇯🇵 用日文問問題，看句子

所有功能邏輯完全相同，只是語言不同！

---

**祝你實施順利！如果有任何問題，歡迎隨時詢問～** 🎉

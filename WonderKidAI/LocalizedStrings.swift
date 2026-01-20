import Foundation

// 🌍 集中管理所有 UI 文字 (中/英/日三語)
struct LocalizedStrings {
    let language: AppLanguage
    
    // MARK: - 導覽列
    var historyButton: String {
        switch language {
        case .chinese: return "足跡"
        case .english: return "History"
        case .japanese: return "履歴"
        }
    }
    
    var statusOnline: String {
        switch language {
        case .chinese: return "安安老師上線中"
        case .english: return "Teacher An-An is Online"
        case .japanese: return "あんあん先生、いるよ〜"
        }
    }
    
    var statusOffline: String {
        switch language {
        case .chinese: return "老師休息中 (點我叫醒)"
        case .english: return "Teacher is Sleeping (Tap)"
        case .japanese: return "先生おねむ中（起こしてね）"
        }
    }
    
    var statusConnecting: String {
        switch language {
        case .chinese: return "正在找老師..."
        case .english: return "Connecting..."
        case .japanese: return "先生をさがしてるよ..."
        }
    }
    
    // MARK: - 主畫面提示
    var hintListening: String {
        switch language {
        case .chinese: return "安安老師在聽囉..."
        case .english: return "I'm listening..."
        case .japanese: return "ちゃんと聞いてるよ〜"
        }
    }
    
    var hintTapToSpeak: String {
        switch language {
        case .chinese: return "點一下，開始說話"
        case .english: return "Tap to speak"
        case .japanese: return "タンっ！してお話しよう"
        }
    }
    
    var hintPreparing: String {
        switch language {
        case .chinese: return "準備中..."
        case .english: return "Preparing..."
        case .japanese: return "じゅんび中..."
        }
    }
    
    var hintCancel: String {
        switch language {
        case .chinese: return "點一下取消"
        case .english: return "Tap to cancel"
        case .japanese: return "タンっ！でやめられるよ"
        }
    }
    
    var hintInterrupt: String {
        switch language {
        case .chinese: return "點紅色手手可以打斷老師喔！"
        case .english: return "Tap the red hand to interrupt!"
        case .japanese: return "赤いおててをタンっ！で止められるよ"
        }
    }
    
    // MARK: - 對話相關
    var questionLabel: String {
        switch language {
        case .chinese: return "問："
        case .english: return "Q:"
        case .japanese: return "質問："
        }
    }
    
    var againButton: String {
        switch language {
        case .chinese: return "聽不懂"
        case .english: return "Again"
        case .japanese: return "もう一度"
        }
    }
    
    var focusButton: String {
        switch language {
        case .chinese: return "唸到這"
        case .english: return "Focus"
        case .japanese: return "ここ"
        }
    }
    
    // MARK: - 系統訊息
    var quotaExceeded: String {
        switch language {
        case .chinese: return "🔒 今天的免費次數用完囉！\n請爸爸媽媽幫忙解鎖～"
        case .english: return "🔒 Free quota used up today!\nAsk parents to unlock."
        case .japanese: return "🔒 今日(きょう)の無料(むりょう)ぶん、ぜんぶ使(つか)っちゃった！\nパパママに聞(き)いてみてね〜"
        }
    }
    
    var errorStart: String {
        switch language {
        case .chinese: return "❌ 啟動失敗"
        case .english: return "❌ Start Failed"
        case .japanese: return "❌ あれれ、うまくいかなかったよ"
        }
    }
    
    var errorTooQuiet: String {
        switch language {
        case .chinese: return "🤔 太小聲囉～"
        case .english: return "🤔 Too quiet~"
        case .japanese: return "🤔 声(こえ)が小(ちい)さいかも〜"
        }
    }
    
    var errorNetwork: String {
        switch language {
        case .chinese: return "🥤 安安老師去喝口水，馬上回來～\n(請檢查網路，再試一次喔！)"
        case .english: return "🥤 Teacher An-An is taking a water break.\n(Please check connection and try again!)"
        case .japanese: return "🥤 あんあん先生、お水(みず)を飲(の)んでくるね〜\n（インターネットを確認(かくにん)してみて！）"
        }
    }

    var permissionRequest: String {
        switch language {
        case .chinese: return "請允許麥克風與語音辨識權限，才能開始錄音喔！"
        case .english: return "Please allow microphone and speech recognition to start recording."
        case .japanese: return "マイクと音声認識の許可が必要だよ。"
        }
    }

    var permissionDenied: String {
        switch language {
        case .chinese: return "麥克風或語音辨識權限被拒絕了，請到設定開啟。"
        case .english: return "Microphone or speech recognition permission is denied. Please enable it in Settings."
        case .japanese: return "許可がオフになっているよ。設定でオンにしてね。"
        }
    }
    
    var cancelled: String {
        switch language {
        case .chinese: return "好喔！那我先暫停～"
        case .english: return "Okay! Cancelled."
        case .japanese: return "わかった！ちょっと待(ま)ってるね〜"
        }
    }
    
    var simplerExplanationRequest: String {
        switch language {
        case .chinese: return "🔄 老師，可以講簡單一點嗎？"
        case .english: return "🔄 Teacher, simpler please?"
        case .japanese: return "🔄 先生(せんせい)、もっとやさしく教(おし)えて？"
        }
    }
    
    // MARK: - 頁尾
    var dataSource: String {
        switch language {
        case .chinese: return "資料來源：維基百科"
        case .english: return "Data Source: Wikipedia"
        case .japanese: return "データソース：ウィキペディア"
        }
    }
    
    var dataSourceCompact: String {
        switch language {
        case .chinese: return "來源：維基百科"
        case .english: return "Source: Wikipedia"
        case .japanese: return "出典：ウィキペディア"
        }
    }
    
    var privacyPolicy: String {
        switch language {
        case .chinese: return "隱私權政策"
        case .english: return "Privacy Policy"
        case .japanese: return "プライバシーポリシー"
        }
    }
    
    // MARK: - 歡迎詞
    var welcomeMessage: String {
        switch language {
        case .chinese:
            return "嗨！我是安安老師～\n小朋友你想知道什麼呢？"
        case .english:
            return "Hi! I am Teacher An-An.\nWhat would you like to know?"
        case .japanese:
            return "やっほー！あんあん先生だよ〜\n何(なに)が知(し)りたい？"
        }
    }
    
    var introMessage: String {
        switch language {
        case .chinese:
            return "嗨！我是安安老師，你的第一本 AI 百科全書。如果有自然、數學、地理、天文、語文、歷史，或是日常生活的問題，都可以問我喔！"
        case .english:
            return "Hello! I am Teacher An-An, your first AI encyclopedia. You can ask me about nature, math, geography, space, history, or anything in your daily life. I am here to help you!"
        case .japanese:
            return "やっほー！あんあん先生だよ。みんなの最初(さいしょ)のAI百科事典(ひゃっかじてん)なんだ。自然(しぜん)、算数(さんすう)、地理(ちり)、宇宙(うちゅう)、言葉(ことば)、歴史(れきし)、毎日(まいにち)のこと、なんでも聞(き)いてね！"
        }
    }
    
    var firstMeeting: String {
        switch language {
        case .chinese: return "👋 初次見面！"
        case .english: return "👋 Hello!"
        case .japanese: return "👋 はじめまして〜！"
        }
    }
    
    // MARK: - "再次解釋" 功能的 Prompt
    func simplerExplanationPrompt(for question: String) -> String {
        switch language {
        case .chinese:
            return """
            針對小朋友剛剛的問題：「\(question)」。
            他表示「聽不懂」剛才的解釋。
            請你執行以下任務：
            1. 絕對不要重複剛才的答案。
            2. 請改用「生活中的例子」或「童話故事的比喻」來解釋。
            3. 語氣要更慢、更像在跟 3 歲小孩說話。
            4. 開頭可以說：「沒關係，我們想像一下...」
            """
        case .english:
            return """
            Regarding the child's previous question: "\(question)".
            They did not understand the previous explanation.
            Please:
            1. Do NOT repeat the previous answer.
            2. Use a simple real-life analogy or a story metaphor.
            3. Speak as if to a 3-year-old.
            4. Start with "That's okay, let's imagine..."
            """
        case .japanese:
            return """
            子(こ)どもの質問(しつもん)：「\(question)」について。
            子(こ)どもが「わからない」って言(い)ってるよ。
            次(つぎ)のようにしてあげてね：
            1. さっきの答(こた)えは、ぜったい繰(く)り返(かえ)さないでね。
            2. 「おうちにあるもの」や「むかし話(ばなし)」でたとえて説明(せつめい)してあげて。
            3. 3歳(さい)の子(こ)に話(はな)すみたいに、ゆっくりやさしく。
            4. 「だいじょうぶだよ、いっしょに考(かんが)えてみよう...」って始(はじ)めてね。
            """
        }
    }
    
    // MARK: - 載入畫面
    var loadingTitle: String {
        switch language {
        case .chinese: return "安安老師準備中..."
        case .english: return "Teacher An-An is Preparing..."
        case .japanese: return "あんあん先生、じゅんび中..."
        }
    }
    
    var loadingSubtitle: String {
        switch language {
        case .chinese: return "正在連接神奇魔法書櫃 📖"
        case .english: return "Connecting to the Magic Library 📖"
        case .japanese: return "魔法(まほう)の本棚(ほんだな)につないでるよ 📖"
        }
    }
    
    // MARK: - 思考動畫
    var thinkingText: String {
        switch language {
        case .chinese: return "安安老師正在翻書找答案..."
        case .english: return "Checking the magic book..."
        case .japanese: return "あんあん先生、本(ほん)をめくってるよ..."
        }
    }
    
    // MARK: - 歷史紀錄語言碼
    var historyLanguageCode: String {
        switch language {
        case .chinese: return "zh-TW"
        case .english: return "en-US"
        case .japanese: return "ja-JP"
        }
    }
}

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

    var freeQuotaTitle: String {
        switch language {
        case .chinese: return "今日免費額度"
        case .english: return "Free Today"
        case .japanese: return "今日の無料ぶん"
        }
    }

    var freeQuotaLoading: String {
        switch language {
        case .chinese: return "讀取中..."
        case .english: return "Loading..."
        case .japanese: return "よみこみ中..."
        }
    }

    func freeQuotaRemainingText(remaining: Int, total: Int) -> String {
        switch language {
        case .chinese:
            return "剩 \(remaining) / \(total) 次"
        case .english:
            return "\(remaining) / \(total) left"
        case .japanese:
            return "あと \(remaining) / \(total) 回"
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
        case .english: return "I don't get it"
        case .japanese: return "わからない"
        }
    }

    var replayButton: String {
        switch language {
        case .chinese: return "重播"
        case .english: return "Replay"
        case .japanese: return "もう一度"
        }
    }

    var introButton: String {
        switch language {
        case .chinese: return "介紹"
        case .english: return "Intro"
        case .japanese: return "紹介"
        }
    }

    var simplifyButton: String {
        switch language {
        case .chinese: return "聽不懂"
        case .english: return "I don't get it"
        case .japanese: return "わからない"
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

    var errorSpeechUnavailable: String {
        switch language {
        case .chinese: return "🎙️ 聽不清楚，請再說一次～"
        case .english: return "🎙️ I couldn’t hear that. Please try again~"
        case .japanese: return "🎙️ うまく聞(き)こえなかったよ。もう一度(いちど)話(はな)してね〜"
        }
    }
    
    var errorNetwork: String {
        switch language {
        case .chinese: return "🥤 安安老師去喝口水，馬上回來～\n(請檢查網路，再試一次喔！)"
        case .english: return "🥤 Teacher An-An is taking a water break.\n(Please check connection and try again!)"
        case .japanese: return "🥤 あんあん先生、お水(みず)を飲(の)んでくるね〜\n（インターネットを確認(かくにん)してみて！）"
        }
    }

    var backendUpgradeRequired: String {
        switch language {
        case .chinese: return "伺服器正在更新中，請稍後再試。\n如果你是開發者，請先部署新版 backend。"
        case .english: return "The server is being updated.\nDeveloper note: deploy the protected backend first."
        case .japanese: return "サーバーを更新中だよ。\n開発者は新しい backend を先にデプロイしてね。"
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
        case .chinese: return "🔄 老師，請換一個角度說明。"
        case .english: return "🔄 Please explain it from another angle."
        case .japanese: return "🔄 別(べつ)の見方(みかた)で説明(せつめい)してね。"
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

    var termsOfUse: String {
        switch language {
        case .chinese: return "使用條款 (EULA)"
        case .english: return "Terms of Use (EULA)"
        case .japanese: return "利用規約 (EULA)"
        }
    }

    // MARK: - Paywall
    var paywallTitle: String {
        switch language {
        case .chinese: return "解鎖 STEM 學習"
        case .english: return "Unlock STEM Learning"
        case .japanese: return "STEM学習をもっと深く"
        }
    }

    var paywallSubtitle: String {
        switch language {
        case .chinese:
            return "用科學、數學、自然與科技的角度，幫孩子聽懂問題核心。"
        case .english:
            return "Help kids understand questions through science, math, nature, and technology. Answers stay focused, more complete, and easy to listen to."
        case .japanese:
            return "科学・算数・自然・テクノロジーの視点で、子どもの疑問をわかりやすく整理します。答えは核心に集中し、音声でも聞きやすくします。"
        }
    }

    var paywallBenefits: [String] {
        switch language {
        case .chinese:
            return [
                "每日提問不限 3 次",
                "STEM 啟發：科學、數學、自然、科技",
                "先回答核心，再補原因與例子",
                "三語語音問答，同步偏好與歷史"
            ]
        case .english:
            return [
                "No daily 3-question free limit",
                "Stronger STEM learning: science, math, and everyday technology explained in kid-friendly language",
                "More complete answers: direct first, then useful reasons and examples",
                "Voice Q&A in Chinese, English, and Japanese, with synced preferences and history"
            ]
        case .japanese:
            return [
                "1日3回の無料質問制限なし",
                "STEM理解をサポート：科学・算数・身近なテクノロジーを子ども向けに説明",
                "より詳しい回答：まず答えを伝え、必要な理由と例だけを追加",
                "中国語・英語・日本語の音声質問に対応し、設定と履歴を同期"
            ]
        }
    }

    var paywallFootnote: String {
        switch language {
        case .chinese:
            return "訂閱由 App Store 處理，可在 Apple ID 設定中管理或取消。"
        case .english:
            return "Subscriptions are handled by the App Store and can be managed or canceled in Apple ID settings."
        case .japanese:
            return "サブスクリプションは App Store で処理され、Apple ID 設定から管理・解約できます。"
        }
    }

    var paywallMonthlyTitle: String {
        switch language {
        case .chinese: return "月訂閱"
        case .english: return "Monthly"
        case .japanese: return "月額プラン"
        }
    }

    var paywallMonthlySubtitle: String {
        switch language {
        case .chinese: return "適合先試用，每月自動續訂。"
        case .english: return "Good for trying it first. Renews monthly."
        case .japanese: return "まず試したい方向け。毎月自動更新。"
        }
    }

    var paywallYearlyTitle: String {
        switch language {
        case .chinese: return "年訂閱"
        case .english: return "Yearly"
        case .japanese: return "年額プラン"
        }
    }

    var paywallYearlySubtitle: String {
        switch language {
        case .chinese: return "適合長期學習，一次解鎖全年。"
        case .english: return "Best for long-term use. Unlocks a full year."
        case .japanese: return "長く使う方向け。1年分をまとめて利用。"
        }
    }

    var paywallBestValueBadge: String {
        switch language {
        case .chinese: return "較划算"
        case .english: return "Best value"
        case .japanese: return "おすすめ"
        }
    }

    var paywallSubscribeButton: String {
        switch language {
        case .chinese: return "訂閱"
        case .english: return "Subscribe"
        case .japanese: return "登録する"
        }
    }

    var paywallLoadingPlans: String {
        switch language {
        case .chinese: return "正在讀取訂閱方案..."
        case .english: return "Loading subscription plans..."
        case .japanese: return "プランを読み込み中..."
        }
    }

    var paywallNoPlans: String {
        switch language {
        case .chinese: return "目前無法讀取訂閱方案，請稍後再試。"
        case .english: return "Subscription plans are unavailable right now. Please try again later."
        case .japanese: return "現在プランを読み込めません。あとでもう一度お試しください。"
        }
    }

    var paywallPurchaseInProgress: String {
        switch language {
        case .chinese: return "正在開啟 App Store..."
        case .english: return "Opening the App Store..."
        case .japanese: return "App Store を開いています..."
        }
    }

    var paywallRestoreButton: String {
        switch language {
        case .chinese: return "恢復購買"
        case .english: return "Restore Purchases"
        case .japanese: return "購入を復元"
        }
    }

    var paywallRestoreInProgress: String {
        switch language {
        case .chinese: return "正在恢復購買..."
        case .english: return "Restoring purchases..."
        case .japanese: return "購入を復元中..."
        }
    }

    var paywallPurchaseFailed: String {
        switch language {
        case .chinese: return "購買尚未完成，請稍後再試。"
        case .english: return "Purchase was not completed. Please try again later."
        case .japanese: return "購入が完了しませんでした。あとでもう一度お試しください。"
        }
    }

    var paywallRestoreFailed: String {
        switch language {
        case .chinese: return "沒有找到可恢復的有效訂閱。"
        case .english: return "No active subscription was found to restore."
        case .japanese: return "復元できる有効なサブスクリプションが見つかりませんでした。"
        }
    }

    var paywallCloseLabel: String {
        switch language {
        case .chinese: return "關閉"
        case .english: return "Close"
        case .japanese: return "閉じる"
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
    
    // MARK: - "聽不懂" 功能的 Prompt
    func simplerExplanationPrompt(for question: String) -> String {
        switch language {
        case .chinese:
            return """
            針對小朋友剛剛的問題：「\(question)」。
            小朋友按了「聽不懂」，請不要把答案講得更幼稚，也不要用童話或奇怪比喻。請從另一個適合孩子理解的面向重新回答同一個問題。

            請遵守：
            1. 先直接回答原問題的核心，不要鋪陳，也不要離題。
            2. 不要重複上一種說法；改從另一個面向說明，例如用途、功能、外觀、結構、形成原因、差異、孩子能觀察到的現象。只選最適合題目的一到兩個面向。
            3. 不要刻意降低年齡、不要裝可愛，使用自然、清楚、適合孩子理解的口語。
            4. 禁止童話、故事場景、魔法、擬人化、誇張比喻或無關聯想。
            5. 例子只能用真實、直接相關、生活中能看到的例子，最多一個；沒有合適例子就不要舉例。
            6. 不要加入題外話、冷知識或為了變長而補充不必要內容。
            7. 最多 2 到 3 個短段落，每段都要幫助孩子理解原問題。
            """
        case .english:
            return """
            Regarding the child's previous question: "\(question)".
            The child tapped "I don't get it". Do not make the answer more childish, and do not use fairy-tale or strange metaphors. Answer the same question from another child-friendly angle.

            Rules:
            1. Answer the core of the original question first. Do not add a long setup or drift away.
            2. Do not repeat the previous framing. Choose a different angle, such as purpose, function, shape, parts, cause, process, differences, or what a child can observe. Use only the one or two angles that best fit the question.
            3. Do not lower the age level or use baby talk. Use natural, clear language that a child can understand.
            4. Do not use fairy tales, story scenes, magic, personification, exaggerated analogies, or unrelated associations.
            5. Use at most one real, directly related example that a child could see in everyday life. If no example fits, skip the example.
            6. Do not add side facts, trivia, or filler just to make the answer longer.
            7. Use at most 2 to 3 short paragraphs, and make every paragraph help explain the original question.
            """
        case .japanese:
            return """
            子(こ)どもの質問(しつもん)：「\(question)」について。
            子(こ)どもが「わからない」を押(お)しました。答(こた)えを幼(おさな)くしすぎず、昔話(むかしばなし)や変(へん)なたとえを使(つか)わず、同(おな)じ質問(しつもん)を別(べつ)の見方(みかた)から説明(せつめい)してください。

            ルール：
            1. 最初(さいしょ)に元(もと)の質問(しつもん)の中心(ちゅうしん)へ答(こた)えてください。長(なが)い前置(まえお)きや脱線(だっせん)はしないでください。
            2. 前(まえ)と同(おな)じ説明(せつめい)をくり返(かえ)さず、別(べつ)の見方(みかた)を選(えら)んでください。たとえば、役割(やくわり)、はたらき、形(かたち)、つくり、理由(りゆう)、でき方(かた)、ちがい、子(こ)どもが観察(かんさつ)できることです。質問(しつもん)に合(あ)うものを一(ひと)つか二(ふた)つだけ使(つか)ってください。
            3. 年齢(ねんれい)を下(さ)げすぎたり、赤(あか)ちゃん向(む)けの言(い)い方(かた)にしたりしないでください。自然(しぜん)で、子(こ)どもが理解(りかい)しやすい言葉(ことば)にしてください。
            4. 昔話(むかしばなし)、物語(ものがたり)の場面(ばめん)、魔法(まほう)、擬人化(ぎじんか)、大(おお)げさなたとえ、関係(かんけい)ない連想(れんそう)は使(つか)わないでください。
            5. 例(れい)は、本当(ほんとう)に関係(かんけい)があり、生活(せいかつ)の中(なか)で見(み)られるものを一(ひと)つまでにしてください。合(あ)う例(れい)がなければ、例(れい)は出(だ)さないでください。
            6. 関係(かんけい)ない豆知識(まめちしき)や、長(なが)くするためだけの説明(せつめい)は入(い)れないでください。
            7. 短(みじか)い段落(だんらく)は 2〜3 個(こ)までにして、どの段落(だんらく)も元(もと)の質問(しつもん)を理解(りかい)する助(たす)けになる内容(ないよう)にしてください。
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

    func waitingTitle(for stage: AssistantWaitingStage) -> String {
        switch language {
        case .chinese:
            switch stage {
            case .craftingAnswer: return "安安老師正在想答案"
            case .generatingVoice: return "安安老師正在把答案變成聲音"
            case .preparingPlayback: return "安安老師正在準備播放聲音"
            }
        case .english:
            switch stage {
            case .craftingAnswer: return "Teacher An-An is thinking"
            case .generatingVoice: return "Teacher An-An is making the voice"
            case .preparingPlayback: return "Teacher An-An is getting the audio ready"
            }
        case .japanese:
            switch stage {
            case .craftingAnswer: return "あんあん先生、答(こた)えを考(かんが)え中(ちゅう)"
            case .generatingVoice: return "声(こえ)を作(つく)っているよ"
            case .preparingPlayback: return "もうすぐ聞(き)けるよ"
            }
        }
    }

    func waitingSubtitle(for stage: AssistantWaitingStage) -> String {
        switch language {
        case .chinese:
            switch stage {
            case .craftingAnswer: return "先把重點整理好，等一下會用小朋友聽得懂的方式說給你聽。"
            case .generatingVoice: return "正在把剛剛的答案做成溫柔語音，進度會慢慢往前走。"
            case .preparingPlayback: return "最後把聲音和字幕對好，下一秒就會開始播放。"
            }
        case .english:
            switch stage {
            case .craftingAnswer: return "Putting the idea together in a kid-friendly way."
            case .generatingVoice: return "Turning the answer into a gentle voice, one step at a time."
            case .preparingPlayback: return "Matching the audio and captions before playback starts."
            }
        case .japanese:
            switch stage {
            case .craftingAnswer: return "わかりやすく伝(つた)えるために、やさしくまとめているよ。"
            case .generatingVoice: return "答(こた)えを、やさしい声(こえ)にしているよ。"
            case .preparingPlayback: return "声(こえ)と字幕(じまく)をそろえているよ。"
            }
        }
    }

    func waitingBadge(for stage: AssistantWaitingStage) -> String {
        switch language {
        case .chinese:
            switch stage {
            case .craftingAnswer: return "思考中"
            case .generatingVoice: return "語音生成"
            case .preparingPlayback: return "準備播放"
            }
        case .english:
            switch stage {
            case .craftingAnswer: return "Thinking"
            case .generatingVoice: return "Voice"
            case .preparingPlayback: return "Ready"
            }
        case .japanese:
            switch stage {
            case .craftingAnswer: return "考え中"
            case .generatingVoice: return "音声"
            case .preparingPlayback: return "再生準備"
            }
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

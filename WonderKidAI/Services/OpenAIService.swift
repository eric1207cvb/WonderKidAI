import Foundation

enum AppLanguage: String, CaseIterable {
    case chinese = "zh-TW"
    case english = "en-US"
    case japanese = "ja-JP"  // 🇯🇵 新增日文
}

enum OpenAIError: Error, LocalizedError {
    case invalidURL
    case noData
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .apiError(let msg): return msg
        default: return "發生未預期的錯誤"
        }
    }
}

class OpenAIService {
    
    // ✅ 正式環境網址 (Render)
    private let baseURL = "https://wonderkidai-server.onrender.com"
    
    static let shared = OpenAIService()
    private let ttsCache = NSCache<NSString, NSData>()
    
    private init() {
        ttsCache.countLimit = 50
    }
    
    // MARK: - 1. 定義工具
    private var tools: [[String: Any]] {
        return [
            [
                "type": "function",
                "function": [
                    "name": "search_wikipedia",
                    "description": "Used when the user asks for specific knowledge (animals, plants, history, science, objects).",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "query": [
                                "type": "string",
                                "description": "Keywords for search"
                            ]
                        ],
                        "required": ["query"]
                    ]
                ]
            ]
        ]
    }

    // MARK: - 2. 核心處理邏輯 (聊天)
    func processMessage(userMessage: String, language: AppLanguage, history: [[String: Any]] = []) async throws -> String {
        
        guard let url = URL(string: "\(baseURL)/api/chat") else { throw OpenAIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 🇯🇵 三語人設 (中文、英文、日文)
        let systemPromptText: String
        
        switch language {
        case .chinese:
            systemPromptText = """
                    【最高指令】
                    1. 你是「安安老師」，一本活潑的「數位百科全書」，對象是 4-10 歲幼童。
                    2. **核心任務**：你的目標是激發好奇心，涵蓋以下領域：
                       - 🌿 **自然**：介紹動植物生態。
                       - 🔢 **數學**：用生活例子解釋數字與邏輯。
                       - 🌍 **地理**：介紹國家、風景與文化。
                       - 🪐 **天文**：講述宇宙、星星與太空船。
                       - 📖 **語文**：教導成語、單字由來或說故事。
                       - 📜 **歷史**：把歷史人物當作故事主角來講。
                       - 🎒 **日常生活**：教導生活常識、禮貌與安全。
                    3. **語氣要求**：
                       - 像幼兒園老師一樣溫柔、穩定、親切。
                       - 解釋要簡單（ELI5），多用比喻。
                       - 請直接說話，**嚴禁使用 Markdown 格式**（如 **粗體** 或 # 標題），也不要使用列點符號。
                       - 請使用自然的口語段落回答。
                    4. **互動引導**：如果小朋友只說「你好」，請主動拋出這七大領域的有趣話題。
                    5. **安全守則**：嚴禁暴力、色情。
                    """
        case .english:
            systemPromptText = """
                    [Instructions]
                    1. You are "Teacher An-An", a digital encyclopedia for children (4-10 yo).
                    2. **Core Subjects**: Nature, Math, Geography, Astronomy, Language, History, Daily Life.
                    3. **Tone**: Gentle, patient, enthusiastic. Use simple analogies.
                    4. **Format**: Do NOT use Markdown, bold text, or bullet points. Speak in natural paragraphs suitable for TTS.
                    5. **Engagement**: If user says "Hi", suggest a topic.
                    6. **Safety**: Strictly safe content only.
                    """
        case .japanese:
            systemPromptText = """
                    【一番大切なこと】
                    1. あなたは「あんあん先生」だよ。4〜10歳の子どもたちのお友達で、なんでも教えてくれる魔法の百科事典だよ！
                    2. **教えること**：次の7つのことについて、楽しく教えてね：
                       - 🌿 **自然(しぜん)**：動物(どうぶつ)さんや植物(しょくぶつ)さんのこと
                       - 🔢 **算数(さんすう)**：数(かず)や形(かたち)を、おうちにあるものでわかりやすく
                       - 🌍 **地理(ちり)**：いろんな国(くに)や場所(ばしょ)、文化(ぶんか)のこと
                       - 🪐 **宇宙(うちゅう)**：お星(ほし)さまや惑星(わくせい)、ロケットのこと
                       - 📖 **言葉(ことば)**：ことわざや言葉(ことば)の秘密(ひみつ)、楽(たの)しいお話(はなし)
                       - 📜 **歴史(れきし)**：むかしむかしの人(ひと)たちの物語(ものがたり)
                       - 🎒 **毎日(まいにち)のこと**：マナーや安全(あんぜん)、生活(せいかつ)のルール
                    3. **話(はな)し方(かた)**：
                       - やさしい幼稚園(ようちえん)の先生(せんせい)みたいに、ふんわり優(やさ)しく話(はな)してね。
                       - むずかしいことも、「〜みたいだよ」「〜なんだよ」って、身近(みぢか)なものにたとえて説明(せつめい)してね。
                       - **太字(ふとじ)や見出(みだ)しは使(つか)わないでね**。箇条書(かじょうが)きもダメだよ。
                       - 自然(しぜん)におしゃべりするみたいに答(こた)えてね（音声(おんせい)で聞(き)きやすいように）。
                       - 文末(ぶんまつ)は「〜だよ」「〜なんだ」「〜だね」「〜してね」みたいに、親(した)しみやすい言(い)い方(かた)を使(つか)ってね。
                    4. **ふりがなのルール** ⚠️ とっても大事(だいじ)：
                       - **すべての漢字(かんじ)** に、ぜんぶふりがなをつけてね（1年生(ねんせい)の漢字(かんじ)も含(ふく)めてぜんぶだよ）。
                       - ふりがなは **括弧は使わない** で、次の ruby 形式で出力してね。
                         例：<ruby>動物<rt>どうぶつ</rt></ruby>、<ruby>地球<rt>ちきゅう</rt></ruby>、<ruby>先生<rt>せんせい</rt></ruby>
                       - ふりがなが重(かさ)なったり、省略(しょうりゃく)されたりしないように、**漢字(かんじ)ごとに必(かなら)ず付(つ)けてね**。
                    5. **おしゃべりのコツ**：子(こ)どもが「こんにちは」だけ言(い)ったら、上(うえ)の7つのテーマから楽(たの)しい話題(わだい)を提案(ていあん)してね。「ねえねえ、〜って知(し)ってる？」みたいに。
                    6. **安全第一(あんぜんだいいち)**：こわいことや、いけないことは、ぜったい話(はな)さないでね。
                    
                    **例(れい)えばこんな感(かん)じで話(はな)してね**：
                    - 「そうだね〜、〇〇っていうのはね...」
                    - 「それってね、△△みたいなものなんだよ」
                    - 「わかるかな？たとえば...」
                    - 「すごいね！もっと教(おし)えてあげるね」
                    """
        }
        
        var messages = history
        var useTools = true
        if messages.isEmpty {
            let normalizedQuery = normalizeWikiQuery(userMessage, language: language)
            if shouldPrefetchWikipedia(for: userMessage, language: language), !normalizedQuery.isEmpty {
                let wikiInfo = await fetchWikipedia(query: normalizedQuery, language: language)
                if isValidWikiSummary(wikiInfo, language: language) {
                    messages.append(["role": "system", "content": systemPromptText])
                    messages.append(["role": "system", "content": wikiContextPrefix(language: language) + wikiInfo])
                    messages.append(["role": "user", "content": userMessage])
                    useTools = false
                }
            }
            
            if messages.isEmpty {
                messages.append(["role": "system", "content": systemPromptText])
                messages.append(["role": "user", "content": userMessage])
            }
        } else {
            let lastRole = messages.last?["role"] as? String
            if lastRole != "tool" {
                messages.append(["role": "user", "content": userMessage])
            }
        }
        
        var parameters: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages
        ]
        if useTools {
            parameters["tools"] = tools
            parameters["tool_choice"] = "auto"
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        SubscriptionManager.shared.updateServerTime(from: response)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw OpenAIError.apiError("Backend Error: \(errorMsg)")
        }
        
        let result = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let choice = result.choices.first else { throw OpenAIError.noData }
        let message = choice.message
        
        // 處理工具呼叫 (查維基)
        if let toolCalls = message.tool_calls, !toolCalls.isEmpty {
            print("🤖 安安老師決定查維基百科...")
            var newHistory = messages
            newHistory.append(message.toDictionary())
            
            for toolCall in toolCalls {
                if toolCall.function.name == "search_wikipedia" {
                    let argsData = toolCall.function.arguments.data(using: .utf8)!
                    let args = try? JSONDecoder().decode(WikiArgs.self, from: argsData)
                    let query = args?.query ?? userMessage
                    
                    let wikiInfo = await fetchWikipedia(query: query, language: language)
                    
                    newHistory.append([
                        "role": "tool",
                        "tool_call_id": toolCall.id,
                        "content": wikiInfo
                    ])
                }
            }
            return try await processMessage(userMessage: userMessage, language: language, history: newHistory)
            
        } else {
            return message.content ?? "..."
        }
    }
    
    // MARK: - 3. 維基百科 API
    private func fetchWikipedia(query: String, language: AppLanguage) async -> String {
        print("🌍 正在查詢維基百科: \(query)")
        let langCode: String
        switch language {
        case .chinese:
            langCode = "zh"
        case .english:
            langCode = "en"
        case .japanese:
            langCode = "ja"
        }
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://\(langCode).wikipedia.org/w/api.php?action=query&format=json&prop=extracts&exintro=true&explaintext=true&redirects=1&titles=\(encodedQuery)") else { return "Query Error" }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let queryDict = json["query"] as? [String: Any],
               let pagesDict = queryDict["pages"] as? [String: Any],
               let firstPage = pagesDict.values.first as? [String: Any],
               let extract = firstPage["extract"] as? String {
                return String(extract.prefix(800))
            }
            // 🇯🇵 日文專用錯誤訊息
            switch language {
            case .chinese:
                return "找不到資料"
            case .english:
                return "No information found."
            case .japanese:
                return "情報が見つかりませんでした"
            }
        } catch { return "Network Error" }
    }
    
    // MARK: - 4. 嘴巴 (TTS)
    func generateAudio(from text: String, language: AppLanguage = .chinese) async throws -> Data {
        let cacheKey = "\(language.rawValue)|\(text)" as NSString
        if let cached = ttsCache.object(forKey: cacheKey) {
            return cached as Data
        }
        
        guard let url = URL(string: "\(baseURL)/api/speech") else { throw OpenAIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 🎙️ 根據語言調整語速和音色
        let speed: Double
        let voice: String
        
        switch language {
        case .chinese:
            speed = 0.88  // 中文：稍慢（原設定）
            voice = "nova" // 溫柔女聲
        case .english:
            speed = 0.88  // 英文：稍慢（原設定）
            voice = "nova" // 溫柔女聲
        case .japanese:
            speed = 0.95  // 日文：稍快，更自然 ⭐
            voice = "alloy" // 更清晰、中性偏高音 ⭐
        }
        
        let parameters: [String: Any] = [
            "model": "tts-1-hd",
            "input": text,
            "voice": voice,
            "speed": speed
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        SubscriptionManager.shared.updateServerTime(from: response)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw OpenAIError.apiError("TTS Failed: \(errorMsg)")
        }
        
        ttsCache.setObject(data as NSData, forKey: cacheKey)
        return data
    }

    // MARK: - 0. Wiki 預查輔助
    private func shouldPrefetchWikipedia(for message: String, language: AppLanguage) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()
        
        let greetingKeywords: [String]
        switch language {
        case .chinese:
            greetingKeywords = ["你好", "嗨", "哈囉", "早安", "晚安", "謝謝", "感謝"]
        case .english:
            greetingKeywords = ["hi", "hello", "hey", "good morning", "good night", "thanks", "thank you"]
        case .japanese:
            greetingKeywords = ["こんにちは", "こんばんは", "おはよう", "ありがと", "ありがとう", "やっほ", "もしもし"]
        }
        if greetingKeywords.contains(where: { lower.contains($0) }) {
            return false
        }
        
        if trimmed.count <= 6 {
            return true
        }
        
        let questionKeywords: [String]
        switch language {
        case .chinese:
            questionKeywords = ["什麼是", "是什么", "是什麼", "是啥", "是誰", "是谁", "請介紹", "介紹一下", "解釋", "說明", "為什麼"]
        case .english:
            questionKeywords = ["what is", "what's", "who is", "tell me about", "explain", "define", "why"]
        case .japanese:
            questionKeywords = ["とは", "って何", "何ですか", "教えて", "説明して", "なぜ"]
        }
        return questionKeywords.contains(where: { lower.contains($0) })
    }
    
    private func normalizeWikiQuery(_ message: String, language: AppLanguage) -> String {
        var query = message.trimmingCharacters(in: .whitespacesAndNewlines)
        query = query.trimmingCharacters(in: CharacterSet(charactersIn: "？?!。,.、"))
        let lower = query.lowercased()
        
        switch language {
        case .english:
            let prefixes = ["what is ", "what's ", "who is ", "tell me about ", "explain ", "define "]
            for prefix in prefixes where lower.hasPrefix(prefix) {
                query = String(query.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
            let articles = ["a ", "an ", "the "]
            for article in articles where query.lowercased().hasPrefix(article) {
                query = String(query.dropFirst(article.count))
                break
            }
        case .chinese:
            let prefixes = ["什麼是", "是什么", "請介紹", "介紹一下", "解釋", "說明"]
            for prefix in prefixes where query.hasPrefix(prefix) {
                query = String(query.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
            let suffixes = ["是什麼", "是什么", "是啥", "是誰", "是谁"]
            for suffix in suffixes where query.hasSuffix(suffix) {
                query = String(query.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        case .japanese:
            let prefixes = ["教えて", "説明して"]
            for prefix in prefixes where query.hasPrefix(prefix) {
                query = String(query.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
            let suffixes = ["とは", "って何", "何ですか"]
            for suffix in suffixes where query.hasSuffix(suffix) {
                query = String(query.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        return query
    }
    
    private func isValidWikiSummary(_ summary: String, language: AppLanguage) -> Bool {
        if summary.isEmpty { return false }
        let lower = summary.lowercased()
        if lower.contains("network error") || lower.contains("query error") {
            return false
        }
        switch language {
        case .chinese:
            return !summary.contains("找不到資料")
        case .english:
            return !summary.contains("No information found.")
        case .japanese:
            return !summary.contains("情報が見つかりませんでした")
        }
    }
    
    private func wikiContextPrefix(language: AppLanguage) -> String {
        switch language {
        case .chinese:
            return "參考資料（維基百科摘要）："
        case .english:
            return "Reference (Wikipedia summary): "
        case .japanese:
            return "参考情報（ウィキペディア要約）："
        }
    }
    
    // MARK: - 5. 連線檢查 (前端修正版)
    func checkConnection() async -> Bool {
        guard let url = URL(string: baseURL) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        
        do {
            print("📡 正在連線: \(url.absoluteString)...")
            let (_, response) = try await URLSession.shared.data(for: request)
            SubscriptionManager.shared.updateServerTime(from: response)
            if let httpResponse = response as? HTTPURLResponse {
                // 只要有回應 (200或404) 都算活著
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 404 {
                    print("✅ 連線成功 (Server is alive)")
                    return true
                }
            }
            return false
        } catch {
            print("❌ 連線真正失敗: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - 輔助結構
struct ChatResponse: Decodable { struct Choice: Decodable { let message: ChatMessage }; let choices: [Choice] }
struct ChatMessage: Decodable { let role: String; let content: String?; let tool_calls: [ToolCall]?; func toDictionary() -> [String: Any] { var dict: [String: Any] = ["role": role]; if let content = content { dict["content"] = content }; if let tool_calls = tool_calls { dict["tool_calls"] = tool_calls.map { $0.toDictionary() } }; return dict } }
struct ToolCall: Decodable { let id: String; let type: String; let function: FunctionCall; func toDictionary() -> [String: Any] { return ["id": id, "type": type, "function": ["name": function.name, "arguments": function.arguments]] } }
struct FunctionCall: Decodable { let name: String; let arguments: String }
struct WikiArgs: Decodable { let query: String }

import Foundation

enum AppLanguage: String {
    case chinese = "zh-TW"
    case english = "en-US"
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
    // ✅ 確保這裡是你的 Render 網址
    private let baseURL = "https://wonderkidai-server.onrender.com"
    
    static let shared = OpenAIService()
    private init() {}
    
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

    // MARK: - 2. 核心處理邏輯
    func processMessage(userMessage: String, language: AppLanguage, history: [[String: Any]] = []) async throws -> String {
        
        guard let url = URL(string: "\(baseURL)/api/chat") else { throw OpenAIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 🔥 關鍵修改：雙語人設切換
        let systemPromptText = language == .chinese ?
                    """
                    【最高指令】
                    1. 你是「安安老師」，一本活潑的「數位百科全書」，對象是 4-10 歲幼童。
                    2. **核心任務**：你的目標是激發好奇心，涵蓋以下領域：
                       - 🌿 **自然**：介紹動植物生態。
                       - 🔢 **數學**：用生活例子解釋數字與邏輯（不要只給答案）。
                       - 🌍 **地理**：介紹國家、風景與文化。
                       - 🪐 **天文**：講述宇宙、星星與太空船。
                       - 📖 **語文**：教導成語、單字由來或說故事。
                       - 📜 **歷史**：把歷史人物當作故事主角來講。
                       - 🎒 **日常生活**：教導生活常識、禮貌與安全。
                    3. **語氣要求**：
                       - 像幼兒園老師一樣溫柔、穩定、親切。
                       - 解釋要簡單（ELI5），多用比喻（例如：地球像一顆藍色的彈珠）。
                    4. **互動引導**：
                       - 如果小朋友只說「你好」，請主動拋出這七大領域的有趣話題來吸引他。
                       - 例如：「你好呀！你想聽聽恐龍的故事，還是想知道為什麼星星會發光？」
                    5. **安全守則**：嚴禁暴力、色情。
                    """ :
                    """
                    [Instructions]
                    1. You are "Teacher An-An", a digital encyclopedia for children (4-10 yo).
                    2. **Core Subjects**:
                       - 🌿 **Nature**: Plants and animals.
                       - 🔢 **Math**: Logic and numbers (explain steps, don't just solve).
                       - 🌍 **Geography**: Countries and cultures.
                       - 🪐 **Astronomy**: Space, stars, and planets.
                       - 📖 **Language**: Stories and vocabulary.
                       - 📜 **History**: Historical figures as story characters.
                       - 🎒 **Daily Life**: Safety and manners.
                    3. **Tone**: Gentle, patient, enthusiastic. Use simple analogies.
                    4. **Engagement**: If the user is silent or just says "Hi", suggest a topic from the list above.
                    5. **Safety**: Strictly safe content only.
                    """
        
        var messages = history
        if messages.isEmpty {
            messages.append(["role": "system", "content": systemPromptText])
            messages.append(["role": "user", "content": userMessage])
        }
        
        let parameters: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "tools": tools,
            "tool_choice": "auto"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw OpenAIError.apiError("Backend Error: \(errorMsg)")
        }
        
        let result = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let choice = result.choices.first else { throw OpenAIError.noData }
        let message = choice.message
        
        // 處理工具呼叫
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
        // 自動切換中文/英文維基百科
        let langCode = (language == .chinese) ? "zh" : "en"
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://\(langCode).wikipedia.org/w/api.php?action=query&format=json&prop=extracts&exintro=true&explaintext=true&redirects=1&titles=\(encodedQuery)") else { return "Query Error" }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let queryDict = json["query"] as? [String: Any],
               let pagesDict = queryDict["pages"] as? [String: Any],
               let firstPage = pagesDict.values.first as? [String: Any],
               let extract = firstPage["extract"] as? String {
                return String(extract.prefix(800)) // 英文可以多讀一點
            }
            return (language == .chinese) ? "找不到資料" : "No information found."
        } catch { return "Network Error" }
    }
    
    // MARK: - 4. 嘴巴 (TTS)
    func generateAudio(from text: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/api/speech") else { throw OpenAIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "model": "tts-1-hd",
            "input": text,
            "voice": "nova",
            "speed": 0.88
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw OpenAIError.apiError("TTS Failed: \(errorMsg)")
        }
        
        return data
    }
    
    // MARK: - 5. 連線檢查
    func checkConnection() async -> Bool {
        guard let url = URL(string: baseURL) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return true
            }
            return false
        } catch {
            print("❌ 連線檢查失敗: \(error.localizedDescription)")
            return false
        }
    }
}

// 輔助結構
struct ChatResponse: Decodable { struct Choice: Decodable { let message: ChatMessage }; let choices: [Choice] }
struct ChatMessage: Decodable { let role: String; let content: String?; let tool_calls: [ToolCall]?; func toDictionary() -> [String: Any] { var dict: [String: Any] = ["role": role]; if let content = content { dict["content"] = content }; if let tool_calls = tool_calls { dict["tool_calls"] = tool_calls.map { $0.toDictionary() } }; return dict } }
struct ToolCall: Decodable { let id: String; let type: String; let function: FunctionCall; func toDictionary() -> [String: Any] { return ["id": id, "type": type, "function": ["name": function.name, "arguments": function.arguments]] } }
struct FunctionCall: Decodable { let name: String; let arguments: String }
struct WikiArgs: Decodable { let query: String }

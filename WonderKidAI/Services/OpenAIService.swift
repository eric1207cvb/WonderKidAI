import Foundation
import CryptoKit
import RevenueCat
import Security

enum AppLanguage: String, CaseIterable {
    case chinese = "zh-TW"
    case english = "en-US"
    case japanese = "ja-JP"  // 🇯🇵 新增日文
}

enum OpenAIError: Error, LocalizedError {
    case invalidURL
    case noData
    case quotaExceeded
    case backendUpgradeRequired
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .quotaExceeded: return "Free quota exhausted"
        case .backendUpgradeRequired: return "Backend must be upgraded to the protected API contract"
        case .apiError(let msg): return msg
        default: return "發生未預期的錯誤"
        }
    }
}

private struct BackendErrorPayload: Decodable {
    let error: String?
    let message: String?
    let details: String?
}

private struct TTSVoiceProfile: Sendable {
    let model: String
    let voice: String
    let speed: Double
    let responseFormat: String
    let instructions: String
    let cacheVersion: String
}

private struct TTSAudioCacheEntry: Codable {
    let filename: String
    let byteSize: Int
    let createdAt: Date
    var lastAccessedAt: Date
}

struct AIAnswerResponse: Sendable {
    let answer: String
    let ttsInput: String
    let speechTicket: String
    let plan: String?
    let servedFromCache: Bool

    var answerDepth: AIAnswerDepth {
        plan == "pro" ? .expanded : .standard
    }
}

private struct BackendChatResponse: Decodable {
    let answer: String
    let ttsInput: String
    let speechTicket: String
    let plan: String?
}

enum AIAnswerDepth: String, Sendable {
    case standard
    case expanded

    func promptInstruction(language: AppLanguage) -> String {
        switch (self, language) {
        case (.standard, .chinese):
            return "先用第一句直接回答孩子的問題。接著用 2 到 3 個短段落補上真正有用的內容：至少包含一個『為什麼』或運作方式，以及一個孩子在生活中看得到的具體例子。回答約 230 到 280 個中文字；每一句都要提供新資訊，不要用『很特別、很有趣、可以多多觀察』這類空泛句子湊字數。適合一次語音播放。"
        case (.standard, .english):
            return "Keep the answer under 80 words, with at most 2 short paragraphs, suitable for one audio playback."
        case (.standard, .japanese):
            return "最初(さいしょ)に質問(しつもん)の答(こた)えをはっきり言(い)ってから、理由(りゆう)と身近(みぢか)な例(れい)を足(た)してね。目安(めやす)は 280〜360 字(じ)、2〜3 の短(みじか)い段落(だんらく)で、子(こ)どもが『なるほど』と思(おも)える学(まな)びを入(い)れてね。漢字(かんじ)を使(つか)う時(とき)は、子(こ)どもが読(よ)めるように必(かなら)ず 漢字(ひらがな) の形(かたち)でふりがなを付(つ)けてね。"
        case (.expanded, .chinese):
            return "付費深度模式：請先直接回答孩子問的核心問題，再補充必要原因、例子或常見誤解。內容要更好懂，但不要為了變長而加入無關聯想、延伸故事、冷知識或空泛總結。簡單問題用 2 到 3 個短段落即可；複雜問題最多 4 到 5 個短段落。保持口語、溫柔、適合一次語音播放。"
        case (.expanded, .english):
            return "Premium deep mode: answer the child's exact question first, then add only the necessary reason, example, or common misunderstanding. Make it easier to understand, but do not pad with unrelated associations, side stories, trivia, or generic recaps. Use 2 to 3 short paragraphs for simple questions and at most 4 to 5 for complex ones. Keep it natural for one audio playback."
        case (.expanded, .japanese):
            return "プレミアム深(ふか)ぼりモード：最初(さいしょ)に質問(しつもん)の核心(かくしん)へまっすぐ答(こた)えて、そのあと必要(ひつよう)な理由(りゆう)、例(れい)、まちがえやすい点(てん)だけを足(た)してね。長(なが)くするための関係(かんけい)ない連想(れんそう)、豆知識(まめちしき)、物語(ものがたり)、ふわっとしたまとめは入(い)れないで。簡単(かんたん)な質問(しつもん)は 2〜3 段落(だんらく)、複雑(ふくざつ)な質問(しつもん)でも 4〜5 段落(だんらく)までにしてね。漢字(かんじ)を使(つか)う時(とき)は、子(こ)どもが読(よ)めるように必(かなら)ず 漢字(ひらがな) の形(かたち)でふりがなを付(つ)けてね。"
        }
    }

    func chatMaxOutputTokens(language: AppLanguage) -> Int {
        switch (self, language) {
        case (.standard, .chinese):
            return 460
        case (.standard, .japanese):
            return 500
        case (.standard, .english):
            return 180
        case (.expanded, .chinese), (.expanded, .japanese):
            return 850
        case (.expanded, .english):
            return 560
        }
    }

    func spokenCharacterLimit(language: AppLanguage) -> Int {
        switch (self, language) {
        case (.standard, .chinese):
            return 340
        case (.standard, .english), (.standard, .japanese):
            return 260
        case (.expanded, .english):
            return 1_250
        case (.expanded, .chinese), (.expanded, .japanese):
            return 900
        }
    }
}

private struct AnswerCacheEntry: Codable {
    let answer: String
    let ttsInput: String?
    let speechTicket: String?
    let plan: String?
    let byteSize: Int
    let createdAt: Date
    var lastAccessedAt: Date
}

private enum BackendClientIdentity {
    private static let installIDKey = "WonderKidInstallID"
    private static let keychainService = Bundle.main.bundleIdentifier ?? "WonderKidAI"

    static var installID: String {
        if let existing = keychainString(for: installIDKey), !existing.isEmpty {
            return existing
        }

        let fresh = UUID().uuidString
        keychainSet(fresh, for: installIDKey)
        return fresh
    }

    static var appUserID: String? {
        let appUserID = Purchases.shared.appUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        return appUserID.isEmpty ? nil : appUserID
    }

    static var cacheScope: String {
        appUserID.map { "rc:\($0)" } ?? "install:\(installID)"
    }

    static func attach(to request: inout URLRequest) {
        request.addValue(installID, forHTTPHeaderField: "x-install-id")
        if let appUserID {
            request.addValue(appUserID, forHTTPHeaderField: "x-app-user-id")
        }
    }

    private static func keychainString(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keychainSet(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }
}

private actor AnswerDiskCache {
    private struct CacheIndex: Codable {
        var entries: [String: AnswerCacheEntry] = [:]
    }

    private let fileManager = FileManager.default
    private let cacheDirectoryURL: URL
    private let indexURL: URL
    private let maxCacheSizeBytes = 1_500_000
    private let maxEntryCount = 80
    private let maxEntryAge: TimeInterval = 7 * 24 * 60 * 60
    private var index: CacheIndex?

    init() {
        let cachesRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        cacheDirectoryURL = cachesRoot.appendingPathComponent("WonderKidAI-Answer-Cache", isDirectory: true)
        indexURL = cacheDirectoryURL.appendingPathComponent("index.json")
    }

    func answerResponse(for key: String) -> AIAnswerResponse? {
        ensureLoaded()

        guard var entry = index?.entries[key] else {
            return nil
        }

        let now = Date()
        if now.timeIntervalSince(entry.createdAt) > maxEntryAge {
            index?.entries.removeValue(forKey: key)
            persistIndex()
            return nil
        }

        entry.lastAccessedAt = now
        index?.entries[key] = entry
        persistIndex()
        guard let ttsInput = entry.ttsInput,
              let speechTicket = entry.speechTicket,
              !ttsInput.isEmpty,
              !speechTicket.isEmpty else {
            index?.entries.removeValue(forKey: key)
            persistIndex()
            return nil
        }

        return AIAnswerResponse(
            answer: entry.answer,
            ttsInput: ttsInput,
            speechTicket: speechTicket,
            plan: entry.plan,
            servedFromCache: true
        )
    }

    func store(_ response: AIAnswerResponse, for key: String) {
        ensureLoaded()

        let now = Date()
        let byteSize = response.answer.utf8.count + response.ttsInput.utf8.count + response.speechTicket.utf8.count
        index?.entries[key] = AnswerCacheEntry(
            answer: response.answer,
            ttsInput: response.ttsInput,
            speechTicket: response.speechTicket,
            plan: response.plan,
            byteSize: byteSize,
            createdAt: now,
            lastAccessedAt: now
        )
        persistIndex()
        pruneIfNeeded()
    }

    func pruneIfNeeded() {
        ensureLoaded()

        guard var currentIndex = index else { return }

        let now = Date()
        var didChange = false

        let expiredKeys = currentIndex.entries.compactMap { key, entry in
            now.timeIntervalSince(entry.lastAccessedAt) > maxEntryAge ? key : nil
        }

        for key in expiredKeys {
            currentIndex.entries.removeValue(forKey: key)
            didChange = true
        }

        var totalSize = currentIndex.entries.values.reduce(0) { $0 + $1.byteSize }
        let sortedEntries = currentIndex.entries.sorted { lhs, rhs in
            lhs.value.lastAccessedAt < rhs.value.lastAccessedAt
        }

        for (key, entry) in sortedEntries {
            let shouldTrimBySize = totalSize > maxCacheSizeBytes
            let shouldTrimByCount = currentIndex.entries.count > maxEntryCount
            guard shouldTrimBySize || shouldTrimByCount else { break }

            currentIndex.entries.removeValue(forKey: key)
            totalSize -= entry.byteSize
            didChange = true
        }

        if didChange {
            index = currentIndex
            persistIndex()
        }
    }

    func removeAll() {
        ensureLoaded()
        index = CacheIndex()
        persistIndex()
    }

    private func ensureLoaded() {
        guard index == nil else { return }

        try? fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: indexURL),
           let decoded = try? JSONDecoder().decode(CacheIndex.self, from: data) {
            index = decoded
        } else {
            index = CacheIndex()
        }
    }

    private func persistIndex() {
        guard let index else { return }
        guard let data = try? JSONEncoder().encode(index) else { return }
        try? data.write(to: indexURL, options: [.atomic])
    }
}

private actor TTSAudioDiskCache {
    private struct CacheIndex: Codable {
        var entries: [String: TTSAudioCacheEntry] = [:]
    }

    private let fileManager = FileManager.default
    private let cacheDirectoryURL: URL
    private let indexURL: URL
    private let maxCacheSizeBytes = 80 * 1024 * 1024
    private let maxEntryCount = 120
    private let maxEntryAge: TimeInterval = 21 * 24 * 60 * 60
    private var index: CacheIndex?

    init() {
        let cachesRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        cacheDirectoryURL = cachesRoot.appendingPathComponent("WonderKidAI-TTS-Cache", isDirectory: true)
        indexURL = cacheDirectoryURL.appendingPathComponent("index.json")
    }

    func data(for key: String) -> Data? {
        ensureLoaded()

        guard var entry = index?.entries[key] else {
            return nil
        }

        let fileURL = cacheDirectoryURL.appendingPathComponent(entry.filename)
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]) else {
            removeEntry(forKey: key, filename: entry.filename)
            persistIndex()
            return nil
        }

        entry.lastAccessedAt = Date()
        index?.entries[key] = entry
        persistIndex()
        return data
    }

    func store(_ data: Data, for key: String) {
        ensureLoaded()

        let filename = Self.filename(for: key)
        let fileURL = cacheDirectoryURL.appendingPathComponent(filename)
        try? data.write(to: fileURL, options: [.atomic])

        let now = Date()
        index?.entries[key] = TTSAudioCacheEntry(
            filename: filename,
            byteSize: data.count,
            createdAt: now,
            lastAccessedAt: now
        )
        persistIndex()
        pruneIfNeeded()
    }

    func pruneIfNeeded() {
        ensureLoaded()

        guard var currentIndex = index else { return }

        let now = Date()
        var didChange = false

        let invalidKeys = currentIndex.entries.compactMap { key, entry in
            let fileURL = cacheDirectoryURL.appendingPathComponent(entry.filename)
            let isExpired = now.timeIntervalSince(entry.lastAccessedAt) > maxEntryAge
            let isMissingFile = !fileManager.fileExists(atPath: fileURL.path)
            return (isExpired || isMissingFile) ? key : nil
        }

        for key in invalidKeys {
            if let entry = currentIndex.entries[key] {
                removeEntry(forKey: key, filename: entry.filename)
                currentIndex.entries.removeValue(forKey: key)
                didChange = true
            }
        }

        var totalSize = currentIndex.entries.values.reduce(0) { $0 + $1.byteSize }
        let sortedEntries = currentIndex.entries.sorted { lhs, rhs in
            lhs.value.lastAccessedAt < rhs.value.lastAccessedAt
        }

        for (key, entry) in sortedEntries {
            let shouldTrimBySize = totalSize > maxCacheSizeBytes
            let shouldTrimByCount = currentIndex.entries.count > maxEntryCount
            guard shouldTrimBySize || shouldTrimByCount else { break }

            removeEntry(forKey: key, filename: entry.filename)
            currentIndex.entries.removeValue(forKey: key)
            totalSize -= entry.byteSize
            didChange = true
        }

        if didChange {
            index = currentIndex
            persistIndex()
        }

        removeOrphanFiles(keeping: Set(currentIndex.entries.values.map(\.filename)))
    }

    func removeAll() {
        ensureLoaded()

        if let fileURLs = try? fileManager.contentsOfDirectory(at: cacheDirectoryURL, includingPropertiesForKeys: nil) {
            for fileURL in fileURLs where fileURL.lastPathComponent != indexURL.lastPathComponent {
                try? fileManager.removeItem(at: fileURL)
            }
        }

        index = CacheIndex()
        persistIndex()
    }

    private func ensureLoaded() {
        guard index == nil else { return }

        try? fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: indexURL),
           let decoded = try? JSONDecoder().decode(CacheIndex.self, from: data) {
            index = decoded
        } else {
            index = CacheIndex()
        }
    }

    private func persistIndex() {
        guard let index else { return }
        guard let data = try? JSONEncoder().encode(index) else { return }
        try? data.write(to: indexURL, options: [.atomic])
    }

    private func removeEntry(forKey key: String, filename: String) {
        let fileURL = cacheDirectoryURL.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
        index?.entries.removeValue(forKey: key)
    }

    private func removeOrphanFiles(keeping indexedFilenames: Set<String>) {
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: cacheDirectoryURL, includingPropertiesForKeys: nil) else {
            return
        }

        for fileURL in fileURLs {
            let filename = fileURL.lastPathComponent
            guard filename != indexURL.lastPathComponent, !indexedFilenames.contains(filename) else {
                continue
            }

            try? fileManager.removeItem(at: fileURL)
        }
    }

    private static func filename(for key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let fileExtension = key.contains("|wav|") ? "wav" : "audio"
        return "\(hex).\(fileExtension)"
    }
}

private actor TTSAudioRequestRegistry {
    private var tasks: [String: Task<Data, Error>] = [:]

    func task(for key: String) -> Task<Data, Error>? {
        tasks[key]
    }

    func insert(_ task: Task<Data, Error>, for key: String) {
        tasks[key] = task
    }

    func remove(for key: String) {
        tasks.removeValue(forKey: key)
    }
}

class OpenAIService {
    
    // ✅ 正式環境網址 (Render)
    private let baseURL = "https://wonderkidai-server.onrender.com"
    // Temporary compatibility bridge for the existing Render raw proxy.
    // This restores service without a new deployment, but server-side quota/model enforcement is weaker.
    private let allowsLegacyRenderProxyFallback = true
    private static let legacyProxySpeechTicket = "legacy-render-proxy"
    private let answerCacheVersion = "answer-v6-richer-zh-standard"
    
    static let shared = OpenAIService()
    private let ttsCache = NSCache<NSString, NSData>()
    private let diskCache = TTSAudioDiskCache()
    private let answerCache = AnswerDiskCache()
    private let requestRegistry = TTSAudioRequestRegistry()
    
    private init() {
        ttsCache.countLimit = 50
        ttsCache.totalCostLimit = 24 * 1024 * 1024
        removeLegacyIntroFilesIfNeeded()

        Task {
            await diskCache.pruneIfNeeded()
            await answerCache.pruneIfNeeded()
        }
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

    func processMessage(userMessage: String, language: AppLanguage, history: [[String: Any]] = [], answerDepth: AIAnswerDepth = .standard) async throws -> String {
        let response = try await processMessageWithMetadata(userMessage: userMessage, language: language, history: history, answerDepth: answerDepth)
        return response.answer
    }

    // MARK: - 2. 核心處理邏輯 (聊天)
    func processMessageWithMetadata(userMessage: String, language: AppLanguage, history: [[String: Any]] = [], answerDepth: AIAnswerDepth = .standard) async throws -> AIAnswerResponse {
        let canUseAnswerCache = history.isEmpty && shouldUseAnswerCache(for: userMessage, language: language)
        let cacheKey = answerCacheKey(for: userMessage, language: language, answerDepth: answerDepth)

        if canUseAnswerCache, let cachedResponse = await answerCache.answerResponse(for: cacheKey) {
            #if DEBUG
            print("[AnswerCache] hit language=\(language.rawValue), depth=\(answerDepth.rawValue), questionLen=\(userMessage.count)")
            #endif
            return cachedResponse
        }

        let response = try await requestChatAnswer(userMessage: userMessage, language: language, history: history, answerDepth: answerDepth)

        if canUseAnswerCache, response.speechTicket != Self.legacyProxySpeechTicket {
            await answerCache.store(response, for: cacheKey)
            #if DEBUG
            print("[AnswerCache] stored language=\(language.rawValue), depth=\(answerDepth.rawValue), answerLen=\(response.answer.count)")
            #endif
        }

        return response
    }

    private func requestChatAnswer(userMessage: String, language: AppLanguage, history: [[String: Any]] = [], answerDepth: AIAnswerDepth = .standard) async throws -> AIAnswerResponse {
        guard let url = URL(string: "\(baseURL)/api/chat") else { throw OpenAIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        BackendClientIdentity.attach(to: &request)

        let parameters: [String: Any] = [
            "language": language.rawValue,
            "message": userMessage
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)

        let (data, response) = try await URLSession.shared.data(for: request)
        SubscriptionManager.shared.updateServerTime(from: response)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.noData
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 402 {
                throw OpenAIError.quotaExceeded
            }
            let errorMsg = Self.backendErrorMessage(from: data)
            if Self.isBackendUpgradeRequired(statusCode: httpResponse.statusCode, errorMessage: errorMsg) {
                if allowsLegacyRenderProxyFallback {
                    return try await requestLegacyProxyChatAnswer(
                        userMessage: userMessage,
                        language: language,
                        history: history,
                        answerDepth: answerDepth
                    )
                }
                throw OpenAIError.backendUpgradeRequired
            }
            throw OpenAIError.apiError("Backend Error: \(errorMsg)")
        }

        let result = try JSONDecoder().decode(BackendChatResponse.self, from: data)
        guard !result.answer.isEmpty, !result.ttsInput.isEmpty, !result.speechTicket.isEmpty else {
            throw OpenAIError.noData
        }

        return AIAnswerResponse(
            answer: result.answer,
            ttsInput: result.ttsInput,
            speechTicket: result.speechTicket,
            plan: result.plan,
            servedFromCache: false
        )
    }

    private func requestLegacyProxyChatAnswer(userMessage: String, language: AppLanguage, history: [[String: Any]] = [], answerDepth: AIAnswerDepth = .standard) async throws -> AIAnswerResponse {
        guard let url = URL(string: "\(baseURL)/api/chat") else { throw OpenAIError.invalidURL }

        #if DEBUG
        print("⚠️ Using legacy Render chat proxy fallback. Server-side quota/model enforcement is not protected.")
        #endif

        var messages: [[String: Any]] = [
            [
                "role": "system",
                "content": legacySystemPrompt(language: language, answerDepth: answerDepth)
            ]
        ]

        if !history.isEmpty {
            messages.append(contentsOf: history)
        }

        let userContent: String
        if shouldPrefetchWikipedia(for: userMessage, language: language) {
            let query = normalizeWikiQuery(userMessage, language: language)
            let wikiSummary = await fetchWikipedia(query: query, language: language)
            if isValidWikiSummary(wikiSummary, language: language) {
                userContent = "\(wikiContextPrefix(language: language))\n\(wikiSummary)\n\n\(userMessage)"
            } else {
                userContent = userMessage
            }
        } else {
            userContent = userMessage
        }

        messages.append(["role": "user", "content": userContent])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        BackendClientIdentity.attach(to: &request)

        let parameters: [String: Any] = [
            "model": "gpt-4o",
            "temperature": 0.7,
            "max_tokens": chatMaxOutputTokens(for: language, answerDepth: answerDepth),
            "messages": messages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)

        let (data, response) = try await URLSession.shared.data(for: request)
        SubscriptionManager.shared.updateServerTime(from: response)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorMsg = Self.backendErrorMessage(from: data)
            throw OpenAIError.apiError("Legacy Backend Error (HTTP \(statusCode)): \(errorMsg)")
        }

        let result = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let answer = result.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !answer.isEmpty else {
            throw OpenAIError.noData
        }

        return AIAnswerResponse(
            answer: answer,
            ttsInput: answer.cleanForTTS(language: language),
            speechTicket: Self.legacyProxySpeechTicket,
            plan: nil,
            servedFromCache: false
        )
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
    func cachedAudioIfAvailable(for text: String, language: AppLanguage = .chinese) async -> Data? {
        let profile = ttsVoiceProfile(for: language)
        let cacheKey = ttsCacheKey(for: text, language: language, profile: profile)

        if let cached = ttsCache.object(forKey: cacheKey as NSString) {
            return cached as Data
        }

        if let diskCached = await diskCache.data(for: cacheKey) {
            ttsCache.setObject(diskCached as NSData, forKey: cacheKey as NSString, cost: diskCached.count)
            return diskCached
        }

        return nil
    }

    func generateIntroAudio(from text: String, language: AppLanguage = .chinese) async throws -> Data {
        let profile = ttsVoiceProfile(for: language)
        let cacheKey = ttsCacheKey(for: text, language: language, profile: profile)

        if let cached = await cachedAudioIfAvailable(for: text, language: language) {
            return cached
        }

        if let existingTask = await requestRegistry.task(for: cacheKey) {
            return try await existingTask.value
        }

        let task = Task<Data, Error> { [self] in
            guard let url = URL(string: "\(baseURL)/api/intro-speech") else { throw OpenAIError.invalidURL }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            BackendClientIdentity.attach(to: &request)

            let parameters: [String: Any] = [
                "language": language.rawValue
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)

            let (data, response) = try await URLSession.shared.data(for: request)
            SubscriptionManager.shared.updateServerTime(from: response)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let errorMsg = Self.backendErrorMessage(from: data)
                if Self.isBackendUpgradeRequired(statusCode: statusCode, errorMessage: errorMsg) {
                    if allowsLegacyRenderProxyFallback {
                        let legacyData = try await requestLegacyProxySpeechAudio(text: text, language: language)
                        ttsCache.setObject(legacyData as NSData, forKey: cacheKey as NSString, cost: legacyData.count)
                        await diskCache.store(legacyData, for: cacheKey)
                        return legacyData
                    }
                    throw OpenAIError.backendUpgradeRequired
                }
                throw OpenAIError.apiError("TTS Failed (HTTP \(statusCode)): \(errorMsg)")
            }

            #if DEBUG
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
            print("[TTS] intro language=\(language.rawValue), contentType=\(contentType), bytes=\(data.count)")
            #endif

            ttsCache.setObject(data as NSData, forKey: cacheKey as NSString, cost: data.count)
            await diskCache.store(data, for: cacheKey)
            return data
        }

        await requestRegistry.insert(task, for: cacheKey)

        do {
            let data = try await task.value
            await requestRegistry.remove(for: cacheKey)
            return data
        } catch {
            await requestRegistry.remove(for: cacheKey)
            throw error
        }
    }

    func generateSpeechAudio(ttsInput: String, language: AppLanguage, speechTicket: String) async throws -> Data {
        let profile = ttsVoiceProfile(for: language)
        // The reading card and speech must always use the same complete answer.
        // A long answer naturally takes longer to synthesize and play, but it
        // must never be silently shortened by the legacy proxy fallback.
        let cacheKey = ttsCacheKey(for: ttsInput, language: language, profile: profile)

        if let cached = await cachedAudioIfAvailable(for: ttsInput, language: language) {
            return cached
        }

        if let existingTask = await requestRegistry.task(for: cacheKey) {
            return try await existingTask.value
        }

        let task = Task<Data, Error> { [self] in
            if speechTicket == Self.legacyProxySpeechTicket {
                let legacyData = try await requestLegacyProxySpeechAudio(text: ttsInput, language: language)
                ttsCache.setObject(legacyData as NSData, forKey: cacheKey as NSString, cost: legacyData.count)
                await diskCache.store(legacyData, for: cacheKey)
                return legacyData
            }

            guard let url = URL(string: "\(baseURL)/api/speech") else { throw OpenAIError.invalidURL }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            BackendClientIdentity.attach(to: &request)

            let parameters: [String: Any] = [
                "language": language.rawValue,
                "ttsInput": ttsInput,
                "speechTicket": speechTicket
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)

            let (data, response) = try await URLSession.shared.data(for: request)
            SubscriptionManager.shared.updateServerTime(from: response)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let errorMsg = Self.backendErrorMessage(from: data)
                if Self.isBackendUpgradeRequired(statusCode: statusCode, errorMessage: errorMsg) {
                    if allowsLegacyRenderProxyFallback {
                        let legacyData = try await requestLegacyProxySpeechAudio(text: ttsInput, language: language)
                        ttsCache.setObject(legacyData as NSData, forKey: cacheKey as NSString, cost: legacyData.count)
                        await diskCache.store(legacyData, for: cacheKey)
                        return legacyData
                    }
                    throw OpenAIError.backendUpgradeRequired
                }
                throw OpenAIError.apiError("TTS Failed (HTTP \(statusCode)): \(errorMsg)")
            }

            #if DEBUG
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
            let cacheHeader = httpResponse.value(forHTTPHeaderField: "X-Speech-Cache") ?? "unknown"
            print("[TTS] protected language=\(language.rawValue), cache=\(cacheHeader), contentType=\(contentType), bytes=\(data.count)")
            #endif

            ttsCache.setObject(data as NSData, forKey: cacheKey as NSString, cost: data.count)
            await diskCache.store(data, for: cacheKey)
            return data
        }

        await requestRegistry.insert(task, for: cacheKey)

        do {
            let data = try await task.value
            await requestRegistry.remove(for: cacheKey)
            return data
        } catch {
            await requestRegistry.remove(for: cacheKey)
            throw error
        }
    }

    private func requestLegacyProxySpeechAudio(text: String, language: AppLanguage) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/api/speech") else { throw OpenAIError.invalidURL }

        #if DEBUG
        print("⚠️ Using legacy Render speech proxy fallback. TTS parameters are client-controlled in this mode.")
        #endif

        let profile = ttsVoiceProfile(for: language)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        BackendClientIdentity.attach(to: &request)

        let parameters: [String: Any] = [
            "model": profile.model,
            "input": text,
            "voice": profile.voice,
            "speed": profile.speed,
            "response_format": profile.responseFormat,
            "instructions": profile.instructions
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)

        let (data, response) = try await URLSession.shared.data(for: request)
        SubscriptionManager.shared.updateServerTime(from: response)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorMsg = Self.backendErrorMessage(from: data)
            throw OpenAIError.apiError("Legacy TTS Failed (HTTP \(statusCode)): \(errorMsg)")
        }

        return data
    }

    func maintainTTSAudioCache() {
        maintainLocalCaches()
    }

    func maintainLocalCaches() {
        Task {
            await diskCache.pruneIfNeeded()
            await answerCache.pruneIfNeeded()
        }
    }

    func clearTransientAudioMemoryCache() {
        ttsCache.removeAllObjects()
    }

    func clearAllCachedAudio() {
        ttsCache.removeAllObjects()

        Task {
            await diskCache.removeAll()
        }
    }

    func clearAllCachedAnswers() {
        Task {
            await answerCache.removeAll()
        }
    }

    private func ttsVoiceProfile(for language: AppLanguage) -> TTSVoiceProfile {
        let naturalFemaleStyle = "Use a natural, realistic adult female voice. Speak like a calm, friendly woman in a normal conversation, with relaxed pacing, subtle intonation, smooth vowel endings, and light natural pauses after punctuation. Keep the voice warm but not childlike, not theatrical, not a teacher character, and not an announcer. Prioritize lifelike, clean, non-metallic audio with soft consonants, stable volume, and no harsh high-frequency edges. Avoid robotic clipping, metallic compression, exaggerated cartoon acting, vocal fry, sibilance, overly bright sharp consonants, or emotional overacting."

        switch language {
        case .chinese:
            return TTSVoiceProfile(
                model: "gpt-4o-mini-tts",
                voice: "nova",
                speed: 0.92,
                responseFormat: "wav",
                instructions: "\(naturalFemaleStyle) Use natural Taiwan Mandarin pronunciation and rhythm. Pronounce 一 as yi / ㄧ, never yao / 么. When Arabic digit sequences are present or already expanded into Chinese digit names, read every digit in the exact same order as written; never swap, drop, or reorder digits. For example, 747 is 七四七, not 四七四. Avoid Mainland Mandarin accent, erhua, and heavy retroflex sounds.",
                cacheVersion: "natural-female-v1-zh-tw-nova-wav"
            )
        case .english:
            return TTSVoiceProfile(
                model: "gpt-4o-mini-tts",
                voice: "nova",
                speed: 0.92,
                responseFormat: "wav",
                instructions: "\(naturalFemaleStyle) Use natural American English pronunciation and rhythm.",
                cacheVersion: "natural-female-v1-en-us-nova-wav"
            )
        case .japanese:
            return TTSVoiceProfile(
                model: "gpt-4o-mini-tts",
                voice: "nova",
                speed: 0.92,
                responseFormat: "wav",
                instructions: "\(naturalFemaleStyle) Use natural Japanese pronunciation and rhythm. Avoid anime-style acting or exaggerated cute character voice.",
                cacheVersion: "natural-female-v4-ja-ruby-spoken-nova-0.92-wav"
            )
        }
    }

    private func chatMaxOutputTokens(for language: AppLanguage, answerDepth: AIAnswerDepth) -> Int {
        answerDepth.chatMaxOutputTokens(language: language)
    }

    private func ttsCacheKey(for text: String, language: AppLanguage, profile: TTSVoiceProfile) -> String {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(language.rawValue)|\(profile.cacheVersion)|\(profile.model)|\(profile.voice)|\(profile.speed)|\(profile.responseFormat)|\(normalizedText)"
    }

    private func answerCacheKey(for userMessage: String, language: AppLanguage, answerDepth: AIAnswerDepth) -> String {
        let normalizedQuestion = normalizedAnswerCacheQuestion(userMessage)
        let rawKey = "\(BackendClientIdentity.cacheScope)|\(language.rawValue)|\(answerCacheVersion)|\(answerDepth.rawValue)|\(normalizedQuestion)"
        let digest = SHA256.hash(data: Data(rawKey.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func shouldUseAnswerCache(for userMessage: String, language: AppLanguage) -> Bool {
        let normalized = normalizedAnswerCacheQuestion(userMessage)
        guard normalized.count >= 2, normalized.count <= 160 else {
            return false
        }

        if containsAnyCacheBlockedKeyword(in: normalized, language: language) {
            return false
        }

        return shouldPrefetchWikipedia(for: normalized, language: language)
    }

    private func normalizedAnswerCacheQuestion(_ message: String) -> String {
        var normalized = message
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))

        let edgePunctuation = CharacterSet(charactersIn: "？?！!。.,，、")
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines.union(edgePunctuation))

        if let whitespaceRegex = try? NSRegularExpression(pattern: "\\s+", options: []) {
            let range = NSRange(normalized.startIndex..., in: normalized)
            normalized = whitespaceRegex.stringByReplacingMatches(in: normalized, options: [], range: range, withTemplate: " ")
        }

        return normalized
    }

    private func containsAnyCacheBlockedKeyword(in normalizedMessage: String, language: AppLanguage) -> Bool {
        let sharedBlockedKeywords = [
            "email",
            "e-mail",
            "password",
            "電話",
            "地址",
            "密碼",
            "パスワード",
            "電話番号",
            "住所"
        ]

        let languageBlockedKeywords: [String]
        switch language {
        case .chinese:
            languageBlockedKeywords = [
                "今天", "明天", "昨天", "現在", "最新", "新聞", "天氣", "股價", "匯率", "價格", "幾點", "日期", "今年", "最近",
                "我叫", "我的名字", "我住", "我的生日", "我幾歲"
            ]
        case .english:
            languageBlockedKeywords = [
                "today", "tomorrow", "yesterday", "now", "latest", "news", "weather", "stock", "exchange rate", "price", "time", "date", "this year", "recent",
                "my name", "i live", "my birthday", "how old am i", "where am i", "who am i"
            ]
        case .japanese:
            languageBlockedKeywords = [
                "今日", "明日", "昨日", "今", "最新", "ニュース", "天気", "株価", "為替", "価格", "何時", "日付", "今年", "最近",
                "私の名前", "わたしの名前", "ぼくの名前", "住んで", "誕生日", "何歳"
            ]
        }

        return (sharedBlockedKeywords + languageBlockedKeywords).contains { normalizedMessage.contains($0) }
    }

    private static func backendErrorMessage(from data: Data) -> String {
        if let payload = try? JSONDecoder().decode(BackendErrorPayload.self, from: data) {
            return payload.details ?? payload.message ?? payload.error ?? "Unknown"
        }

        return String(data: data, encoding: .utf8) ?? "Unknown"
    }

    private static func isBackendUpgradeRequired(statusCode: Int, errorMessage: String) -> Bool {
        let normalizedMessage = errorMessage.lowercased()
        return normalizedMessage.contains("you must provide a model parameter")
            || normalizedMessage.contains("cannot get /api/session")
            || normalizedMessage.contains("cannot post /api/intro-speech")
            || normalizedMessage.contains("cannot post /api/speech")
            || normalizedMessage.contains("cannot post /api/chat")
            || (statusCode == 404 && normalizedMessage.contains("not found"))
    }

    private func removeLegacyIntroFilesIfNeeded() {
        guard let cachesRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }

        let legacyLanguages = ["zh-TW", "en-US", "ja-JP"]
        for language in legacyLanguages {
            let legacyURL = cachesRoot.appendingPathComponent("intro-\(language).m4a")
            if FileManager.default.fileExists(atPath: legacyURL.path) {
                try? FileManager.default.removeItem(at: legacyURL)
            }
        }
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

    private func legacySystemPrompt(language: AppLanguage, answerDepth: AIAnswerDepth) -> String {
        switch language {
        case .chinese:
            return "你是安安老師，對象是 4 到 10 歲小朋友。請用溫柔、簡單、適合語音朗讀的自然段落回答，不要用 Markdown。\(answerDepth.promptInstruction(language: language))"
        case .english:
            return "You are Teacher An-An for children aged 4 to 10. Answer gently in simple natural paragraphs suitable for TTS. Do not use Markdown. \(answerDepth.promptInstruction(language: language))"
        case .japanese:
            return "あなたはあんあん先生です。4〜10歳の子ども向けに、やさしく、音声で聞きやすい自然な文で答えてください。Markdown は使わないでください。漢字を使う時は、表示用に必ず 漢字(ひらがな) の形でふりがなを付けてください。例：火山(かざん)、自然(しぜん)、理由(りゆう)。日本語の句読点は必ず全角の「、」「。」を自然な位置に使い、各文は「。」で終えてください。「、」「。」「！」「？」の直前に空白を置かず、半角の , . ! ? は使わないでください。\(answerDepth.promptInstruction(language: language))"
        }
    }
    
    // MARK: - 5. 連線檢查
    func checkConnection() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/session") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        BackendClientIdentity.attach(to: &request)
        
        do {
            print("📡 正在連線: \(url.absoluteString)...")
            let (data, response) = try await URLSession.shared.data(for: request)
            SubscriptionManager.shared.updateServerTime(from: response)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ 連線成功 (Protected backend is compatible)")
                    return true
                }

                let errorMsg = Self.backendErrorMessage(from: data)
                if Self.isBackendUpgradeRequired(statusCode: httpResponse.statusCode, errorMessage: errorMsg) {
                    if allowsLegacyRenderProxyFallback {
                        return await checkLegacyProxyConnection()
                    }
                    print("⚠️ 伺服器版本不相容，需要部署 protected backend")
                    return false
                }
            }
            return false
        } catch {
            print("❌ 連線真正失敗: \(error.localizedDescription)")
            return false
        }
    }

    private func checkLegacyProxyConnection() async -> Bool {
        guard let url = URL(string: baseURL) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            SubscriptionManager.shared.updateServerTime(from: response)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 || httpResponse.statusCode == 404 {
                print("⚠️ 連線成功 (Legacy Render proxy fallback)")
                return true
            }
        } catch {
            print("❌ Legacy proxy 連線失敗: \(error.localizedDescription)")
        }

        return false
    }
}

// MARK: - 輔助結構
struct ChatResponse: Decodable { struct Choice: Decodable { let message: ChatMessage }; let choices: [Choice] }
struct ChatMessage: Decodable { let role: String; let content: String?; let tool_calls: [ToolCall]?; func toDictionary() -> [String: Any] { var dict: [String: Any] = ["role": role]; if let content = content { dict["content"] = content }; if let tool_calls = tool_calls { dict["tool_calls"] = tool_calls.map { $0.toDictionary() } }; return dict } }
struct ToolCall: Decodable { let id: String; let type: String; let function: FunctionCall; func toDictionary() -> [String: Any] { return ["id": id, "type": type, "function": ["name": function.name, "arguments": function.arguments]] } }
struct FunctionCall: Decodable { let name: String; let arguments: String }
struct WikiArgs: Decodable { let query: String }

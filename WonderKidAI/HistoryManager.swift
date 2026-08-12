import Foundation
import Combine
import SwiftUI // 🔥 關鍵修正：加入這行，才能使用 remove(atOffsets:)

// 歷史紀錄的資料結構
struct HistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let question: String
    let answer: String
    let language: String // "zh-TW" or "en-US"
}

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    // 發布變數，讓 UI 可以即時更新
    @Published var history: [HistoryItem] = []
    
    private let key = "WonderKidHistory"
    
    private init() {
        loadHistory()
    }
    
    // MARK: - 核心功能
    
    // 新增紀錄
    @MainActor
    func addRecord(question: String, answer: String, language: String) {
        let newItem = HistoryItem(
            id: UUID(),
            date: Date(),
            question: PromptVisibilitySanitizer.visibleQuestion(from: question, language: language),
            answer: PromptVisibilitySanitizer.visibleAnswer(from: answer, language: language),
            language: language
        )
        
        // 1. 插入到最前面 (最新)
        history.insert(newItem, at: 0)
        
        // 2. 檢查數量上限 (例如只留 50 筆)
        if history.count > 50 {
            history.removeLast()
        }
        
        saveHistory()
        PremiumCloudSyncManager.shared.historyDidChange(history)
    }
    
    // 刪除紀錄 (支援滑動刪除)
    func deleteRecord(at offsets: IndexSet) {
        // SwiftUI 的刪除事件可能在資料已被同步更新後才送達；只處理仍有效的索引，
        // 避免把過期的 IndexSet 傳給 remove(atOffsets:) 而越界。
        let validOffsets = IndexSet(offsets.filter { history.indices.contains($0) })
        guard !validOffsets.isEmpty else { return }

        let deletedIDs = validOffsets.map { history[$0].id }

        history.remove(atOffsets: validOffsets)
        saveHistory()
        deletedIDs.forEach {
            PremiumCloudSyncManager.shared.historyRecordDidDelete($0, remainingHistory: history)
        }
    }

    func deleteRecord(id: UUID) {
        guard history.contains(where: { $0.id == id }) else { return }
        history.removeAll { $0.id == id }
        saveHistory()
        PremiumCloudSyncManager.shared.historyRecordDidDelete(id, remainingHistory: history)
    }
    
    // 清空所有紀錄
    func clearHistory() {
        let previousHistory = history
        guard !previousHistory.isEmpty else { return }
        history.removeAll()
        saveHistory()
        PremiumCloudSyncManager.shared.historyDidClear(previousHistory: previousHistory)
    }

    @discardableResult
    func applyCloudHistory(_ cloudHistory: [HistoryItem], deletedRecordIDs: Set<UUID>, clearedAt: Date?) -> Bool {
        // 不信任持久化或 iCloud payload 中的 UUID 唯一性。Dictionary(uniqueKeysWithValues:)
        // 遇到重複 key 會直接觸發 runtime trap，因此保留日期較新的那筆即可。
        var mergedByID: [UUID: HistoryItem] = [:]
        for item in history + cloudHistory {
            let sanitized = PromptVisibilitySanitizer.sanitizedHistoryItem(item)
            if let existing = mergedByID[sanitized.id], existing.date >= sanitized.date {
                continue
            }
            mergedByID[sanitized.id] = sanitized
        }

        var merged = Array(mergedByID.values)
        merged.removeAll { item in
            if deletedRecordIDs.contains(item.id) {
                return true
            }

            if let clearedAt, item.date <= clearedAt {
                return true
            }

            return false
        }
        merged.sort { $0.date > $1.date }

        if merged.count > 50 {
            merged = Array(merged.prefix(50))
        }

        guard merged != history else { return false }
        history = merged
        saveHistory()
        return true
    }
    
    // MARK: - 資料持久化 (UserDefaults)
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            // 避免損毀資料、重複 UUID 或舊版留下的超量紀錄影響記憶體與同步合併。
            let normalized = normalizedHistory(decoded)
            history = normalized
            if normalized != decoded {
                saveHistory()
            }
        }
    }

    private func normalizedHistory(_ items: [HistoryItem]) -> [HistoryItem] {
        var newestByID: [UUID: HistoryItem] = [:]
        for rawItem in items {
            let item = PromptVisibilitySanitizer.sanitizedHistoryItem(rawItem)
            if let existing = newestByID[item.id], existing.date >= item.date {
                continue
            }
            newestByID[item.id] = item
        }

        return newestByID.values
            .sorted(by: { $0.date > $1.date })
            .prefix(50)
            .map { $0 }
    }
}

enum PromptVisibilitySanitizer {
    static func sanitizedHistoryItem(_ item: HistoryItem) -> HistoryItem {
        let question = visibleQuestion(from: item.question, language: item.language)
        let answer = visibleAnswer(from: item.answer, language: item.language)

        guard question != item.question || answer != item.answer else {
            return item
        }

        return HistoryItem(
            id: item.id,
            date: item.date,
            question: question,
            answer: answer,
            language: item.language
        )
    }

    static func visibleQuestion(from text: String, language: String? = nil) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if let extracted = extractQuestion(from: trimmed) {
            return extracted
        }

        if containsInternalQuestionPrompt(trimmed) {
            return fallbackQuestion(for: language)
        }

        return trimmed
    }

    static func visibleAnswer(from text: String, language: String? = nil) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let lines = text.components(separatedBy: .newlines)
        var cleanedLines: [String] = []
        var skippingInstructionRules = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedLine.isEmpty {
                if !skippingInstructionRules {
                    cleanedLines.append(line)
                }
                skippingInstructionRules = false
                continue
            }

            if isInternalPromptHeaderLine(trimmedLine) {
                continue
            }

            if isRuleHeaderLine(trimmedLine) {
                skippingInstructionRules = true
                continue
            }

            if skippingInstructionRules && isNumberedInstructionLine(trimmedLine) {
                continue
            }

            skippingInstructionRules = false
            cleanedLines.append(line)
        }

        let cleaned = cleanedLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty && containsInternalQuestionPrompt(trimmed) {
            return fallbackAnswer(for: language)
        }

        return cleaned
    }

    private static func extractQuestion(from text: String) -> String? {
        let patterns = [
            ("針對小朋友剛剛的問題：「", "」。"),
            ("針對小朋友剛剛的問題：「", "」"),
            ("Regarding the child's previous question: \"", "\"."),
            ("Regarding the child's previous question: \"", "\""),
            ("子(こ)どもの質問(しつもん)：「", "」について。"),
            ("子(こ)どもの質問(しつもん)：「", "」")
        ]

        for pattern in patterns {
            if let extracted = extractBetween(text, start: pattern.0, end: pattern.1) {
                let visible = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
                if !visible.isEmpty {
                    return visible
                }
            }
        }

        return nil
    }

    private static func extractBetween(_ text: String, start: String, end: String) -> String? {
        guard let startRange = text.range(of: start) else { return nil }
        let searchStart = startRange.upperBound
        guard let endRange = text[searchStart...].range(of: end) else { return nil }
        return String(text[searchStart..<endRange.lowerBound])
    }

    private static func containsInternalQuestionPrompt(_ text: String) -> Bool {
        internalQuestionMarkers.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func isInternalPromptHeaderLine(_ line: String) -> Bool {
        containsInternalQuestionPrompt(line) || internalAnswerMarkers.contains {
            line.localizedCaseInsensitiveContains($0)
        }
    }

    private static func isRuleHeaderLine(_ line: String) -> Bool {
        ruleHeaderMarkers.contains { line.localizedCaseInsensitiveContains($0) }
    }

    private static func isNumberedInstructionLine(_ line: String) -> Bool {
        guard let first = line.first, first.isNumber else { return false }
        let rest = line.dropFirst().trimmingCharacters(in: .whitespaces)
        return rest.hasPrefix(".") || rest.hasPrefix("。") || rest.hasPrefix(")")
    }

    private static func fallbackQuestion(for language: String?) -> String {
        switch language {
        case AppLanguage.english.rawValue:
            return "Original question"
        case AppLanguage.japanese.rawValue:
            return "元(もと)の質問(しつもん)"
        default:
            return "原本的問題"
        }
    }

    private static func fallbackAnswer(for language: String?) -> String {
        switch language {
        case AppLanguage.english.rawValue:
            return "Teacher An-An did not organize that answer well. Please ask again."
        case AppLanguage.japanese.rawValue:
            return "あんあん先生がうまくまとめられませんでした。もう一度(いちど)聞(き)いてください。"
        default:
            return "安安老師剛剛沒有整理好，請再問一次。"
        }
    }

    private static let internalQuestionMarkers = [
        "針對小朋友剛剛的問題",
        "小朋友按了「聽不懂」",
        "Regarding the child's previous question",
        "The child tapped \"I don't get it\"",
        "子(こ)どもの質問(しつもん)",
        "子(こ)どもが「わからない」"
    ]

    private static let internalAnswerMarkers = [
        "請不要把答案講得更幼稚",
        "請從另一個適合孩子理解的面向",
        "Do not make the answer more childish",
        "Answer the same question from another child-friendly angle",
        "答(こた)えを幼(おさな)くしすぎず",
        "別(べつ)の見方(みかた)から説明(せつめい)"
    ]

    private static let ruleHeaderMarkers = [
        "請遵守：",
        "Rules:",
        "ルール："
    ]
}

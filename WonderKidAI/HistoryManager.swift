import Foundation
import Combine
import SwiftUI // 🔥 關鍵修正：加入這行，才能使用 remove(atOffsets:)

// 歷史紀錄的資料結構
struct HistoryItem: Identifiable, Codable {
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
        let newItem = HistoryItem(id: UUID(), date: Date(), question: question, answer: answer, language: language)
        
        // 1. 插入到最前面 (最新)
        history.insert(newItem, at: 0)
        
        // 2. 檢查數量上限 (例如只留 50 筆)
        if history.count > 50 {
            history.removeLast()
        }
        
        saveHistory()
    }
    
    // 刪除紀錄 (支援滑動刪除)
    func deleteRecord(at offsets: IndexSet) {
        // 這行程式碼需要 import SwiftUI 才能運作
        history.remove(atOffsets: offsets)
        saveHistory()
    }
    
    // 清空所有紀錄
    func clearHistory() {
        history.removeAll()
        saveHistory()
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
            // 確保排序是新的在前面
            history = decoded.sorted(by: { $0.date > $1.date })
        }
    }
}

import Foundation
import Combine  // 👈 關鍵修正：必須加入這一行才能使用 @Published 和 ObservableObject

struct HistoryItem: Identifiable, Codable {
    let id: UUID
    let date: Date
    let question: String
    let answer: String
    let language: String // 記錄當下是用中文還是英文問的
}

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    // @Published 需要 Combine 框架支援
    @Published var history: [HistoryItem] = []
    
    private let key = "WonderKidHistory"
    
    private init() {
        loadHistory()
    }
    
    func addRecord(question: String, answer: String, language: String) {
            let newItem = HistoryItem(id: UUID(), date: Date(), question: question, answer: answer, language: language)
            
            // 1. 插入到最前面 (最新)
            history.insert(newItem, at: 0)
            
            // 2. 🔥 新增：檢查數量上限 (例如只留 50 筆)
            // 如果超過 50 筆，就把最舊的 (最後面) 刪掉
            if history.count > 50 {
                history.removeLast()
            }
            
            saveHistory()
        }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
    
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

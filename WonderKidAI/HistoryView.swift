import SwiftUI

struct HistoryView: View {
    @Binding var isPresented: Bool
    let language: AppLanguage
    @StateObject private var manager = HistoryManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.SoftBlue.opacity(0.3).ignoresSafeArea()
                
                if manager.history.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text(language == .chinese ? "還沒有紀錄喔\n快去問問安安老師吧！" : "No records yet.\nGo ask Teacher An-An!")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(manager.history) { item in
                            VStack(alignment: .leading, spacing: 10) {
                                // 日期與時間
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.MagicBlue)
                                        .font(.caption)
                                    Text(item.date.formatted(date: .numeric, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    // 語言標記
                                    Text(item.language == "zh-TW" ? "🇹🇼" : "🇺🇸")
                                        .font(.caption)
                                }
                                
                                // 問題 (小朋友)
                                HStack(alignment: .top) {
                                    Text("Q:")
                                        .font(.headline)
                                        .foregroundColor(.ButtonRed)
                                    Text(item.question)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.DarkText)
                                }
                                
                                // 回答 (老師) - 只顯示前兩行，太多會太長
                                HStack(alignment: .top) {
                                    Text("A:")
                                        .font(.headline)
                                        .foregroundColor(.MagicBlue)
                                    Text(item.answer)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .lineLimit(3) // 只顯示3行，保持版面整潔
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .onDelete(perform: deleteItems) // 允許家長刪除單條紀錄
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(language == .chinese ? "👶 成長足跡" : "👶 Growth Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if !manager.history.isEmpty {
                        Button(language == .chinese ? "清空" : "Clear") {
                            manager.clearHistory()
                        }
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                }
            }
        }
    }
    
    func deleteItems(at offsets: IndexSet) {
        // 這裡需要實作刪除邏輯，簡單起見先重整
        var items = manager.history
        items.remove(atOffsets: offsets)
        // 重新存回去 (簡化版做法)
        manager.history = items
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: "WonderKidHistory")
        }
    }
}

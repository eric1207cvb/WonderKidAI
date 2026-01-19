import SwiftUI

struct HistoryView: View {
    @Binding var isPresented: Bool
    let language: AppLanguage
    
    // 引入管理員 (Singleton)
    @ObservedObject private var manager = HistoryManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // 1. 背景色 (自動適配深淺模式)
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                // 2. 內容區
                if manager.history.isEmpty {
                    // --- 空狀態 (Empty State) ---
                    VStack(spacing: 20) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary) // 自動變灰色
                        
                        Text(language == .chinese ? "還沒有紀錄喔\n快去問問安安老師吧！" : "No records yet.\nGo ask Teacher An-An!")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary) // 自動變灰色
                            .font(.system(.body, design: .rounded))
                    }
                } else {
                    // --- 列表內容 ---
                    List {
                        ForEach(manager.history) { item in
                            VStack(alignment: .leading, spacing: 12) {
                                // A. 頂部資訊列 (日期 | 語言)
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.MagicBlue)
                                        .font(.caption)
                                    
                                    Text(item.date.formatted(date: .numeric, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    // 顯示該筆紀錄是中文還是英文還是日文
                                    Text(item.language == "zh-TW" ? "🇹🇼" : (item.language == "ja-JP" ? "🇯🇵" : "🇺🇸"))
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                // B. 問題 (Q)
                                HStack(alignment: .top) {
                                    Text("Q:")
                                        .font(.headline)
                                        .foregroundColor(.ButtonRed)
                                    
                                    Text(item.question)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary) // 🔥 關鍵：深色模式變白，淺色模式變黑
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                
                                // C. 回答 (A)
                                HStack(alignment: .top) {
                                    Text("A:")
                                        .font(.headline)
                                        .foregroundColor(.MagicBlue)
                                    
                                    Text(item.answer)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary) // 🔥 關鍵：次要文字自動變灰
                                        .lineLimit(3) // 預覽只顯示 3 行
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        // 刪除功能
                        .onDelete { indexSet in
                            manager.deleteRecord(at: indexSet)
                        }
                    }
                    .listStyle(.insetGrouped) // 使用群組樣式，質感較好
                }
            }
            .navigationTitle(language == .chinese ? "👶 成長足跡" : "👶 Growth Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 右上角關閉按鈕
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                }
                
                // 左上角清空按鈕
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
        .navigationViewStyle(.stack) // 確保 iPad 顯示正常
    }
}

import SwiftUI
import RevenueCat // 👈 加入這行

@main
struct WonderKidAIApp: App {
    
    init() {
        // 🔥 初始化 RevenueCat
        // 請去 RevenueCat 後台 -> API Keys -> 複製 "Public SDK Key" (appl_xxxx...)
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "test_DlwDxLGmAkXmSCQZzMXRSQQvsaV")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

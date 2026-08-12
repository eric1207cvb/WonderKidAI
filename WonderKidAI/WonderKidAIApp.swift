import SwiftUI
import RevenueCat
import AVFoundation // 👈 1. 記得引入這個框架來修復聲音問題

@main
struct WonderKidAIApp: App {
    
    init() {
        // --- 1. 初始化 RevenueCat (依照你的要求，Key 寫死在這裡) ---
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif

        let configuration = Configuration
            .builder(withAPIKey: "appl_NSAHxRGGvIsicrSoplahHXZwhen")
            .with(entitlementVerificationMode: .informational)
            .build()
        Purchases.configure(with: configuration)
        
        // 🔥 2. [關鍵修正] 強制 SubscriptionManager 立即檢查一次狀態
        // 這樣 ContentView 才能馬上知道使用者是不是 VIP
        SubscriptionManager.shared.checkSubscriptionStatus()
        
        // 🔥 3. [關鍵修正] 設定全域音訊環境
        // 確保就算手機開靜音模式，安安老師的聲音還是能播放
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ 音訊環境設定失敗: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}

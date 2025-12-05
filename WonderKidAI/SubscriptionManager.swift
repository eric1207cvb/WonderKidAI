import Foundation
import RevenueCat
import Combine

// 🔥 修改 1: 加上 NSObject 繼承，這樣才能當 PurchasesDelegate
class SubscriptionManager: NSObject, ObservableObject {
    
    static let shared = SubscriptionManager()
    
    // UI 會監聽這個變數來決定要不要顯示鎖頭
    @Published var isPro: Bool = false
    @Published var customerInfo: CustomerInfo?
    
    // 設定你的 Entitlement ID (後台設定的權限名稱)
    private let proEntitlementID = "pro"
    
    private let dailyFreeLimit = 3
    
    // 🔥 修改 2: 因為繼承了 NSObject，所以要 override init 並呼叫 super
    override private init() {
        super.init()
        // 監聽 RevenueCat 的購買狀態變化
        Purchases.shared.delegate = self
    }
    
    // MARK: - 初始化設定
    func configure() {
        // 啟動時立刻檢查一次資格
        checkSubscriptionStatus()
    }
    
    // MARK: - 檢查額度 (免費仔邏輯)
    func checkUserQuota() -> Bool {
        if isPro { return true }
        
        let calendar = Calendar.current
        let today = Date()
        
        // 讀取 HistoryManager 判斷今天用了幾次
        // 確保 HistoryManager 已存在並公開 history 屬性
        let todayCount = HistoryManager.shared.history.filter { item in
            return calendar.isDate(item.date, inSameDayAs: today)
        }.count
        
        print("📊 今日免費額度使用: \(todayCount) / \(dailyFreeLimit)")
        return todayCount < dailyFreeLimit
    }
    
    // MARK: - 檢查訂閱狀態
    func checkSubscriptionStatus() {
        Purchases.shared.getCustomerInfo { [weak self] (info, error) in
            guard let self = self, let info = info else { return }
            self.updateProStatus(with: info)
        }
    }
    
    private func updateProStatus(with info: CustomerInfo) {
        DispatchQueue.main.async {
            self.customerInfo = info
            // 檢查是否擁有 "pro" 的權限
            self.isPro = info.entitlements[self.proEntitlementID]?.isActive == true
            print("👑 VIP Status: \(self.isPro)")
        }
    }
}

// MARK: - RevenueCat Delegate
extension SubscriptionManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        updateProStatus(with: customerInfo)
    }
}

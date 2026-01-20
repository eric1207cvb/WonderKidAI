import Foundation
import RevenueCat
import Combine
import Security

// 🔥 修改 1: 加上 NSObject 繼承，這樣才能當 PurchasesDelegate
class SubscriptionManager: NSObject, ObservableObject {
    
    static let shared = SubscriptionManager()
    
    // UI 會監聽這個變數來決定要不要顯示鎖頭
    @Published var isPro: Bool = false
    @Published var customerInfo: CustomerInfo?
    @Published var isSubscriptionLoaded: Bool = false
    @Published var hasServerTime: Bool = false
    
    // 設定你的 Entitlement ID (後台設定的權限名稱)
    private let proEntitlementID = "pro"
    
    private let dailyFreeLimit = 3
    private let quotaSnapshotKey = "WonderKidQuotaSnapshot"
    private let serverTimeKey = "WonderKidServerTime"
    private let lastKnownProKey = "WonderKidLastKnownPro"
    private let keychainService = Bundle.main.bundleIdentifier ?? "WonderKidAI"
    
    // 🔥 修改 2: 因為繼承了 NSObject，所以要 override init 並呼叫 super
    override private init() {
        super.init()
        isPro = loadLastKnownPro()
        hasServerTime = loadServerTime() != nil
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
        if !isSubscriptionLoaded { return false }
        guard let dayToken = currentServerDayToken() else { return false }
        
        var snapshot = loadQuotaSnapshot()
        if snapshot?.dayToken != dayToken {
            let freshSnapshot = QuotaSnapshot(count: 0, dayToken: dayToken)
            saveQuotaSnapshot(freshSnapshot)
            snapshot = freshSnapshot
        }
        
        let count = snapshot?.count ?? 0
        print("📊 今日免費額度使用: \(count) / \(dailyFreeLimit)")
        return count < dailyFreeLimit
    }

    func recordUsage() {
        if isPro || !isSubscriptionLoaded { return }
        guard let dayToken = currentServerDayToken() else { return }
        
        let snapshot = loadQuotaSnapshot()
        let count = (snapshot?.dayToken == dayToken ? snapshot?.count ?? 0 : 0) + 1
        saveQuotaSnapshot(QuotaSnapshot(count: count, dayToken: dayToken))
    }
    
    // MARK: - 檢查訂閱狀態
    func checkSubscriptionStatus() {
        Purchases.shared.getCustomerInfo { [weak self] (info, error) in
            guard let self = self else { return }
            if let info = info {
                self.updateProStatus(with: info)
            } else {
                DispatchQueue.main.async {
                    self.isSubscriptionLoaded = true
                }
            }
        }
    }
    
    private func updateProStatus(with info: CustomerInfo) {
        DispatchQueue.main.async {
            self.customerInfo = info
            // 檢查是否擁有 "pro" 的權限
            self.isPro = info.entitlements[self.proEntitlementID]?.isActive == true
            self.isSubscriptionLoaded = true
            self.saveLastKnownPro(self.isPro)
            print("👑 VIP Status: \(self.isPro)")
        }
    }

    func updateServerTime(from response: URLResponse) {
        guard let http = response as? HTTPURLResponse,
              let dateHeader = http.value(forHTTPHeaderField: "Date"),
              let date = parseServerDate(dateHeader) else { return }
        updateServerTime(date)
    }

    private func updateServerTime(_ date: Date) {
        if let stored = loadServerTime(), date <= stored { return }
        saveServerTime(date)
        DispatchQueue.main.async {
            self.hasServerTime = true
        }
    }

    private struct QuotaSnapshot: Codable {
        let count: Int
        let dayToken: String
    }

    private func currentServerDayToken() -> String? {
        guard let serverDate = loadServerTime() else { return nil }
        return dayToken(from: serverDate)
    }

    private func dayToken(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func parseServerDate(_ header: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        return formatter.date(from: header)
    }

    private func loadQuotaSnapshot() -> QuotaSnapshot? {
        guard let data = keychainGet(quotaSnapshotKey) else { return nil }
        return try? JSONDecoder().decode(QuotaSnapshot.self, from: data)
    }

    private func saveQuotaSnapshot(_ snapshot: QuotaSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        keychainSet(data, for: quotaSnapshotKey)
    }

    private func loadServerTime() -> Date? {
        guard let data = keychainGet(serverTimeKey),
              let timeInterval = try? JSONDecoder().decode(TimeInterval.self, from: data) else { return nil }
        return Date(timeIntervalSince1970: timeInterval)
    }

    private func saveServerTime(_ date: Date) {
        guard let data = try? JSONEncoder().encode(date.timeIntervalSince1970) else { return }
        keychainSet(data, for: serverTimeKey)
    }

    private func loadLastKnownPro() -> Bool {
        guard let data = keychainGet(lastKnownProKey),
              let value = try? JSONDecoder().decode(Bool.self, from: data) else { return false }
        return value
    }

    private func saveLastKnownPro(_ value: Bool) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        keychainSet(data, for: lastKnownProKey)
    }

    private func keychainGet(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private func keychainSet(_ data: Data, for key: String) {
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

// MARK: - RevenueCat Delegate
extension SubscriptionManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        updateProStatus(with: customerInfo)
    }
}

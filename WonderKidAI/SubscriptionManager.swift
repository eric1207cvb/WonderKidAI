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
    @Published var freeQuotaRemaining: Int?
    
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
        // Token-consuming access must be based on freshly verified RevenueCat state.
        isPro = false
        hasServerTime = loadServerTime() != nil
        refreshFreeQuotaState()
        // 監聽 RevenueCat 的購買狀態變化
        Purchases.shared.delegate = self
    }
    
    // MARK: - 初始化設定
    func configure() {
        // 啟動時立刻檢查一次資格
        checkSubscriptionStatus()
    }

    var dailyFreeLimitValue: Int {
        dailyFreeLimit
    }

    var hasVerifiedProAccess: Bool {
        isSubscriptionLoaded && isPro
    }
    
    // MARK: - 檢查額度 (免費仔邏輯)
    func checkUserQuota() -> Bool {
        if !isSubscriptionLoaded {
            refreshFreeQuotaState()
            return false
        }

        if hasVerifiedProAccess {
            refreshFreeQuotaState()
            return true
        }

        guard let remaining = currentRemainingFreeQuota() else {
            refreshFreeQuotaState()
            return false
        }

        let used = dailyFreeLimit - remaining
        print("📊 今日免費額度使用: \(used) / \(dailyFreeLimit)")
        refreshFreeQuotaState()
        return remaining > 0
    }

    func recordUsage() {
        if !isSubscriptionLoaded || hasVerifiedProAccess {
            refreshFreeQuotaState()
            return
        }
        guard let dayToken = currentServerDayToken() else {
            refreshFreeQuotaState()
            return
        }

        let nextCount = min(quotaCount(for: dayToken) + 1, dailyFreeLimit)
        saveQuotaSnapshot(QuotaSnapshot(count: nextCount, dayToken: dayToken))
        refreshFreeQuotaState()
    }
    
    // MARK: - 檢查訂閱狀態
    func checkSubscriptionStatus() {
        checkSubscriptionStatus(allowCacheRefreshRetry: true)
    }

    private func checkSubscriptionStatus(allowCacheRefreshRetry: Bool) {
        Purchases.shared.getCustomerInfo { [weak self] (info, error) in
            guard let self = self else { return }
            if let info = info {
                if allowCacheRefreshRetry, self.needsVerifiedCustomerInfoRefresh(info) {
                    Purchases.shared.invalidateCustomerInfoCache()
                    self.checkSubscriptionStatus(allowCacheRefreshRetry: false)
                    return
                }
                self.updateProStatus(with: info)
            } else {
                DispatchQueue.main.async {
                    self.isPro = false
                    self.isSubscriptionLoaded = true
                    self.refreshFreeQuotaState()
                    PremiumCloudSyncManager.shared.setPremiumSyncEnabled(false)
                }
            }
        }
    }

    private func needsVerifiedCustomerInfoRefresh(_ info: CustomerInfo) -> Bool {
        info.entitlements[proEntitlementID]?.isActive == true
            && !info.entitlements.verification.isVerified
    }
    
    private func updateProStatus(with info: CustomerInfo) {
        applyCustomerInfo(info)
    }

    @discardableResult
    func applyCustomerInfo(_ info: CustomerInfo) -> Bool {
        let hasVerifiedEntitlements = info.entitlements.verification.isVerified
        let isActivePro = info.entitlements[proEntitlementID]?.isActive == true && hasVerifiedEntitlements

        DispatchQueue.main.async {
            let wasVerifiedPro = self.hasVerifiedProAccess
            self.customerInfo = info
            // Token-consuming Pro access requires active entitlement and trusted RevenueCat verification.
            self.isPro = isActivePro
            self.isSubscriptionLoaded = true
            self.saveLastKnownPro(self.isPro)
            self.refreshFreeQuotaState()
            PremiumCloudSyncManager.shared.setPremiumSyncEnabled(self.hasVerifiedProAccess)
            self.handleSubscriptionDowngradeIfNeeded(wasVerifiedPro: wasVerifiedPro)
            if !hasVerifiedEntitlements {
                print("⚠️ RevenueCat entitlement verification failed or was not requested: \(info.entitlements.verification)")
            }
            print("👑 VIP Status: \(self.isPro)")
        }

        return isActivePro
    }

    private func handleSubscriptionDowngradeIfNeeded(wasVerifiedPro: Bool) {
        guard wasVerifiedPro, !hasVerifiedProAccess else { return }

        OpenAIService.shared.clearAllCachedAnswers()
        OpenAIService.shared.clearAllCachedAudio()
        PremiumCloudSyncManager.shared.setPremiumSyncEnabled(false)
        print("🔒 Pro entitlement inactive. Cleared premium caches and reverted to free quota rules.")
    }

    func updateServerTime(from response: URLResponse) {
        guard let http = response as? HTTPURLResponse,
              let dateHeader = http.value(forHTTPHeaderField: "Date"),
              let date = parseServerDate(dateHeader) else { return }
        updateServerTime(date)
    }

    private func updateServerTime(_ date: Date) {
        if let stored = loadServerTime(), date <= stored {
            refreshFreeQuotaState()
            return
        }
        saveServerTime(date)
        DispatchQueue.main.async {
            self.hasServerTime = true
            self.refreshFreeQuotaState()
        }
    }

    private struct QuotaSnapshot: Codable {
        let count: Int
        let dayToken: String
    }

    private func currentRemainingFreeQuota() -> Int? {
        guard let dayToken = currentServerDayToken() else { return nil }
        let count = quotaCount(for: dayToken)
        return max(dailyFreeLimit - count, 0)
    }

    private func quotaCount(for dayToken: String) -> Int {
        var snapshot = loadQuotaSnapshot()
        if snapshot?.dayToken != dayToken {
            let freshSnapshot = QuotaSnapshot(count: 0, dayToken: dayToken)
            saveQuotaSnapshot(freshSnapshot)
            snapshot = freshSnapshot
        }
        return snapshot?.count ?? 0
    }

    private func refreshFreeQuotaState() {
        let remaining: Int?
        if hasVerifiedProAccess {
            remaining = nil
        } else if !isSubscriptionLoaded {
            remaining = nil
        } else {
            remaining = currentRemainingFreeQuota()
        }

        DispatchQueue.main.async {
            self.freeQuotaRemaining = remaining
        }
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

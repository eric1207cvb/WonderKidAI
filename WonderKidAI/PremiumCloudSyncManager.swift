import Foundation

extension Notification.Name {
    static let premiumCloudLanguageDidChange = Notification.Name("PremiumCloudLanguageDidChange")
}

private struct CloudLanguagePayload: Codable {
    let languageRawValue: String
    let updatedAt: Date
}

private struct CloudHistoryPayload: Codable {
    let history: [HistoryItem]
    let deletedRecordIDs: [UUID]
    let clearedAt: Date?
    let updatedAt: Date
}

final class PremiumCloudSyncManager {
    static let shared = PremiumCloudSyncManager()

    private let store = NSUbiquitousKeyValueStore.default
    private let languageKey = "premium.languagePreference.v1"
    private let historyKey = "premium.history.v1"
    private let localLanguageUpdatedAtKey = "WonderKidCloudLanguageUpdatedAt"
    private let deletedRecordIDsKey = "WonderKidCloudDeletedHistoryIDs"
    private let historyClearedAtKey = "WonderKidCloudHistoryClearedAt"
    private let maxSyncedHistoryItems = 50
    private let maxDeletedRecordIDs = 240
    private let maxCloudPayloadBytes = 700_000

    private var isPremiumSyncEnabled = false
    private var isObserving = false
    private var isApplyingCloudUpdate = false

    private init() { }

    func setPremiumSyncEnabled(_ enabled: Bool) {
        guard enabled != isPremiumSyncEnabled else {
            if enabled {
                synchronizeNow()
            }
            return
        }

        isPremiumSyncEnabled = enabled

        if enabled {
            startObservingIfNeeded()
            synchronizeNow()
        }
    }

    func synchronizeNow() {
        guard isPremiumSyncEnabled else { return }

        store.synchronize()
        syncLanguageFromCloudOrSeedLocal()
        syncHistoryFromCloudOrSeedLocal()
    }

    func pushLanguagePreference(_ language: AppLanguage) {
        let now = Date()
        saveLocalLanguageUpdatedAt(now)
        guard isPremiumSyncEnabled, !isApplyingCloudUpdate else { return }
        writePayload(
            CloudLanguagePayload(languageRawValue: language.rawValue, updatedAt: now),
            forKey: languageKey
        )
    }

    func historyDidChange(_ history: [HistoryItem]) {
        guard isPremiumSyncEnabled, !isApplyingCloudUpdate else { return }
        pushHistorySnapshot(history)
    }

    func historyRecordDidDelete(_ id: UUID, remainingHistory: [HistoryItem]) {
        guard isPremiumSyncEnabled, !isApplyingCloudUpdate else { return }

        var deletedIDs = loadDeletedRecordIDs()
        deletedIDs.insert(id)
        saveDeletedRecordIDs(deletedIDs)
        pushHistorySnapshot(remainingHistory)
    }

    func historyDidClear(previousHistory: [HistoryItem]) {
        guard isPremiumSyncEnabled, !isApplyingCloudUpdate else { return }

        let now = Date()
        var deletedIDs = loadDeletedRecordIDs()
        deletedIDs.formUnion(previousHistory.map(\.id))
        saveDeletedRecordIDs(deletedIDs)
        saveHistoryClearedAt(now)
        pushHistorySnapshot([])
    }

    private func startObservingIfNeeded() {
        guard !isObserving else { return }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquitousStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        isObserving = true
    }

    @objc private func ubiquitousStoreDidChange(_ notification: Notification) {
        guard isPremiumSyncEnabled else { return }

        let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        if changedKeys == nil || changedKeys?.contains(languageKey) == true {
            syncLanguageFromCloudOrSeedLocal()
        }

        if changedKeys == nil || changedKeys?.contains(historyKey) == true {
            syncHistoryFromCloudOrSeedLocal()
        }
    }

    private func syncLanguageFromCloudOrSeedLocal() {
        let localLanguage = currentLocalLanguage()
        let localUpdatedAt = loadLocalLanguageUpdatedAt()

        guard let payload: CloudLanguagePayload = readPayload(forKey: languageKey),
              let cloudLanguage = AppLanguage(rawValue: payload.languageRawValue) else {
            if let localLanguage {
                pushLanguagePreference(localLanguage)
            }
            return
        }

        if let localUpdatedAt, localUpdatedAt >= payload.updatedAt {
            if let localLanguage, localUpdatedAt > payload.updatedAt {
                pushLanguagePreference(localLanguage)
            }
            return
        }

        isApplyingCloudUpdate = true
        saveLocalLanguageUpdatedAt(payload.updatedAt)
        isApplyingCloudUpdate = false

        NotificationCenter.default.post(
            name: .premiumCloudLanguageDidChange,
            object: nil,
            userInfo: ["language": cloudLanguage.rawValue]
        )
    }

    private func syncHistoryFromCloudOrSeedLocal() {
        guard let payload: CloudHistoryPayload = readPayload(forKey: historyKey) else {
            pushHistorySnapshot(HistoryManager.shared.history)
            return
        }

        var deletedIDs = loadDeletedRecordIDs()
        deletedIDs.formUnion(payload.deletedRecordIDs)
        saveDeletedRecordIDs(deletedIDs)

        if let clearedAt = payload.clearedAt {
            let localClearedAt = loadHistoryClearedAt()
            if localClearedAt == nil || clearedAt > localClearedAt! {
                saveHistoryClearedAt(clearedAt)
            }
        }

        isApplyingCloudUpdate = true
        let didChange = HistoryManager.shared.applyCloudHistory(
            payload.history,
            deletedRecordIDs: deletedIDs,
            clearedAt: loadHistoryClearedAt()
        )
        isApplyingCloudUpdate = false

        if didChange {
            pushHistorySnapshot(HistoryManager.shared.history)
        }
    }

    private func pushHistorySnapshot(_ history: [HistoryItem]) {
        var syncedHistory = Array(history.prefix(maxSyncedHistoryItems))

        while !syncedHistory.isEmpty {
            let payload = makeHistoryPayload(with: syncedHistory)
            guard let data = try? JSONEncoder().encode(payload) else { return }

            if data.count <= maxCloudPayloadBytes {
                writeData(data, forKey: historyKey)
                return
            }

            syncedHistory.removeLast()
        }

        writePayload(makeHistoryPayload(with: []), forKey: historyKey)
    }

    private func makeHistoryPayload(with history: [HistoryItem]) -> CloudHistoryPayload {
        CloudHistoryPayload(
            history: history,
            deletedRecordIDs: Array(loadDeletedRecordIDs().prefix(maxDeletedRecordIDs)),
            clearedAt: loadHistoryClearedAt(),
            updatedAt: Date()
        )
    }

    private func currentLocalLanguage() -> AppLanguage? {
        guard let rawValue = UserDefaults.standard.string(forKey: "WonderKidPreferredLanguage") else {
            return nil
        }
        return AppLanguage(rawValue: rawValue)
    }

    private func readPayload<T: Decodable>(forKey key: String) -> T? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func writePayload<T: Encodable>(_ payload: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        writeData(data, forKey: key)
    }

    private func writeData(_ data: Data, forKey key: String) {
        store.set(data, forKey: key)
        store.synchronize()
    }

    private func loadLocalLanguageUpdatedAt() -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: localLanguageUpdatedAtKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func saveLocalLanguageUpdatedAt(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: localLanguageUpdatedAtKey)
    }

    private func loadDeletedRecordIDs() -> Set<UUID> {
        let rawValues = UserDefaults.standard.stringArray(forKey: deletedRecordIDsKey) ?? []
        return Set(rawValues.compactMap(UUID.init(uuidString:)))
    }

    private func saveDeletedRecordIDs(_ ids: Set<UUID>) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: deletedRecordIDsKey)
    }

    private func loadHistoryClearedAt() -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: historyClearedAtKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func saveHistoryClearedAt(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: historyClearedAtKey)
    }
}

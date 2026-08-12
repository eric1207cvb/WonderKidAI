import SwiftUI

struct LegalView: View {
    let type: LegalType
    let language: AppLanguage
    @Binding var isPresented: Bool
    @Environment(\.openURL) private var openURL
    @State private var showParentalGate = false
    @State private var pendingURL: URL?

    enum LegalType {
        case privacy
        case eula
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let isPad = UIDevice.current.userInterfaceIdiom == .pad && geometry.size.width >= 700
                ZStack {
                    legalBackground
                    ScrollView(showsIndicators: false) {
                        Group {
                            if type == .privacy {
                                PrivacyPolicyPage(copy: PrivacyPolicyCopy(language: language), isPad: isPad)
                            } else {
                                EULAPage(language: language, isPad: isPad, openAppleEULA: openAppleEULA)
                            }
                        }
                        .frame(maxWidth: isPad ? 760 : .infinity, alignment: .leading)
                        .padding(.horizontal, isPad ? 28 : 18)
                        .padding(.top, isPad ? 24 : 16)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom + 36, 52))
                        .frame(maxWidth: .infinity)
                    }

                    if showParentalGate {
                        ParentalGateView(isPresented: $showParentalGate, language: language) {
                            if let pendingURL { openURL(pendingURL) }
                            pendingURL = nil
                        }
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(1)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(closeLabel)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var legalBackground: some View {
        LinearGradient(
            colors: [Color(uiColor: .systemBackground), Color.MagicBlue.opacity(0.08), Color(uiColor: .systemBackground)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var title: String {
        switch (type, language) {
        case (.privacy, .chinese): return "隱私權政策"
        case (.privacy, .english): return "Privacy Policy"
        case (.privacy, .japanese): return "プライバシーポリシー"
        case (.eula, .chinese): return "使用者授權協定"
        case (.eula, .english): return "EULA"
        case (.eula, .japanese): return "利用規約"
        }
    }

    private var closeLabel: String {
        switch language { case .chinese: return "關閉"; case .english: return "Close"; case .japanese: return "閉じる" }
    }

    private func openAppleEULA() {
        pendingURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
        showParentalGate = true
    }
}

private struct PrivacyPolicyPage: View {
    let copy: PrivacyPolicyCopy
    let isPad: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isPad ? 20 : 16) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: isPad ? 34 : 30, weight: .bold))
                    .foregroundStyle(Color.MagicBlue)
                    .frame(width: isPad ? 66 : 58, height: isPad ? 66 : 58)
                    .background(Color.MagicBlue.opacity(0.12), in: Circle())

                Text(copy.heroTitle)
                    .font(.system(size: isPad ? 29 : 25, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                Text(copy.heroSubtitle)
                    .font(.system(size: isPad ? 16 : 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Label(copy.lastUpdated, systemImage: "calendar")
                    .font(.system(size: isPad ? 14 : 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.MagicBlue)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Color.MagicBlue.opacity(0.1), in: Capsule())
            }
            .padding(isPad ? 24 : 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.72)) }

            PrivacyHighlight(icon: "checkmark.shield.fill", title: copy.promiseTitle, message: copy.promiseMessage, color: .green, isPad: isPad)

            ForEach(copy.sections) { section in
                PrivacySectionCard(section: section, isPad: isPad)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(copy.contactTitle)
                    .font(.system(size: isPad ? 17 : 15, weight: .bold, design: .rounded))
                Text(copy.contactMessage)
                    .font(.system(size: isPad ? 15 : 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("eric1207cvb@msn.com")
                    .font(.system(size: isPad ? 17 : 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.MagicBlue)
                    .textSelection(.enabled)
            }
            .padding(isPad ? 20 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.MagicBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

private struct PrivacyHighlight: View {
    let icon: String
    let title: String
    let message: String
    let color: Color
    let isPad: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: isPad ? 22 : 19, weight: .bold)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: isPad ? 17 : 15, weight: .bold, design: .rounded))
                Text(message).font(.system(size: isPad ? 15 : 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(isPad ? 18 : 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct PrivacySectionCard: View {
    let section: PrivacySection
    let isPad: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isPad ? 14 : 12) {
            Label(section.title, systemImage: section.icon)
                .font(.system(size: isPad ? 19 : 17, weight: .heavy, design: .rounded))
                .foregroundStyle(section.color)
            ForEach(section.points, id: \.self) { point in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(section.color.opacity(0.76)).padding(.top, 2)
                    Text(point).font(.system(size: isPad ? 16 : 14, weight: .regular, design: .rounded)).foregroundStyle(Color.primary.opacity(0.82)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(isPad ? 20 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(section.color.opacity(0.15)) }
    }
}

private struct EULAPage: View {
    let language: AppLanguage
    let isPad: Bool
    let openAppleEULA: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: isPad ? 20 : 16) {
            Label(title, systemImage: "doc.text.fill")
                .font(.system(size: isPad ? 28 : 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.MagicBlue)
            Text(content)
                .font(.system(size: isPad ? 16 : 14, weight: .regular, design: .rounded))
                .foregroundStyle(.primary)
                .lineSpacing(isPad ? 7 : 5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(isPad ? 20 : 16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            Button(action: openAppleEULA) {
                Label(buttonTitle, systemImage: "arrow.up.right.square")
                    .font(.system(size: isPad ? 16 : 14, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.MagicBlue)
        }
    }

    private var title: String { switch language { case .chinese: return "標準使用者授權合約"; case .english: return "End User License Agreement"; case .japanese: return "利用規約" } }
    private var buttonTitle: String { switch language { case .chinese: return "閱讀 Apple 完整 EULA"; case .english: return "Read Apple’s Full EULA"; case .japanese: return "Apple EULA 全文を読む" } }
    private var content: String {
        switch language {
        case .chinese: return "本應用程式依 Apple 標準使用者授權合約提供使用。您與開發者締結本協議，而非 Apple。開發者對 App 及其內容負責；Apple 不負維護或支援義務。"
        case .english: return "This App is licensed under Apple’s Standard EULA. This agreement is between you and the Developer, not Apple. The Developer is responsible for the App and its content; Apple has no maintenance or support obligation."
        case .japanese: return "本アプリは Apple 標準 EULA に基づいて提供されます。本契約はお客様と開発者の間の契約であり、Apple との契約ではありません。アプリとその内容は開発者が責任を負い、Apple に保守・サポート義務はありません。"
        }
    }
}

private struct PrivacySection: Identifiable {
    let id: String
    let icon: String
    let title: String
    let points: [String]
    let color: Color
}

private struct PrivacyPolicyCopy {
    let language: AppLanguage

    var heroTitle: String { switch language { case .chinese: return "孩子的好奇心，值得被好好保護"; case .english: return "A safe place for children’s curiosity"; case .japanese: return "子どもの好奇心を、たいせつに守ります" } }
    var heroSubtitle: String { switch language { case .chinese: return "WonderKidAI 為兒童設計；以下清楚說明哪些資料留在裝置，以及哪些資料會傳給服務供應商。"; case .english: return "WonderKidAI is designed for children. This explains what stays on the device and what is sent to service providers."; case .japanese: return "WonderKidAI は子どものためのアプリです。端末に残る情報と、サービス提供者に送られる情報をわかりやすく説明します。" } }
    var lastUpdated: String { switch language { case .chinese: return "最後更新：2026 年 8 月 12 日"; case .english: return "Last updated: August 12, 2026"; case .japanese: return "最終更新：2026 年 8 月 12 日" } }
    var promiseTitle: String { switch language { case .chinese: return "我們重視兒童隱私"; case .english: return "We value children’s privacy"; case .japanese: return "子どものプライバシーを大切にします" } }
    var promiseMessage: String { switch language { case .chinese: return "本 App 專為兒童設計，並以 COPPA 與相關兒童隱私規範為設計原則。"; case .english: return "The App is designed for children, with COPPA and related children’s privacy principles in mind."; case .japanese: return "本アプリは子ども向けに設計され、COPPA などの児童プライバシーの考え方を大切にしています。" } }
    var contactTitle: String { switch language { case .chinese: return "有隱私權相關問題嗎？"; case .english: return "Questions about privacy?"; case .japanese: return "プライバシーに関するご質問" } }
    var contactMessage: String { switch language { case .chinese: return "請直接聯絡開發者："; case .english: return "Please contact the Developer:"; case .japanese: return "開発者までご連絡ください：" } }

    var sections: [PrivacySection] {
        switch language {
        case .chinese:
            return [
                .init(id: "device", icon: "iphone.and.arrow.forward", title: "留在裝置上的內容", points: ["提問、回答與成長紀錄預設保存在裝置；可在「成長足跡」逐筆或全部刪除。", "為加快重播，回答與語音可能暫存於 App 快取；系統可自行清除這些快取。"], color: .MagicBlue),
                .init(id: "ai", icon: "waveform.badge.mic", title: "語音、Render 與 OpenAI", points: ["語音辨識使用 Apple Speech；送往 AI 的是辨識出的文字與你輸入的問題，而不是本 App 直接上傳的原始錄音檔。", "提問文字與朗讀文字會先傳至 Render 作為服務閘道，再由 OpenAI 產生回答與語音。各供應商依其服務與資料政策處理請求。"], color: .purple),
                .init(id: "identifier", icon: "key.fill", title: "識別碼與訂閱", points: ["App 在裝置 Keychain 建立隨機安裝識別碼，用於用量限制、防濫用與服務穩定；每次 AI 或語音請求會傳給 Render。", "RevenueCat 處理 App Store 訂閱與恢復購買；其匿名 App User ID 用來核對權益，也會隨服務請求傳送。"], color: .orange),
                .init(id: "references", icon: "book.closed.fill", title: "Wikipedia 知識來源", points: ["部分知識型問題會將查詢詞直接傳至對應語言的 Wikipedia，以取得公開摘要；Wikimedia 依其政策處理該網路請求。", "我們不提供廣告，也不會用資料跨 App 或跨網站追蹤你。"], color: .teal),
                .init(id: "icloud", icon: "icloud.fill", title: "iCloud 同步與安全", points: ["付費訂閱驗證後，App 會透過 Apple iCloud Key-Value Storage 同步語言偏好及最多 50 筆問答紀錄（問題、回答、日期、語言）到同一 Apple ID 的裝置。", "服務傳輸使用加密連線。請家長協助孩子避免在問題中分享姓名、地址、電話或其他私密資訊。"], color: .green)
            ]
        case .english:
            return [
                .init(id: "device", icon: "iphone.and.arrow.forward", title: "What stays on your device", points: ["Questions, answers, and Growth Journey records are stored on the device by default. They can be deleted one at a time or all at once in Growth Journey.", "To make replay faster, answer and audio files may be kept in the App cache. The system may clear this cache."], color: .MagicBlue),
                .init(id: "ai", icon: "waveform.badge.mic", title: "Speech, Render, and OpenAI", points: ["Speech recognition uses Apple Speech. The App sends the recognized text and typed questions to AI services, not the raw microphone recording directly to our App backend.", "Question text and text for narration are sent to Render as a service gateway and then to OpenAI to create answers and speech. Each provider handles requests under its own service and data policies."], color: .purple),
                .init(id: "identifier", icon: "key.fill", title: "Identifiers and subscriptions", points: ["The App creates a random installation identifier in the device Keychain for rate limits, abuse prevention, and service reliability. It is sent to Render with AI and speech requests.", "RevenueCat handles App Store subscriptions and Restore Purchases. Its anonymous App User ID is used to check entitlements and is also sent with service requests."], color: .orange),
                .init(id: "references", icon: "book.closed.fill", title: "Wikipedia as a knowledge source", points: ["For some factual questions, the search term is sent directly to the matching-language Wikipedia to retrieve a public summary. Wikimedia handles that network request under its own policy.", "We do not serve advertising or use data to track you across apps or websites."], color: .teal),
                .init(id: "icloud", icon: "icloud.fill", title: "iCloud sync and security", points: ["After a paid subscription is verified, the App uses Apple iCloud Key-Value Storage to sync language preference and up to 50 question-and-answer records (question, answer, date, and language) to devices using the same Apple ID.", "Service connections use encryption. Parents should help children avoid sharing names, addresses, phone numbers, or other private information in questions."], color: .green)
            ]
        case .japanese:
            return [
                .init(id: "device", icon: "iphone.and.arrow.forward", title: "端末に保存される内容", points: ["質問、回答、成長の記録は標準で端末に保存されます。「成長の記録」から1件ずつ、またはすべて削除できます。", "再生を速くするため、回答と音声をアプリのキャッシュに一時保存することがあります。キャッシュはシステムにより削除される場合があります。"], color: .MagicBlue),
                .init(id: "ai", icon: "waveform.badge.mic", title: "音声、Render、OpenAI", points: ["音声認識には Apple Speech を使用します。AI サービスに送られるのは認識された文字と入力した質問であり、本アプリのバックエンドに生の録音データを直接送るものではありません。", "質問文と読み上げ用テキストはサービスの入口である Render に送られ、その後 OpenAI が回答と音声を生成します。各提供者はそれぞれのサービスおよびデータポリシーに従ってリクエストを処理します。"], color: .purple),
                .init(id: "identifier", icon: "key.fill", title: "識別子とサブスクリプション", points: ["アプリは利用回数の制限、不正利用の防止、サービスの安定運用のために、端末の Keychain にランダムなインストール識別子を作成します。この識別子は AI と音声のリクエストとともに Render に送られます。", "RevenueCat は App Store のサブスクリプションと購入の復元を処理します。匿名の App User ID は利用資格の確認に使用され、サービスへのリクエストにも送られます。"], color: .orange),
                .init(id: "references", icon: "book.closed.fill", title: "Wikipedia の知識ソース", points: ["一部の知識に関する質問では、公開要約を取得するため、検索語を対応言語の Wikipedia に直接送信します。この通信は Wikimedia のポリシーに従って処理されます。", "広告の配信や、アプリやウェブサイトをまたぐ追跡は行いません。"], color: .teal),
                .init(id: "icloud", icon: "icloud.fill", title: "iCloud 同期と安全性", points: ["有料サブスクリプションの確認後、Apple iCloud Key-Value Storage を使い、言語設定と最大50件の質問・回答記録（質問、回答、日付、言語）を同じ Apple ID の端末に同期します。", "サービスとの通信には暗号化接続を使用します。お子さまが質問の中で氏名、住所、電話番号などの個人情報を共有しないよう、保護者の方がお手伝いください。"], color: .green)
            ]
        }
    }
}

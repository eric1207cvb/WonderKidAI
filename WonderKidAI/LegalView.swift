import SwiftUI

struct LegalView: View {
    let type: LegalType
    let language: AppLanguage
    @Binding var isPresented: Bool
    
    enum LegalType {
        case privacy
        case eula
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // 1. 主要條款內容
                    Text(getContent())
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                    
                    // 2. 分隔線
                    Divider()
                        .padding(.vertical, 10)
                    
                    // 3. 🔥 新增：外部超連結按鈕 (EULA 專用)
                    if type == .eula {
                        Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                    .font(.system(size: 20))
                                Text(language == .chinese ? "點此閱讀完整 Apple EULA 條款" : (language == .japanese ? "Apple EULA全文を読む" : "Read Full Apple EULA"))
                                    .fontWeight(.bold)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.MagicBlue) // 使用你的主題色
                            .cornerRadius(12)
                            .shadow(radius: 2)
                        }
                    } else if type == .privacy {
                        // 隱私權政策的外部連結 (連回你的 GitHub 隱私頁面)
                        Link(destination: URL(string: "https://github.com/eric1207cvb/WonderKidAI/blob/main/PRIVACY.md")!) {
                            HStack {
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 20))
                                Text(language == .chinese ? "線上查看完整隱私權政策" : (language == .japanese ? "オンラインで全文を読む" : "View Privacy Policy Online"))
                                    .fontWeight(.bold)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                            }
                            .padding()
                            .foregroundColor(.MagicBlue)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.MagicBlue, lineWidth: 1)
                            )
                        }
                    }
                    
                    // 底部留白，避免被 Home Bar 擋住
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle(getTitle())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 24))
                    }
                }
            }
        }
        .navigationViewStyle(.stack) // 確保 iPad 相容性
    }
    
    func getTitle() -> String {
        switch type {
        case .privacy:
            switch language {
            case .chinese: return "隱私權政策"
            case .english: return "Privacy Policy"
            case .japanese: return "プライバシーポリシー"
            }
        case .eula:
            switch language {
            case .chinese: return "使用者授權協定"
            case .english: return "EULA"
            case .japanese: return "利用規約"
            }
        }
    }
    
    func getContent() -> String {
        if type == .privacy {
            switch language {
            case .chinese:
                return """
                【隱私權政策摘要】
                
                最後更新日期：2025年12月
                
                WonderKidAI（以下簡稱「本應用程式」）非常重視您的隱私權。本應用程式專為兒童設計，我們承諾遵守《兒童線上隱私權保護法》(COPPA) 及相關法律規範。
                
                1. 資料收集
                - 我們「不會」收集任何個人識別資料（如姓名、地址、電話）。
                - 用戶的語音與圖片數據僅用於即時 AI 分析，分析完成後即丟棄，不會儲存在我們的伺服器上。
                - 所有的對話紀錄僅儲存在您的本機裝置中。
                
                2. AI 技術使用
                - 本應用程式使用 OpenAI API 進行語言與影像處理。
                - 傳輸過程皆經過加密處理。
                
                3. 聯絡我們
                - 如果您對隱私權有任何疑問，請聯繫開發者：eric1207cvb@msn.com
                """
            case .english:
                return """
                [Privacy Policy Summary]
                
                Last Updated: Dec 2025
                
                WonderKidAI ("the App") values your privacy. Designed for children, we are committed to complying with COPPA.
                
                1. Data Collection
                - We do NOT collect any personally identifiable information (PII).
                - Voice and image data are used solely for real-time AI analysis and are discarded immediately after processing.
                - All chat history is stored locally on your device.
                
                2. AI Technology
                - The App uses OpenAI API for processing.
                - All data transmission is encrypted.
                
                3. Contact
                - If you have questions, please contact the developer: eric1207cvb@msn.com
                """
            case .japanese:
                return """
                【プライバシーポリシー概要】
                
                最終更新日：2025年12月
                
                WonderKidAI（以下「本アプリ」）は、お客様のプライバシーを非常に重視しています。本アプリは子ども向けに設計されており、COPPA（児童オンラインプライバシー保護法）を遵守します。
                
                1. データ収集
                - 個人を特定できる情報（氏名、住所、電話番号）は一切収集しません。
                - 音声と画像データはリアルタイムAI分析のみに使用され、処理後は直ちに破棄されます。
                - 会話履歴はすべてお客様のデバイス内にのみ保存されます。
                
                2. AI技術の使用
                - 本アプリはOpenAI APIを使用しています。
                - すべてのデータ送信は暗号化されています。
                
                3. お問い合わせ
                - プライバシーに関するご質問は開発者までご連絡ください：eric1207cvb@msn.com
                """
            }
        } else {
            // EULA
            switch language {
            case .chinese:
                return """
                【標準使用者授權合約 (EULA)】
                
                本應用程式依據 Apple 標準使用者授權合約 (Standard EULA) 提供使用。
                
                1. 您確認本協議是您與開發者之間的協議，而非 Apple。
                2. 開發者對本應用程式的內容全權負責。
                3. 您同意遵守所有適用的第三方合約條款。
                4. 您承認 Apple 對本應用程式不負有維護或支援的義務。
                """
            case .english:
                return """
                [End User License Agreement (EULA)]
                
                This App is licensed under the standard Apple End User License Agreement.
                
                1. Acknowledgment: You and the Developer acknowledge that this EULA is concluded between You and the Developer only, and not with Apple.
                2. Developer is solely responsible for the App and its content.
                3. No Warranty: The App is provided "as is".
                """
            case .japanese:
                return """
                【利用規約（EULA）】
                
                本アプリは、Apple標準利用規約（Standard EULA）に基づいて提供されます。
                
                1. 本契約はお客様と開発者との間の契約であり、Appleとの契約ではありません。
                2. 開発者が本アプリのコンテンツに全責任を負います。
                3. 本アプリは「現状有姿」で提供されます。
                4. Appleは本アプリの保守またはサポートの義務を負いません。
                """
            }
        }
    }
}

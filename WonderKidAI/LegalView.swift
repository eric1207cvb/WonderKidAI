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
                    Text(getContent())
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineSpacing(4)
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
                    }
                }
            }
        }
    }
    
    func getTitle() -> String {
        switch type {
        case .privacy:
            return language == .chinese ? "隱私權政策" : "Privacy Policy"
        case .eula:
            return language == .chinese ? "使用者授權協定 (EULA)" : "EULA"
        }
    }
    
    func getContent() -> String {
        if type == .privacy {
            if language == .chinese {
                return """
                【隱私權政策】
                
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
            } else {
                return """
                [Privacy Policy]
                
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
            }
        } else {
            // EULA
            if language == .chinese {
                return """
                【標準使用者授權合約 (EULA)】
                
                本應用程式依據 Apple 標準使用者授權合約提供使用。
                
                1. 您確認本協議是您與開發者之間的協議，而非 Apple。
                2. 開發者對本應用程式的內容全權負責。
                3. 您同意遵守所有適用的第三方合約條款。
                4. 您承認 Apple 對本應用程式不負有維護或支援的義務。
                
                (完整條款請參閱 Apple Media Services Terms and Conditions)
                """
            } else {
                return """
                [End User License Agreement (EULA)]
                
                This App is licensed under the standard Apple End User License Agreement.
                
                1. Acknowledgment: You and the Developer acknowledge that this EULA is concluded between You and the Developer only, and not with Apple.
                2. Developer is solely responsible for the App and its content.
                3. No Warranty: The App is provided "as is".
                
                (For full terms, please refer to Apple Media Services Terms and Conditions)
                """
            }
        }
    }
}//
//  LegalView.swift
//  WonderKidAI
//
//  Created by 薛宜安 on 2025/12/2.
//


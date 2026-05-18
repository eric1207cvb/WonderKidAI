import SwiftUI

struct HistoryView: View {
    @Binding var isPresented: Bool
    let language: AppLanguage

    @ObservedObject private var manager = HistoryManager.shared
    @State private var expandedRecordID: UUID?
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let isPad = UIDevice.current.userInterfaceIdiom == .pad && geometry.size.width >= 700
                let contentMaxWidth: CGFloat = isPad ? 820 : .infinity
                let horizontalPadding: CGFloat = isPad ? 28 : 18
                let text = HistoryCopy(language: language)

                ZStack {
                    historyBackground

                    ScrollView {
                        VStack(spacing: isPad ? 18 : 14) {
                            historyHero(text: text, isPad: isPad)

                            if manager.history.isEmpty {
                                emptyState(text: text, isPad: isPad)
                            } else {
                                summaryStrip(text: text, isPad: isPad)

                                LazyVStack(spacing: isPad ? 16 : 12) {
                                    ForEach(manager.history) { item in
                                        HistoryRecordCard(
                                            item: item,
                                            interfaceLanguage: language,
                                            text: text,
                                            isPad: isPad,
                                            isExpanded: expandedRecordID == item.id,
                                            onToggleExpanded: {
                                                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                                    expandedRecordID = expandedRecordID == item.id ? nil : item.id
                                                }
                                            },
                                            onDelete: {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    manager.deleteRecord(id: item.id)
                                                    if expandedRecordID == item.id {
                                                        expandedRecordID = nil
                                                    }
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: contentMaxWidth)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, isPad ? 22 : 14)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom + 24, 34))
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(HistoryCopy(language: language).title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !manager.history.isEmpty {
                        Button {
                            showClearConfirmation = true
                        } label: {
                            Label(HistoryCopy(language: language).clearButton, systemImage: "trash")
                                .labelStyle(.titleAndIcon)
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.ButtonRed)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .confirmationDialog(
                HistoryCopy(language: language).clearConfirmTitle,
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button(HistoryCopy(language: language).clearConfirmAction, role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        manager.clearHistory()
                        expandedRecordID = nil
                    }
                }

                Button(HistoryCopy(language: language).cancelButton, role: .cancel) { }
            } message: {
                Text(HistoryCopy(language: language).clearConfirmMessage)
            }
        }
        .navigationViewStyle(.stack)
    }

    private var historyBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.98, blue: 0.91),
                    Color(red: 0.91, green: 0.96, blue: 1.0),
                    Color(red: 0.98, green: 0.95, blue: 0.89)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.ButtonOrange.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 34)
                .offset(x: -160, y: -240)

            Circle()
                .fill(Color.MagicBlue.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 42)
                .offset(x: 180, y: 260)
        }
    }

    private func historyHero(text: HistoryCopy, isPad: Bool) -> some View {
        HStack(spacing: isPad ? 18 : 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.ButtonOrange, Color.ButtonRed.opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isPad ? 66 : 58, height: isPad ? 66 : 58)

                Image(systemName: "sparkles")
                    .font(.system(size: isPad ? 28 : 24, weight: .heavy))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(text.heroTitle)
                    .font(.system(size: isPad ? 28 : 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.DarkText)

                Text(text.heroSubtitle)
                    .font(.system(size: isPad ? 16 : 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.DarkText.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(isPad ? 22 : 18)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.MagicBlue.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    private func emptyState(text: HistoryCopy, isPad: Bool) -> some View {
        VStack(spacing: isPad ? 18 : 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white.opacity(0.74))
                    .frame(width: isPad ? 150 : 124, height: isPad ? 126 : 106)

                Image(systemName: "book.pages.fill")
                    .font(.system(size: isPad ? 58 : 48, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.MagicBlue, Color.ButtonOrange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(text.emptyTitle)
                .font(.system(size: isPad ? 24 : 20, weight: .heavy, design: .rounded))
                .foregroundColor(.DarkText)

            Text(text.emptyMessage)
                .font(.system(size: isPad ? 17 : 15, weight: .semibold, design: .rounded))
                .foregroundColor(.DarkText.opacity(0.68))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isPad ? 56 : 42)
        .padding(.horizontal, 22)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8, 8]))
                .foregroundColor(Color.MagicBlue.opacity(0.28))
        )
    }

    private func summaryStrip(text: HistoryCopy, isPad: Bool) -> some View {
        HStack(spacing: isPad ? 12 : 8) {
            SummaryChip(
                icon: "tray.full.fill",
                title: text.totalLabel,
                value: "\(manager.history.count)",
                color: .MagicBlue,
                isPad: isPad
            )

            SummaryChip(
                icon: "globe.asia.australia.fill",
                title: text.languageLabel,
                value: "\(languageCounts.count)",
                color: .ButtonOrange,
                isPad: isPad
            )

            SummaryChip(
                icon: "clock.fill",
                title: text.latestLabel,
                value: latestShortDate,
                color: .ButtonRed,
                isPad: isPad
            )
        }
    }

    private var languageCounts: [String: Int] {
        Dictionary(grouping: manager.history, by: \.language).mapValues(\.count)
    }

    private var latestShortDate: String {
        guard let latest = manager.history.first?.date else { return "-" }
        return latest.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
                .locale(Locale(identifier: HistoryCopy(language: language).localeIdentifier))
        )
    }
}

private struct SummaryChip: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let isPad: Bool

    var body: some View {
        HStack(spacing: isPad ? 10 : 7) {
            Image(systemName: icon)
                .font(.system(size: isPad ? 15 : 12, weight: .bold))
                .foregroundColor(color)
                .frame(width: isPad ? 30 : 24, height: isPad ? 30 : 24)
                .background(color.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: isPad ? 12 : 10, weight: .bold, design: .rounded))
                    .foregroundColor(.DarkText.opacity(0.56))
                    .lineLimit(1)

                Text(value)
                    .font(.system(size: isPad ? 16 : 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.DarkText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, isPad ? 12 : 10)
        .padding(.horizontal, isPad ? 14 : 10)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: color.opacity(0.08), radius: 10, x: 0, y: 6)
    }
}

private struct HistoryRecordCard: View {
    let item: HistoryItem
    let interfaceLanguage: AppLanguage
    let text: HistoryCopy
    let isPad: Bool
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: isPad ? 16 : 13) {
            metadataRow

            PromptBlock(
                label: text.questionLabel,
                icon: "questionmark.bubble.fill",
                color: .ButtonRed,
                content: item.question,
                itemLanguage: itemLanguage,
                isAnswer: false,
                isExpanded: true,
                isPad: isPad
            )

            PromptBlock(
                label: text.answerLabel,
                icon: "sparkles.rectangle.stack.fill",
                color: .MagicBlue,
                content: item.answer,
                itemLanguage: itemLanguage,
                isAnswer: true,
                isExpanded: isExpanded,
                isPad: isPad
            )

            footerRow
        }
        .padding(isPad ? 20 : 16)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.95), lineWidth: 1)
        )
        .shadow(color: Color.MagicBlue.opacity(0.11), radius: 16, x: 0, y: 8)
    }

    private var metadataRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "calendar")
                    .font(.system(size: isPad ? 13 : 11, weight: .bold))
                    .foregroundColor(.MagicBlue)

                Text(formattedDate)
                    .font(.system(size: isPad ? 13 : 11, weight: .bold, design: .rounded))
                    .foregroundColor(.DarkText.opacity(0.62))
                    .lineLimit(1)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(Color.MagicBlue.opacity(0.1), in: Capsule())

            Text(languageBadge)
                .font(.system(size: isPad ? 13 : 11, weight: .heavy, design: .rounded))
                .foregroundColor(.DarkText.opacity(0.7))
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(Color.ButtonOrange.opacity(0.14), in: Capsule())

            Spacer(minLength: 0)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: isPad ? 14 : 12, weight: .bold))
                    .foregroundColor(.ButtonRed)
                    .frame(width: isPad ? 34 : 30, height: isPad ? 34 : 30)
                    .background(Color.ButtonRed.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(text.deleteButton)
        }
    }

    private var footerRow: some View {
        HStack {
            Text(text.savedLocally)
                .font(.system(size: isPad ? 12 : 10, weight: .bold, design: .rounded))
                .foregroundColor(.DarkText.opacity(0.48))

            Spacer(minLength: 0)

            Button(action: onToggleExpanded) {
                HStack(spacing: 6) {
                    Text(isExpanded ? text.collapseButton : text.expandButton)
                        .font(.system(size: isPad ? 14 : 12, weight: .heavy, design: .rounded))

                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: isPad ? 16 : 14, weight: .bold))
                }
                .foregroundColor(.MagicBlue)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.MagicBlue.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var itemLanguage: AppLanguage {
        AppLanguage(rawValue: item.language) ?? interfaceLanguage
    }

    private var formattedDate: String {
        item.date.formatted(
            .dateTime
                .year()
                .month(.abbreviated)
                .day()
                .hour()
                .minute()
                .locale(Locale(identifier: text.localeIdentifier))
        )
    }

    private var languageBadge: String {
        switch itemLanguage {
        case .chinese:
            return "🇹🇼 中文"
        case .english:
            return "🇺🇸 English"
        case .japanese:
            return "🇯🇵 日本語"
        }
    }
}

private struct PromptBlock: View {
    let label: String
    let icon: String
    let color: Color
    let content: String
    let itemLanguage: AppLanguage
    let isAnswer: Bool
    let isExpanded: Bool
    let isPad: Bool

    private var bodyFontSize: CGFloat {
        isPad ? (isAnswer ? 16 : 17) : (isAnswer ? 15 : 16)
    }

    private var bodyFontWeight: Font.Weight {
        isAnswer ? .regular : .bold
    }

    private var bodyTextColor: Color {
        .DarkText.opacity(isAnswer ? 0.68 : 0.88)
    }

    private var bodyLineSpacing: CGFloat {
        isAnswer ? 4 : 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: isPad ? 14 : 12, weight: .bold))
                    .foregroundColor(color)

                Text(label)
                    .font(.system(size: isPad ? 15 : 13, weight: .heavy, design: .rounded))
                    .foregroundColor(color)
            }

            if isAnswer && itemLanguage == .japanese {
                FuriganaText(
                    content,
                    fontSize: bodyFontSize,
                    fontWeight: bodyFontWeight,
                    textColor: bodyTextColor,
                    lineSpacing: bodyLineSpacing
                )
                .lineLimit(isExpanded ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(content)
                    .font(.system(size: bodyFontSize, weight: bodyFontWeight, design: .rounded))
                    .foregroundColor(bodyTextColor)
                    .lineSpacing(bodyLineSpacing)
                    .lineLimit(isAnswer && !isExpanded ? 4 : nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(isPad ? 15 : 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(isAnswer ? 0.07 : 0.09), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct HistoryCopy {
    let language: AppLanguage

    var title: String {
        switch language {
        case .chinese:
            return "成長足跡"
        case .english:
            return "Growth Journey"
        case .japanese:
            return "成長記録"
        }
    }

    var heroTitle: String {
        switch language {
        case .chinese:
            return "今天學到了什麼？"
        case .english:
            return "What did we learn?"
        case .japanese:
            return "今日なにを学んだかな？"
        }
    }

    var heroSubtitle: String {
        switch language {
        case .chinese:
            return "每一次提問都會變成一張學習卡，方便孩子和家長一起回顧。"
        case .english:
            return "Every question becomes a learning card for kids and parents to revisit together."
        case .japanese:
            return "質問は学びカードになって、親子であとから見返せるよ。"
        }
    }

    var totalLabel: String {
        switch language {
        case .chinese:
            return "紀錄"
        case .english:
            return "Records"
        case .japanese:
            return "記録"
        }
    }

    var languageLabel: String {
        switch language {
        case .chinese:
            return "語言"
        case .english:
            return "Languages"
        case .japanese:
            return "言語"
        }
    }

    var latestLabel: String {
        switch language {
        case .chinese:
            return "最新"
        case .english:
            return "Latest"
        case .japanese:
            return "最新"
        }
    }

    var emptyTitle: String {
        switch language {
        case .chinese:
            return "還沒有學習足跡"
        case .english:
            return "No learning cards yet"
        case .japanese:
            return "まだ学びカードがないよ"
        }
    }

    var emptyMessage: String {
        switch language {
        case .chinese:
            return "去問安安老師一個問題，這裡就會開始保存孩子的好奇心。"
        case .english:
            return "Ask Teacher An-An a question, and the child's curiosity will start collecting here."
        case .japanese:
            return "あんあん先生に質問すると、ここに好奇心の記録がたまっていくよ。"
        }
    }

    var questionLabel: String {
        switch language {
        case .chinese:
            return "孩子的問題"
        case .english:
            return "Child's Question"
        case .japanese:
            return "子どもの質問"
        }
    }

    var answerLabel: String {
        switch language {
        case .chinese:
            return "安安老師的回答"
        case .english:
            return "Teacher An-An's Answer"
        case .japanese:
            return "あんあん先生の答え"
        }
    }

    var expandButton: String {
        switch language {
        case .chinese:
            return "展開回答"
        case .english:
            return "Read More"
        case .japanese:
            return "もっと見る"
        }
    }

    var collapseButton: String {
        switch language {
        case .chinese:
            return "收合"
        case .english:
            return "Collapse"
        case .japanese:
            return "閉じる"
        }
    }

    var savedLocally: String {
        switch language {
        case .chinese:
            return "僅儲存在本機"
        case .english:
            return "Stored on this device"
        case .japanese:
            return "この端末だけに保存"
        }
    }

    var clearButton: String {
        switch language {
        case .chinese:
            return "清空"
        case .english:
            return "Clear"
        case .japanese:
            return "削除"
        }
    }

    var clearConfirmTitle: String {
        switch language {
        case .chinese:
            return "清空所有歷史紀錄？"
        case .english:
            return "Clear all history?"
        case .japanese:
            return "すべての記録を消す？"
        }
    }

    var clearConfirmMessage: String {
        switch language {
        case .chinese:
            return "這會移除本機保存的學習卡，無法復原。"
        case .english:
            return "This removes the learning cards stored on this device and cannot be undone."
        case .japanese:
            return "この端末に保存された学びカードを消します。元には戻せません。"
        }
    }

    var clearConfirmAction: String {
        switch language {
        case .chinese:
            return "全部清空"
        case .english:
            return "Clear All"
        case .japanese:
            return "すべて削除"
        }
    }

    var cancelButton: String {
        switch language {
        case .chinese:
            return "取消"
        case .english:
            return "Cancel"
        case .japanese:
            return "キャンセル"
        }
    }

    var deleteButton: String {
        switch language {
        case .chinese:
            return "刪除這筆紀錄"
        case .english:
            return "Delete this record"
        case .japanese:
            return "この記録を削除"
        }
    }

    var localeIdentifier: String {
        switch language {
        case .chinese:
            return "zh_TW"
        case .english:
            return "en_US"
        case .japanese:
            return "ja_JP"
        }
    }
}

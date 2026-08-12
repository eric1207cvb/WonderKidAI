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

                                ParentGrowthDashboard(
                                    insights: ParentGrowthInsights(history: manager.history),
                                    text: text,
                                    isPad: isPad
                                )

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

// MARK: - Parent growth dashboard

private enum CuriosityTopic: CaseIterable, Identifiable {
    case nature, world, language, numbers

    var id: Self { self }

    func title(for language: AppLanguage) -> String {
        switch (self, language) {
        case (.nature, .chinese): return "自然"
        case (.world, .chinese): return "世界"
        case (.language, .chinese): return "語言"
        case (.numbers, .chinese): return "數字"
        case (.nature, .english): return "Nature"
        case (.world, .english): return "World"
        case (.language, .english): return "Language"
        case (.numbers, .english): return "Numbers"
        case (.nature, .japanese): return "自然"
        case (.world, .japanese): return "世界"
        case (.language, .japanese): return "ことば"
        case (.numbers, .japanese): return "数"
        }
    }

    var icon: String {
        switch self {
        case .nature: return "leaf.fill"
        case .world: return "globe.asia.australia.fill"
        case .language: return "text.book.closed.fill"
        case .numbers: return "number.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .nature: return .green
        case .world: return .MagicBlue
        case .language: return .purple
        case .numbers: return .ButtonOrange
        }
    }
}

private struct ParentGrowthInsights {
    let history: [HistoryItem]

    var recentWeek: [HistoryItem] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return history.filter { $0.date >= cutoff }
    }

    var recentQuestions: [HistoryItem] { Array(recentWeek.prefix(3)) }

    var topicCounts: [CuriosityTopic: Int] {
        var counts = Dictionary(uniqueKeysWithValues: CuriosityTopic.allCases.map { ($0, 0) })
        for item in recentWeek {
            counts[classify(item.question)]! += 1
        }
        return counts
    }

    var topTopics: [CuriosityTopic] {
        CuriosityTopic.allCases.sorted { topicCounts[$0, default: 0] > topicCounts[$1, default: 0] }
            .filter { topicCounts[$0, default: 0] > 0 }
    }

    var activeTopicCount: Int { topicCounts.values.filter { $0 > 0 }.count }

    var learningStreak: Int {
        let calendar = Calendar.current
        let days = Set(history.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        if !days.contains(cursor), let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) {
            cursor = yesterday
        }
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private func classify(_ question: String) -> CuriosityTopic {
        let value = question.lowercased()
        let match: (CuriosityTopic, [String]) -> Bool = { topic, words in
            words.contains { value.localizedCaseInsensitiveContains($0) }
        }
        if match(.numbers, ["數", "數字", "加", "減", "算", "number", "math", "count", "数字", "数", "計算"]) { return .numbers }
        if match(.language, ["字", "說", "語", "英文", "日文", "language", "word", "read", "文字", "言葉", "ことば", "漢字"]) { return .language }
        if match(.world, ["國", "城市", "地圖", "地球", "宇宙", "歷史", "world", "country", "space", "city", "日本", "世界", "宇宙", "地理", "歴史"]) { return .world }
        return .nature
    }
}

private struct ParentGrowthDashboard: View {
    let insights: ParentGrowthInsights
    let text: HistoryCopy
    let isPad: Bool

    var body: some View {
        VStack(spacing: isPad ? 16 : 12) {
            weeklySummary
            curiosityMap
            milestones
        }
    }

    private var weeklySummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(text.weeklySummaryTitle, systemImage: "calendar.badge.clock")
                .font(.system(size: isPad ? 18 : 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.MagicBlue)

            Text(text.weeklySummary(count: insights.recentWeek.count, topics: insights.topTopics.prefix(2).map { $0.title(for: text.language) }))
                .font(.system(size: isPad ? 17 : 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            if !insights.recentQuestions.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text(text.recentQuestionsTitle)
                        .font(.system(size: isPad ? 13 : 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    ForEach(insights.recentQuestions) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "quote.bubble.fill").foregroundStyle(Color.MagicBlue.opacity(0.72))
                            Text(item.question)
                                .font(.system(size: isPad ? 15 : 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(12)
                .background(Color.MagicBlue.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(isPad ? 18 : 15)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var curiosityMap: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(text.curiosityMapTitle, systemImage: "map.fill")
                .font(.system(size: isPad ? 18 : 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.purple)
            Text(text.curiosityMapSubtitle)
                .font(.system(size: isPad ? 14 : 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            ForEach(CuriosityTopic.allCases) { topic in
                let count = insights.topicCounts[topic, default: 0]
                HStack(spacing: 10) {
                    Image(systemName: topic.icon).foregroundStyle(topic.color).frame(width: 20)
                    Text(topic.title(for: text.language)).font(.system(size: isPad ? 15 : 14, weight: .bold, design: .rounded)).frame(width: isPad ? 82 : 66, alignment: .leading)
                    GeometryReader { geo in
                        Capsule().fill(topic.color.opacity(0.13))
                            .overlay(alignment: .leading) {
                                Capsule().fill(topic.color).frame(width: insights.recentWeek.isEmpty ? 0 : max(5, geo.size.width * CGFloat(count) / CGFloat(max(insights.recentWeek.count, 1))))
                            }
                    }
                    .frame(height: 9)
                    Text("\(count)").font(.system(size: isPad ? 14 : 13, weight: .heavy, design: .rounded)).foregroundStyle(.secondary).frame(width: 20)
                }
            }
        }
        .padding(isPad ? 18 : 15)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var milestones: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(text.milestoneTitle, systemImage: "medal.fill")
                .font(.system(size: isPad ? 18 : 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.ButtonOrange)
            ForEach(text.milestones(total: insights.history.count, streak: insights.learningStreak, topicCount: insights.activeTopicCount), id: \.title) { milestone in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: milestone.reached ? "checkmark.seal.fill" : "circle")
                        .foregroundStyle(milestone.reached ? Color.green : Color.secondary.opacity(0.42))
                        .font(.system(size: isPad ? 20 : 18, weight: .semibold))
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(milestone.title).font(.system(size: isPad ? 15 : 14, weight: .bold, design: .rounded))
                            Spacer(minLength: 6)
                            Text(milestone.progressLabel)
                                .font(.system(size: isPad ? 13 : 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(milestone.reached ? Color.green : Color.secondary)
                        }
                        Text(milestone.detail).font(.system(size: isPad ? 13 : 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                        GeometryReader { geo in
                            Capsule()
                                .fill(Color.secondary.opacity(0.13))
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(milestone.reached ? Color.green : Color.ButtonOrange)
                                        .frame(width: max(3, geo.size.width * milestone.progress))
                                }
                        }
                        .frame(height: isPad ? 7 : 6)
                        .padding(.top, 5)
                    }
                }
            }
        }
        .padding(isPad ? 18 : 15)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                isExpanded: isExpanded,
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

            if isAnswer && !isExpanded {
                Label(textPreviewLabel, systemImage: "text.justify")
                    .font(.system(size: isPad ? 14 : 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.opacity(0.78))
                    .padding(.vertical, isPad ? 3 : 1)
            } else if isAnswer && itemLanguage == .japanese {
                // The growth record is a parent-facing reading surface, not
                // the child's karaoke card. Present clean Japanese prose here
                // so ruby annotations do not spread every character apart.
                HistoryJapaneseAnswerText(
                    content: content,
                    isExpanded: isExpanded,
                    isPad: isPad
                )
            } else {
                Text(content)
                    .font(.system(size: bodyFontSize, weight: bodyFontWeight, design: .rounded))
                    .foregroundColor(bodyTextColor)
                    .lineSpacing(bodyLineSpacing)
                    .lineLimit(!isExpanded ? 2 : nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(isPad ? 15 : 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(isAnswer ? 0.07 : 0.09), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var textPreviewLabel: String {
        switch itemLanguage {
        case .chinese: return "點開查看老師的完整回答"
        case .english: return "Open to read Teacher An-An’s answer"
        case .japanese: return "開くと先生の答えが読めます"
        }
    }
}

/// Parent-friendly Japanese typography used only in the growth record.
/// The interactive learning screen retains its full ruby karaoke treatment.
private struct HistoryJapaneseAnswerText: View {
    let content: String
    let isExpanded: Bool
    let isPad: Bool

    private var readableContent: String {
        var text = content

        if let rubyRegex = try? NSRegularExpression(
            pattern: #"<ruby>(.*?)<rt>.*?</rt></ruby>"#,
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        ) {
            let range = NSRange(text.startIndex..., in: text)
            text = rubyRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1")
        }

        if let readingRegex = try? NSRegularExpression(
            pattern: #"[\(（][ぁ-んァ-ヴー\s]+[\)）]"#,
            options: []
        ) {
            let range = NSRange(text.startIndex..., in: text)
            text = readingRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }

        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Text(readableContent)
            .font(.system(size: isPad ? 18 : 17, weight: .regular, design: .rounded))
            .foregroundStyle(Color.primary.opacity(0.82))
            .lineSpacing(isPad ? 9 : 8)
            .lineLimit(isExpanded ? nil : 5)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }
}

private struct HistoryCopy {
    let language: AppLanguage

    struct Milestone: Hashable {
        let title: String
        let detail: String
        let current: Int
        let target: Int

        var reached: Bool { current >= target }
        var progress: CGFloat { min(1, CGFloat(current) / CGFloat(max(target, 1))) }
        var progressLabel: String { "\(min(current, target)) / \(target)" }
    }

    var weeklySummaryTitle: String {
        switch language {
        case .chinese: return "本週學習摘要"
        case .english: return "This Week’s Learning"
        case .japanese: return "今週の学び"
        }
    }

    var recentQuestionsTitle: String {
        switch language {
        case .chinese: return "孩子最近問的問題"
        case .english: return "Recent questions"
        case .japanese: return "最近の質問"
        }
    }

    var curiosityMapTitle: String {
        switch language {
        case .chinese: return "好奇心地圖"
        case .english: return "Curiosity Map"
        case .japanese: return "好奇心マップ"
        }
    }

    var curiosityMapSubtitle: String {
        switch language {
        case .chinese: return "依最近 7 天的提問整理；數字越高，代表探索越多。"
        case .english: return "Based on questions from the past 7 days. Higher counts mean more exploration."
        case .japanese: return "最近 7 日間の質問から整理しました。数字が多いほど、よく探究したテーマです。"
        }
    }

    var milestoneTitle: String {
        switch language {
        case .chinese: return "溫柔的成長里程碑"
        case .english: return "Gentle Growth Milestones"
        case .japanese: return "小さな成長のしるし"
        }
    }

    func weeklySummary(count: Int, topics: [String]) -> String {
        let topicText: String
        switch language {
        case .chinese: topicText = topics.isEmpty ? "還在慢慢發現喜歡的主題" : "最常探索「\(topics.joined(separator: "、"))」"
        case .english: topicText = topics.isEmpty ? "They are still discovering favorite topics" : "Most explored: \(topics.joined(separator: " and "))"
        case .japanese: topicText = topics.isEmpty ? "好きなテーマを、これから見つけていくところです" : "よく探究したテーマは「\(topics.joined(separator: "・"))」です"
        }

        switch language {
        case .chinese: return "這週一共探索了 \(count) 個問題，\(topicText)。"
        case .english: return "This week, your child explored \(count) questions. \(topicText)."
        case .japanese: return "今週は \(count) 個の質問を探究しました。\(topicText)"
        }
    }

    func milestones(total: Int, streak: Int, topicCount: Int) -> [Milestone] {
        switch language {
        case .chinese:
            return [
                .init(title: "好奇心起步", detail: total > 0 ? "已留下第一個問題" : "問出第一個問題就能解鎖", current: total, target: 1),
                .init(title: "持續探索", detail: streak >= 3 ? "已連續探索 \(streak) 天" : "連續探索 3 天即可達成", current: streak, target: 3),
                .init(title: "多元發現", detail: topicCount >= 3 ? "本週探索了 \(topicCount) 種主題" : "本週探索 3 種主題即可達成", current: topicCount, target: 3),
                .init(title: "小小研究家", detail: total >= 100 ? "已累積 \(total) 個問題" : "累積 100 個問題即可達成", current: total, target: 100)
            ]
        case .english:
            return [
                .init(title: "Curiosity Begins", detail: total > 0 ? "First question saved" : "Ask a first question to unlock", current: total, target: 1),
                .init(title: "Keep Exploring", detail: streak >= 3 ? "Explored for \(streak) days in a row" : "Explore for 3 days in a row", current: streak, target: 3),
                .init(title: "Many Discoveries", detail: topicCount >= 3 ? "Explored \(topicCount) topic areas this week" : "Explore 3 topic areas this week", current: topicCount, target: 3),
                .init(title: "Little Researcher", detail: total >= 100 ? "Collected \(total) questions" : "Collect 100 questions", current: total, target: 100)
            ]
        case .japanese:
            return [
                .init(title: "好奇心のはじまり", detail: total > 0 ? "はじめての質問を記録しました" : "はじめての質問で達成", current: total, target: 1),
                .init(title: "つづけて探究", detail: streak >= 3 ? "\(streak) 日つづけて探究しました" : "3 日つづけて探究すると達成", current: streak, target: 3),
                .init(title: "いろいろ発見", detail: topicCount >= 3 ? "今週は \(topicCount) 種類のテーマを探究しました" : "今週 3 種類のテーマを探究すると達成", current: topicCount, target: 3),
                .init(title: "小さな研究者", detail: total >= 100 ? "\(total) 個の質問を集めました" : "100 個の質問で達成", current: total, target: 100)
            ]
        }
    }

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

import SwiftUI
import Foundation

// 🇯🇵 日文振假名專用組件 - 讓平假名顯示在漢字正上方
struct FuriganaText: View {
    let text: String
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let textColor: Color
    
    init(_ text: String, fontSize: CGFloat = 18, fontWeight: Font.Weight = .regular, textColor: Color = .primary) {
        self.text = text
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.textColor = textColor
    }
    
    var body: some View {
        // 解析文字中的振假名格式：漢字(ひらがな)
        let normalizedText = normalizeRubyMarkup(text)
        let segments = parseFurigana(normalizedText)
        
        // 使用 HStack + VStack 組合來排列
        FlowLayout(spacing: 2) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                FuriganaSegmentView(
                    base: segment.base,
                    furigana: segment.furigana,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                    textColor: textColor
                )
            }
        }
    }
    
    // 解析振假名格式
    private func parseFurigana(_ text: String) -> [FuriganaSegment] {
        var segments: [FuriganaSegment] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            // 查找下一個 '(' 符號
            if let openParenIndex = text[currentIndex...].firstIndex(of: "(") {
                // 如果前面有文字，先加入沒有振假名的部分
                if currentIndex < openParenIndex {
                    let plainText = String(text[currentIndex..<openParenIndex])
                    // 把每個字符單獨處理（保持對齊）
                    for char in plainText {
                        segments.append(FuriganaSegment(base: String(char), furigana: nil))
                    }
                }
                
                // 查找對應的 ')' 符號
                if let closeParenIndex = text[openParenIndex...].firstIndex(of: ")") {
                    // 提取振假名
                    let furiganaStartIndex = text.index(after: openParenIndex)
                    let furigana = String(text[furiganaStartIndex..<closeParenIndex])
                    
                    // 提取基礎文字（在 '(' 之前的字符）
                    if openParenIndex > text.startIndex {
                        let baseEndIndex = openParenIndex
                        var baseStartIndex = baseEndIndex
                        
                        // 往前找到第一個非 CJK 字符或開頭
                        while baseStartIndex > currentIndex {
                            let prevIndex = text.index(before: baseStartIndex)
                            let char = text[prevIndex]
                            if let scalar = char.unicodeScalars.first,
                               (0x4E00...0x9FFF).contains(scalar.value) {
                                baseStartIndex = prevIndex
                            } else {
                                break
                            }
                        }
                        
                        // 移除最後加入的那些字符（因為它們有振假名）
                        let baseLength = text.distance(from: baseStartIndex, to: baseEndIndex)
                        if baseLength > 0 && segments.count >= baseLength {
                            segments.removeLast(baseLength)
                        }
                        
                        let base = String(text[baseStartIndex..<baseEndIndex])
                        segments.append(FuriganaSegment(base: base, furigana: furigana))
                    }
                    
                    currentIndex = text.index(after: closeParenIndex)
                } else {
                    // 沒有對應的 ')'，視為普通文字
                    segments.append(FuriganaSegment(base: String(text[currentIndex]), furigana: nil))
                    currentIndex = text.index(after: currentIndex)
                }
            } else {
                // 沒有更多振假名，剩餘全部視為普通文字
                let remainingText = String(text[currentIndex...])
                for char in remainingText {
                    segments.append(FuriganaSegment(base: String(char), furigana: nil))
                }
                break
            }
        }
        
        return segments
    }

    private func normalizeRubyMarkup(_ text: String) -> String {
        let pattern = "<ruby>(.*?)<rt>(.*?)</rt></ruby>"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        ) else {
            return text
        }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1($2)")
    }
}

// 振假名片段
struct FuriganaSegment {
    let base: String
    let furigana: String?
}

private struct FuriganaSegmentView: View {
    let base: String
    let furigana: String?
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let textColor: Color
    
    @State private var baseSize: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 0) {
            if let furigana = furigana, !furigana.isEmpty {
                Text(furigana)
                    .font(.system(size: fontSize * 0.5, weight: .regular))
                    .foregroundColor(textColor.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: max(baseSize.width, 1), alignment: .center)
            } else {
                Text(" ")
                    .font(.system(size: fontSize * 0.5, weight: .regular))
                    .opacity(0)
                    .frame(width: max(baseSize.width, 1), alignment: .center)
            }
            
            Text(base)
                .font(.system(size: fontSize, weight: fontWeight, design: .rounded))
                .foregroundColor(textColor)
                .background(FuriganaSizeReader())
        }
        .onPreferenceChange(FuriganaSizeKey.self) { size in
            if size != baseSize {
                baseSize = size
            }
        }
    }
}

private struct FuriganaSizeReader: View {
    var body: some View {
        GeometryReader { geo in
            Color.clear.preference(key: FuriganaSizeKey.self, value: geo.size)
        }
    }
}

private struct FuriganaSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// 自動換行的佈局（類似 FlowLayout）
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    // 換行
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

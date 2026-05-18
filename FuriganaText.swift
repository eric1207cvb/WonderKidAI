import SwiftUI
import Foundation

// 🇯🇵 日文振假名專用組件 - 讓平假名顯示在漢字正上方
struct FuriganaText: View {
    let text: String
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let textColor: Color
    let lineSpacing: CGFloat
    
    init(
        _ text: String,
        fontSize: CGFloat = 18,
        fontWeight: Font.Weight = .regular,
        textColor: Color = .primary,
        lineSpacing: CGFloat = 10
    ) {
        self.text = text
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.textColor = textColor
        self.lineSpacing = lineSpacing
    }
    
    var body: some View {
        let segments = parseSegments(text)
        
        FlowLayout(spacing: max(2, fontSize * 0.12), lineSpacing: lineSpacing) {
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
    
    private func parseSegments(_ text: String) -> [FuriganaSegment] {
        var segments: [FuriganaSegment] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            if let rubySegment = parseRubySegment(in: text, from: currentIndex) {
                segments.append(rubySegment.segment)
                currentIndex = rubySegment.nextIndex
                continue
            }

            if let nextRubyRange = text.range(of: "<ruby>", options: [.caseInsensitive], range: currentIndex..<text.endIndex) {
                let chunk = String(text[currentIndex..<nextRubyRange.lowerBound])
                segments.append(contentsOf: parseParentheticalSegments(chunk))
                currentIndex = nextRubyRange.lowerBound
            } else {
                let chunk = String(text[currentIndex..<text.endIndex])
                segments.append(contentsOf: parseParentheticalSegments(chunk))
                break
            }
        }
        
        return segments
    }

    private func parseRubySegment(
        in text: String,
        from index: String.Index
    ) -> (segment: FuriganaSegment, nextIndex: String.Index)? {
        guard let rubyOpen = text.range(
            of: "<ruby>",
            options: [.caseInsensitive, .anchored],
            range: index..<text.endIndex
        ) else {
            return nil
        }

        guard let rtOpen = text.range(
            of: "<rt>",
            options: [.caseInsensitive],
            range: rubyOpen.upperBound..<text.endIndex
        ), let rtClose = text.range(
            of: "</rt>",
            options: [.caseInsensitive],
            range: rtOpen.upperBound..<text.endIndex
        ), let rubyClose = text.range(
            of: "</ruby>",
            options: [.caseInsensitive],
            range: rtClose.upperBound..<text.endIndex
        ) else {
            return nil
        }

        let base = String(text[rubyOpen.upperBound..<rtOpen.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let furigana = String(text[rtOpen.upperBound..<rtClose.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return nil }

        let normalizedFurigana = furigana.replacingOccurrences(of: " ", with: "")
        let segment = FuriganaSegment(
            base: base,
            furigana: normalizedFurigana.isEmpty || normalizedFurigana == base ? nil : normalizedFurigana
        )
        return (segment, rubyClose.upperBound)
    }

    private func parseParentheticalSegments(_ text: String) -> [FuriganaSegment] {
        var segments: [FuriganaSegment] = []
        var currentIndex = text.startIndex

        while currentIndex < text.endIndex {
            guard let openParenIndex = nextRubyParen(in: text, from: currentIndex) else {
                appendPlainSegments(String(text[currentIndex...]), into: &segments)
                break
            }

            if currentIndex < openParenIndex {
                let plainText = String(text[currentIndex..<openParenIndex])
                appendPlainSegments(plainText, into: &segments)
            }

            guard let closeParenIndex = closingRubyParen(in: text, for: openParenIndex) else {
                appendPlainSegments(String(text[openParenIndex...]), into: &segments)
                break
            }

            let furiganaStartIndex = text.index(after: openParenIndex)
            let furigana = String(text[furiganaStartIndex..<closeParenIndex])
                .replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let baseStartIndex = baseStartIndex(for: text, openParenIndex: openParenIndex)
            let baseLength = text.distance(from: baseStartIndex, to: openParenIndex)

            if baseLength > 0 && !furigana.isEmpty && segments.count >= baseLength {
                segments.removeLast(baseLength)
                let base = String(text[baseStartIndex..<openParenIndex])
                segments.append(FuriganaSegment(base: base, furigana: furigana))
                currentIndex = text.index(after: closeParenIndex)
            } else {
                appendPlainSegments(String(text[openParenIndex...closeParenIndex]), into: &segments)
                currentIndex = text.index(after: closeParenIndex)
            }
        }

        return segments
    }

    private func appendPlainSegments(_ text: String, into segments: inout [FuriganaSegment]) {
        for char in text {
            segments.append(FuriganaSegment(base: String(char), furigana: nil))
        }
    }

    private func nextRubyParen(in text: String, from index: String.Index) -> String.Index? {
        var searchIndex = index
        while searchIndex < text.endIndex {
            let char = text[searchIndex]
            if char == "(" || char == "（" {
                return searchIndex
            }
            searchIndex = text.index(after: searchIndex)
        }
        return nil
    }

    private func closingRubyParen(in text: String, for openParenIndex: String.Index) -> String.Index? {
        let openChar = text[openParenIndex]
        let targetCloseChar: Character = openChar == "（" ? "）" : ")"
        var searchIndex = text.index(after: openParenIndex)
        while searchIndex < text.endIndex {
            if text[searchIndex] == targetCloseChar {
                return searchIndex
            }
            searchIndex = text.index(after: searchIndex)
        }
        return nil
    }

    private func baseStartIndex(for text: String, openParenIndex: String.Index) -> String.Index {
        guard openParenIndex > text.startIndex else { return openParenIndex }

        var candidateStart = openParenIndex
        var sawKanji = false

        while candidateStart > text.startIndex {
            let previousIndex = text.index(before: candidateStart)
            let character = text[previousIndex]

            guard isRubyBaseCharacter(character) else { break }
            if isKanji(character) {
                sawKanji = true
            }
            candidateStart = previousIndex
        }

        guard sawKanji else { return openParenIndex }

        if !isKanji(text[candidateStart]) {
            var adjustedStart = candidateStart
            while adjustedStart < openParenIndex {
                let currentChar = text[adjustedStart]
                if isKanji(currentChar) {
                    return adjustedStart
                }

                let nextIndex = text.index(after: adjustedStart)
                if (currentChar == "お" || currentChar == "ご"),
                   nextIndex < openParenIndex,
                   isKanji(text[nextIndex]) {
                    return adjustedStart
                }
                adjustedStart = nextIndex
            }
        }

        return candidateStart
    }

    private func isRubyBaseCharacter(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        let value = scalar.value

        let isKanjiRange = (0x3400...0x4DBF).contains(value) || (0x4E00...0x9FFF).contains(value)
        let isKanaRange = (0x3040...0x309F).contains(value) || (0x30A0...0x30FF).contains(value)
        let isJapaneseMark = "々〆ヵヶー".contains(character)

        return isKanjiRange || isKanaRange || isJapaneseMark
    }

    private func isKanji(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        let value = scalar.value
        return (0x3400...0x4DBF).contains(value) || (0x4E00...0x9FFF).contains(value) || character == "々"
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
    
    var body: some View {
        let rubyFontSize = max(10, fontSize * 0.5)
        let rubyHeight = rubyFontSize * 1.35
        let trimmedFurigana = furigana?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasRuby = !trimmedFurigana.isEmpty

        VStack(spacing: 0) {
            Text(hasRuby ? trimmedFurigana : " ")
                .font(.system(size: rubyFontSize, weight: .regular, design: .rounded))
                .foregroundColor(textColor.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .fixedSize(horizontal: true, vertical: false)
                .opacity(hasRuby ? 1 : 0)
                .frame(height: rubyHeight, alignment: .center)
            
            Text(base)
                .font(.system(size: fontSize, weight: fontWeight, design: .rounded))
                .foregroundColor(textColor)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minWidth: max(fontSize * 1.05, CGFloat(base.count) * fontSize * 0.92), alignment: .center)
    }
}

// 自動換行的佈局（類似 FlowLayout）
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat? = nil
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing,
            lineSpacing: lineSpacing ?? spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing, lineSpacing: lineSpacing ?? spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat, lineSpacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    // 換行
                    currentX = 0
                    currentY += lineHeight + lineSpacing
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

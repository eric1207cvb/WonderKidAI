import SwiftUI

public struct RubySegment {
    public let base: String
    public let ruby: String?
    public init(base: String, ruby: String? = nil) {
        self.base = base
        self.ruby = ruby
    }
}

public struct RubyTextStyle {
    public var baseFontSize: CGFloat
    public var rubyScale: CGFloat
    public var rubyBaselineOffset: CGFloat
    public var lineSpacing: CGFloat
    public var textColor: Color
    public var fontWeight: Font.Weight
    public var fontDesign: Font.Design
    
    public static let `default` = RubyTextStyle()
    
    public init(
        baseFontSize: CGFloat = 20,
        rubyScale: CGFloat = 0.6,
        rubyBaselineOffset: CGFloat = 10,
        lineSpacing: CGFloat = 4,
        textColor: Color = .primary,
        fontWeight: Font.Weight = .regular,
        fontDesign: Font.Design = .default
    ) {
        self.baseFontSize = baseFontSize
        self.rubyScale = rubyScale
        self.rubyBaselineOffset = rubyBaselineOffset
        self.lineSpacing = lineSpacing
        self.textColor = textColor
        self.fontWeight = fontWeight
        self.fontDesign = fontDesign
    }
    
    public var baseFont: Font {
        Font.system(size: baseFontSize, weight: fontWeight, design: fontDesign)
    }
    
    public var rubyFont: Font {
        Font.system(size: baseFontSize * rubyScale, weight: fontWeight, design: fontDesign)
    }
}

public struct RubyText: View {
    private let segments: [RubySegment]
    private let style: RubyTextStyle
    
    public init(_ segments: [RubySegment], style: RubyTextStyle = .default) {
        self.segments = segments
        self.style = style
    }
    
    public init(_ lightweightText: String, style: RubyTextStyle = .default) {
        self.segments = RubyText.parse(lightweightText)
        self.style = style
    }
    
    private static func parse(_ text: String) -> [RubySegment] {
        var segments: [RubySegment] = []
        var index = text.startIndex
        
        while index < text.endIndex {
            let baseStart = index
            var baseEnd = index
            var foundRuby = false
            
            while baseEnd < text.endIndex {
                if text[baseEnd] == "(" {
                    foundRuby = true
                    break
                }
                baseEnd = text.index(after: baseEnd)
            }
            
            if foundRuby {
                let base = String(text[baseStart..<baseEnd])
                let rubyStart = text.index(after: baseEnd)
                var rubyEnd = rubyStart
                var rubyValid = false
                
                while rubyEnd < text.endIndex {
                    if text[rubyEnd] == ")" {
                        rubyValid = true
                        break
                    }
                    rubyEnd = text.index(after: rubyEnd)
                }
                
                if rubyValid {
                    let ruby = String(text[rubyStart..<rubyEnd])
                    if !base.isEmpty {
                        segments.append(RubySegment(base: base, ruby: ruby))
                    }
                    index = text.index(after: rubyEnd)
                } else {
                    segments.append(RubySegment(base: String(text[index])))
                    index = text.index(after: index)
                }
            } else {
                if baseEnd > baseStart {
                    segments.append(RubySegment(base: String(text[baseStart..<baseEnd])))
                }
                index = baseEnd
            }
        }
        return segments
    }
    
    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()
        
        for segment in segments {
            if let ruby = segment.ruby, !ruby.isEmpty {
                var baseAttr = AttributedString(segment.base)
                baseAttr.font = style.baseFont
                baseAttr.foregroundColor = style.textColor
                result.append(baseAttr)
                
                var zwnj = AttributedString("\u{200C}")
                zwnj.font = style.rubyFont
                result.append(zwnj)
                
                var rubyAttr = AttributedString(ruby)
                rubyAttr.font = style.rubyFont
                rubyAttr.foregroundColor = style.textColor
                rubyAttr.baselineOffset = style.rubyBaselineOffset
                result.append(rubyAttr)
            } else {
                var baseAttr = AttributedString(segment.base)
                baseAttr.font = style.baseFont
                baseAttr.foregroundColor = style.textColor
                result.append(baseAttr)
            }
        }
        return result
    }
    
    public var body: some View {
        Text(buildAttributedString())
            .lineSpacing(style.lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
    }
}

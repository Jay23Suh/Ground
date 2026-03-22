import SwiftUI

// MARK: - Slide definitions

enum AbstractSlideType {
    case title
    case count(bg: Color, accent: Color, value: Int, label: String, context: String)
    case text(bg: Color, accent: Color, headline: String, subtext: String)
    case quote(bg: Color, accent: Color, quote: String, context: String)
    case wordCloud(bg: Color, words: [(word: String, rank: Int)])
    case closing(message: String)
}

struct AbstractSlide: Identifiable {
    let id = UUID()
    let type: AbstractSlideType
}

// MARK: - Main view

struct AbstractView: View {
    let entries: [Entry]
    var onClose: (() -> Void)? = nil
    @State private var current = 0

    private var stats: ReflectStats { ReflectStats(entries: entries) }
    private var slides: [AbstractSlide] { buildSlides() }

    var body: some View {
        ZStack {
            Color(hex: "#110d07").ignoresSafeArea()

            // Slide content — tap to advance
            ForEach(Array(slides.enumerated()), id: \.offset) { i, slide in
                AbstractSlideView(slide: slide, visible: current == i)
            }
            .contentShape(Rectangle())
            .onTapGesture { advance() }

            // Close button
            if let close = onClose {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: close) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.4))
                                .padding(8)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .padding(20)
                    }
                    Spacer()
                }
            }

            // Left / right arrows
            HStack {
                Button {
                    if current > 0 {
                        withAnimation(.easeInOut(duration: 0.55)) { current -= 1 }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.white.opacity(current > 0 ? 0.4 : 0.1))
                        .padding(12)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .padding(.leading, 20)
                .disabled(current == 0)

                Spacer()

                Button {
                    advance()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.white.opacity(current < slides.count - 1 ? 0.4 : 0.1))
                        .padding(12)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .disabled(current == slides.count - 1)
            }
            .frame(maxHeight: .infinity)

            // Dots
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<slides.count, id: \.self) { i in
                        Button {
                            withAnimation(.easeInOut(duration: 0.55)) { current = i }
                        } label: {
                            Capsule()
                                .fill(i == current ? Color(hex: "#f0c060") : Color.white.opacity(0.2))
                                .frame(width: i == current ? 20 : 6, height: 6)
                                .animation(.spring(duration: 0.35), value: current)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onKeyPress(.space)      { advance(); return .handled }
        .onKeyPress(.rightArrow) { advance(); return .handled }
        .onKeyPress(.leftArrow)  { if current > 0 { withAnimation(.easeInOut(duration: 0.55)) { current -= 1 } }; return .handled }
    }

    private func advance() {
        if current < slides.count - 1 {
            withAnimation(.easeInOut(duration: 0.55)) { current += 1 }
        }
    }

    private func formatHour(_ h: Int) -> String {
        if h == 0  { return "midnight" }
        if h == 12 { return "noon" }
        return h < 12 ? "\(h)am" : "\(h - 12)pm"
    }

    private let categoryLabels: [String: String] = [
        "gratitude":  "Gratitude",
        "compassion": "Self-Compassion",
        "values":     "Values & Meaning",
        "emotions":   "Emotions",
        "grounding":  "Present Moment",
    ]
    private let categorySubtexts: [String: String] = [
        "gratitude":  "you kept returning to what you already have.",
        "compassion": "you were learning to be kinder to yourself.",
        "values":     "you were asking what actually matters.",
        "emotions":   "you were letting yourself feel it.",
        "grounding":  "you were finding your way back to now.",
    ]

    private func buildSlides() -> [AbstractSlide] {
        var s: [AbstractSlide] = [.init(type: .title)]

        s.append(.init(type: .count(
            bg: Color(hex: "#1e0e05"), accent: Color(hex: "#ff8c42"),
            value: stats.totalEntries, label: "entries",
            context: stats.totalEntries == 1 ? "you showed up." : "you kept showing up."
        )))

        s.append(.init(type: .count(
            bg: Color(hex: "#071a0f"), accent: Color(hex: "#5edb97"),
            value: stats.totalWords, label: "words written",
            context: "every one of them mattered."
        )))

        if stats.avgWords > 0 {
            s.append(.init(type: .count(
                bg: Color(hex: "#0f0a1e"), accent: Color(hex: "#b088ff"),
                value: stats.avgWords, label: "words on average",
                context: "per entry — just enough to be honest."
            )))
        }

        if let day = stats.mostActiveDay {
            let sub = stats.mostActiveHour.map { "usually around \(formatHour($0))" }
                ?? "whenever the moment felt right."
            s.append(.init(type: .text(
                bg: Color(hex: "#071618"), accent: Color(hex: "#60d4e8"),
                headline: "you wrote most on \(day)s",
                subtext: sub
            )))
        }

        if stats.longestStreak > 1 {
            s.append(.init(type: .count(
                bg: Color(hex: "#181205"), accent: Color(hex: "#ffc840"),
                value: stats.longestStreak, label: "day streak",
                context: "consistency is a form of care."
            )))
        }

        if let cat = stats.topCategory {
            s.append(.init(type: .text(
                bg: Color(hex: "#0d0a1a"), accent: Color(hex: "#C39BD3"),
                headline: categoryLabels[cat] ?? cat,
                subtext: categorySubtexts[cat] ?? "the theme you kept coming back to."
            )))
        }

        if stats.totalSkips > 0 {
            let msg = stats.skipRate >= 0.5
                ? "it's okay — but make some time for yourself to reflect."
                : "you showed up most of the time. that matters."
            s.append(.init(type: .text(
                bg: Color(hex: "#100a18"), accent: Color(hex: "#FFA6C9"),
                headline: "\(stats.totalSkips) skipped",
                subtext: msg
            )))
        }

        // Most used word + word cloud
        let topWords = computeTopWords()
        if let topWord = topWords.first {
            s.append(.init(type: .text(
                bg: Color(hex: "#0a0510"),
                accent: Color(hex: "#C39BD3"),
                headline: topWord,
                subtext: "your most used word"
            )))
        }
        if topWords.count >= 3 {
            s.append(.init(type: .wordCloud(
                bg: Color(hex: "#08080f"),
                words: topWords.prefix(7).enumerated().map { (word: $0.element, rank: $0.offset) }
            )))
        }

        // Pull quote from longest entry
        if let longest = entries.filter({ !$0.skipped }).max(by: { $0.wordCount < $1.wordCount }),
           longest.wordCount > 10,
           let quote = extractFirstSentence(longest.answer ?? "") {
            s.append(.init(type: .quote(
                bg: Color(hex: "#050d12"),
                accent: Color(hex: "#60d4e8"),
                quote: quote,
                context: "from your longest entry"
            )))
        }

        s.append(.init(type: .closing(message: closingMessage())))
        return s
    }

    private func extractFirstSentence(_ text: String) -> String? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > 15 else { return nil }
        let enders = CharacterSet(charactersIn: ".!?")
        if let range = cleaned.rangeOfCharacter(from: enders), range.lowerBound > cleaned.startIndex {
            let sentence = String(cleaned[..<range.upperBound])
            if sentence.count > 15 { return sentence }
        }
        return cleaned.count > 120 ? String(cleaned.prefix(120)) + "…" : cleaned
    }

    private func computeTopWords() -> [String] {
        let stopWords: Set<String> = [
            "i","me","my","we","our","you","your","he","him","his","she","her","it","its",
            "they","them","their","what","which","who","this","that","these","those",
            "am","is","are","was","were","be","been","being","have","has","had","do","does",
            "did","a","an","the","and","but","if","or","as","of","at","by","for","with",
            "about","into","through","before","after","to","from","up","down","in","out",
            "on","off","so","than","just","not","no","nor","all","both","more","most",
            "other","some","when","where","how","will","can","could","would","should",
            "now","then","here","there","very","also","too","only","even","still",
            "really","like","feel","felt","get","got","think","know","want","need",
            "make","made","today","one","two","time","day","days","thing","things","little",
            "lot","much","many","back","well","way","see","going","something","anything",
            "d","ll","m","re","s","t","ve","didn","don","won","isn","wasn","can't","i'm",
            "i've","i'd","it's","that's","been","actually","always","never","ever",
        ]
        var freq: [String: Int] = [:]
        for entry in entries where !entry.skipped {
            guard let text = entry.answer else { continue }
            let words = text.lowercased()
                .components(separatedBy: .init(charactersIn: " \n\t.,!?;:\"'()-"))
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { $0.count > 3 && !stopWords.contains($0) }
            for word in words { freq[word, default: 0] += 1 }
        }
        return freq.filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(8)
            .map(\.key)
    }

    private func closingMessage() -> String {
        if stats.longestStreak >= 7 {
            return "consistency is\na form of love ✦"
        }
        switch stats.topCategory {
        case "gratitude":   return "you already have\nenough ✦"
        case "compassion":  return "be gentle\nwith yourself ✦"
        case "values":      return "keep asking what\nmatters ✦"
        case "emotions":    return "feeling is\nalso healing ✦"
        case "grounding":   return "the present\nis enough ✦"
        default:            return "keep showing up\nfor yourself ✦"
        }
    }
}

// MARK: - Slide view

struct AbstractSlideView: View {
    let slide: AbstractSlide
    let visible: Bool
    @State private var appeared = false
    @State private var countVal: Double = 0

    var body: some View {
        Group {
            switch slide.type {
            case .title:
                TitleSlideView(visible: visible, appeared: appeared)
            case let .count(bg, accent, value, label, context):
                CountSlideView(visible: visible, appeared: appeared,
                               bg: bg, accent: accent,
                               value: value, label: label, context: context,
                               countVal: countVal)
            case let .text(bg, accent, headline, subtext):
                TextSlideView(visible: visible, appeared: appeared,
                              bg: bg, accent: accent,
                              headline: headline, subtext: subtext)
            case let .quote(bg, accent, quote, context):
                QuoteSlideView(visible: visible, appeared: appeared,
                               bg: bg, accent: accent,
                               quote: quote, context: context)
            case let .wordCloud(bg, words):
                WordCloudSlideView(visible: visible, appeared: appeared,
                                   bg: bg, words: words)
            case let .closing(message):
                ClosingSlideView(visible: visible, appeared: appeared, message: message)
            }
        }
        .overlay(NoiseOverlay())
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 32)
        .animation(.easeInOut(duration: 0.55), value: visible)
        .onChange(of: visible) { _, isVisible in
            if isVisible {
                appeared = false
                countVal = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    appeared = true
                    if case let .count(_, _, value, _, _) = slide.type {
                        withAnimation(.easeOut(duration: 1.4).delay(0.2)) {
                            countVal = Double(value)
                        }
                    }
                }
            }
        }
        .onAppear {
            if visible {
                appeared = true
                if case let .count(_, _, value, _, _) = slide.type {
                    withAnimation(.easeOut(duration: 1.4).delay(0.2)) {
                        countVal = Double(value)
                    }
                }
            }
        }
    }
}

// MARK: - Individual slide types

struct TitleSlideView: View {
    let visible: Bool
    let appeared: Bool
    var body: some View {
        ZStack { Color(hex: "#110d07").ignoresSafeArea()
            VStack(spacing: 0) {
                Text("your week in journaling")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .tracking(5).textCase(.uppercase)
                    .foregroundColor(Color(hex: "#f0c060").opacity(0.4))
                    .padding(.bottom, 28)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)
                Text("Abstract ✦")
                    .font(RFont.header(72))
                    .foregroundColor(Color(hex: "#f0c060"))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: appeared)
                Text("tap or press → to begin")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .tracking(3).textCase(.uppercase)
                    .foregroundColor(Color.white.opacity(0.25))
                    .padding(.top, 48)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CountSlideView: View {
    let visible: Bool
    let appeared: Bool
    let bg: Color
    let accent: Color
    let value: Int
    let label: String
    let context: String
    let countVal: Double

    var body: some View {
        ZStack { bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .tracking(5).textCase(.uppercase)
                    .foregroundColor(accent.opacity(0.55))
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)
                Text("\(Int(countVal))")
                    .font(RFont.header(108))
                    .foregroundColor(accent)
                    .contentTransition(.numericText())
                    .padding(.bottom, 28)
                Text(context)
                    .font(RFont.header(18, italic: true))
                    .foregroundColor(Color.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TextSlideView: View {
    let visible: Bool
    let appeared: Bool
    let bg: Color
    let accent: Color
    let headline: String
    let subtext: String

    var body: some View {
        ZStack { bg.ignoresSafeArea()
            VStack(spacing: 28) {
                TypewriterText(text: headline,
                               font: RFont.header(44),
                               color: accent,
                               trigger: appeared,
                               delay: 0.15,
                               speed: min(0.04, 1.8 / Double(max(1, headline.count))))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
                Text(subtext)
                    .font(RFont.header(18, italic: true))
                    .foregroundColor(Color.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: appeared)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct QuoteSlideView: View {
    let visible: Bool
    let appeared: Bool
    let bg: Color
    let accent: Color
    let quote: String
    let context: String

    var body: some View {
        ZStack { bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Text("\u{201C}")
                    .font(RFont.header(96))
                    .foregroundColor(accent.opacity(0.25))
                    .padding(.bottom, -32)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.05), value: appeared)

                TypewriterText(text: quote,
                               font: RFont.header(24, italic: true),
                               color: Color.white.opacity(0.88),
                               trigger: appeared,
                               delay: 0.2,
                               speed: min(0.025, 2.5 / Double(max(1, quote.count))))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 52)

                Text(context)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundColor(accent.opacity(0.4))
                    .padding(.top, 28)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.8), value: appeared)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ClosingSlideView: View {
    let visible: Bool
    let appeared: Bool
    let message: String

    var body: some View {
        ZStack { Color(hex: "#110d07").ignoresSafeArea()
            VStack(spacing: 0) {
                Text("until next time")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .tracking(5).textCase(.uppercase)
                    .foregroundColor(Color(hex: "#f0c060").opacity(0.35))
                    .padding(.bottom, 28)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)
                Text(message)
                    .font(RFont.header(48))
                    .foregroundColor(Color(hex: "#f0c060"))
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: appeared)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Word Cloud Slide

struct WordCloudSlideView: View {
    let visible: Bool
    let appeared: Bool
    let bg: Color
    let words: [(word: String, rank: Int)]

    // Fixed scatter layout: (dx, dy, rotation degrees, size)
    private let layout: [(CGFloat, CGFloat, Double, CGFloat)] = [
        (  0,   0,   0, 52),   // center — largest
        (-95, -44,  -4, 32),
        ( 88, -38,   3, 28),
        (-75,  52,  -2, 26),
        ( 80,  56,   5, 24),
        (  6, -88,  -3, 21),
        (-28,  88,   2, 19),
    ]

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            Text("your words")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .tracking(4).textCase(.uppercase)
                .foregroundColor(Color.white.opacity(0.15))
                .offset(y: -140)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.05), value: appeared)

            ZStack {
                ForEach(Array(words.prefix(7).enumerated()), id: \.offset) { i, item in
                    let (dx, dy, rot, size) = layout[i]
                    let opacity = i == 0 ? 0.92 : max(0.3, 0.75 - Double(i) * 0.08)
                    Text(item.word)
                        .font(RFont.header(size))
                        .foregroundColor(Color.white.opacity(opacity))
                        .rotationEffect(.degrees(rot))
                        .offset(x: dx, y: dy)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.45).delay(0.1 + Double(i) * 0.11), value: appeared)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Noise Overlay

struct NoiseOverlay: View {
    // Deterministic pseudo-random positions — never flickers
    private static let positions: [(CGFloat, CGFloat, CGFloat)] = {
        var pts: [(CGFloat, CGFloat, CGFloat)] = []
        var seed: UInt64 = 0xdeadbeef
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 33) / CGFloat(0x7FFFFFFF)
        }
        for _ in 0..<280 {
            pts.append((next(), next(), next()))   // x, y, size
        }
        return pts
    }()

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                for (nx, ny, ns) in NoiseOverlay.positions {
                    let r = CGRect(x: nx * size.width, y: ny * size.height,
                                   width: 1.0 + ns * 0.8, height: 1.0 + ns * 0.8)
                    ctx.fill(Path(ellipseIn: r), with: .color(.white.opacity(0.028 + Double(ns) * 0.018)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Typewriter Text

struct TypewriterText: View {
    let text: String
    let font: Font
    let color: Color
    let trigger: Bool
    var delay: Double = 0
    var speed: Double = 0.03

    @State private var displayed = ""

    var body: some View {
        Text(displayed)
            .font(font)
            .foregroundColor(color)
            .onChange(of: trigger) { _, isActive in
                if isActive { startAnimation() } else { displayed = "" }
            }
            .onAppear { if trigger { startAnimation() } }
    }

    private func startAnimation() {
        displayed = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            for (i, char) in text.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * speed) {
                    displayed.append(char)
                }
            }
        }
    }
}

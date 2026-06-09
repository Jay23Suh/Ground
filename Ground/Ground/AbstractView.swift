import SwiftUI

// MARK: - Slide definitions

enum AbstractSlideType {
    case title
    case count(bg: Color, accent: Color, value: Int, label: String, context: String)
    case text(bg: Color, accent: Color, headline: String, subtext: String)
    case quote(bg: Color, accent: Color, quote: String, context: String)
    case wordCloud(bg: Color, words: [(word: String, rank: Int)])
    case mood(score: Double, trend: String?)
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
    @State private var sentimentScores: [UUID: Double] = [:]
    @State private var slides: [AbstractSlide] = []

    var body: some View {
        ZStack {
            Color(hex: "#1c1610").ignoresSafeArea()

            // Only render current + immediate neighbors to avoid simultaneous transitions
            ForEach(Array(slides.enumerated()), id: \.offset) { i, slide in
                if abs(i - current) <= 1 {
                    AbstractSlideView(slide: slide, visible: current == i)
                }
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
                        withAnimation(.easeInOut(duration: 0.47)) { current -= 1 }
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
                            withAnimation(.easeInOut(duration: 0.47)) { current = i }
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
        .task(id: entries.map(\.id).hashValue) {
            let scores = await Entry.computeSentiment(for: entries)
            let stats = GroundStats(entries: entries, sentimentScores: scores)
            let topWords = await Task.detached(priority: .userInitiated) { [entries] in
                AbstractView.computeTopWords(entries: entries)
            }.value
            sentimentScores = scores
            slides = buildSlides(stats: stats, sentimentScores: scores, topWords: topWords)
        }
        .onKeyPress(.space)      { advance(); return .handled }
        .onKeyPress(.rightArrow) { advance(); return .handled }
        .onKeyPress(.leftArrow)  { if current > 0 { withAnimation(.easeInOut(duration: 0.47)) { current -= 1 } }; return .handled }
    }

    private func advance() {
        if current < slides.count - 1 {
            withAnimation(.easeInOut(duration: 0.47)) { current += 1 }
        }
    }

    private let categoryLabels: [String: String] = [
        "gratitude":  "Gratitude",
        "compassion": "Self-Compassion",
        "values":     "Values & Meaning",
        "emotions":   "Emotions",
        "grounding":  "Present Moment",
        "horizon":    "Growth & Goals",
        "community":  "Connection",
    ]
    private let categorySubtexts: [String: String] = [
        "gratitude":  "you kept returning to what you already have.",
        "compassion": "you were learning to be kinder to yourself.",
        "values":     "you were asking what actually matters.",
        "emotions":   "you were letting yourself feel it.",
        "grounding":  "you were finding your way back to now.",
        "horizon":    "you kept looking forward.",
        "community":  "you were reaching out.",
    ]

    private func buildSlides(stats: GroundStats, sentimentScores: [UUID: Double] = [:], topWords: [String] = []) -> [AbstractSlide] {
        var s: [AbstractSlide] = [.init(type: .title)]

        // 1. Entries
        s.append(.init(type: .count(
            bg: Color(hex: "#271610"), accent: Color(hex: "#ff8c42"),
            value: stats.totalEntries, label: "entries",
            context: stats.totalEntries == 1 ? "you showed up." : "you kept showing up."
        )))

        // 2. Words
        s.append(.init(type: .count(
            bg: Color(hex: "#0f2418"), accent: Color(hex: "#5edb97"),
            value: stats.totalWords, label: "words written",
            context: "every one of them mattered."
        )))

        // 3. Streak
        if stats.longestStreak > 1 {
            s.append(.init(type: .count(
                bg: Color(hex: "#22190a"), accent: Color(hex: "#ffc840"),
                value: stats.longestStreak, label: "day streak",
                context: "consistency is a form of care."
            )))
        }

        // 4. Top category
        if let cat = stats.topCategory {
            s.append(.init(type: .text(
                bg: Color(hex: "#171322"), accent: Color(hex: "#C39BD3"),
                headline: categoryLabels[cat] ?? cat,
                subtext: categorySubtexts[cat] ?? "the theme you kept coming back to."
            )))
        }

        // 5. Most active day/time
        if let day = stats.mostActiveDay {
            let sub = stats.mostActiveHour.map { "usually around \(hourLabel($0))" }
                ?? "whenever the moment felt right."
            s.append(.init(type: .text(
                bg: Color(hex: "#101f22"), accent: Color(hex: "#60d4e8"),
                headline: "you wrote most on \(day)s",
                subtext: sub
            )))
        }

        // 6. Word cloud
        if topWords.count >= 3 {
            s.append(.init(type: .wordCloud(
                bg: Color(hex: "#121218"),
                words: topWords.prefix(12).enumerated().map { (word: $0.element, rank: $0.offset) }
            )))
        }

        // 7. Pull quote — longest entry
        let answered = entries.filter { !$0.skipped }
        if let longest = answered.max(by: { $0.wordCount < $1.wordCount }),
           longest.wordCount > 10,
           let quote = extractFirstSentence(longest.answer ?? "") {
            s.append(.init(type: .quote(
                bg: Color(hex: "#0e161c"),
                accent: Color(hex: "#60d4e8"),
                quote: quote,
                context: "from your longest entry"
            )))
        }

        // 8. Pull quote — highest sentiment entry (if different from longest)
        let longestId = answered.max(by: { $0.wordCount < $1.wordCount })?.id
        if let highestEntry = answered
            .compactMap({ e -> (Entry, Double)? in
                guard let score = sentimentScores[e.id] else { return nil }
                return (e, score)
            })
            .max(by: { $0.1 < $1.1 })?.0,
           highestEntry.id != longestId,
           let quote = extractFirstSentence(highestEntry.answer ?? "") {
            s.append(.init(type: .quote(
                bg: Color(hex: "#0e1411"),
                accent: Color(hex: "#5edb97"),
                quote: quote,
                context: "from your most uplifting entry"
            )))
        }

        // 9. Mood
        if let avg = stats.avgMoodDelta {
            s.append(.init(type: .mood(score: avg, trend: stats.moodTrendDirection)))
        }

        // 10. Skips — near the end, gentle
        if stats.totalSkips > 0 {
            let msg = stats.skipRate >= 0.5
                ? "it's okay — but make some time for yourself to ground."
                : "you showed up most of the time. that matters."
            s.append(.init(type: .text(
                bg: Color(hex: "#1a1222"), accent: Color(hex: "#FFA6C9"),
                headline: "\(stats.totalSkips) skipped",
                subtext: msg
            )))
        }

        // 11. Closing
        s.append(.init(type: .closing(message: closingMessage(stats: stats))))
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

    private static func computeTopWords(entries: [Entry]) -> [String] {
        let stopWords: Set<String> = [
            // pronouns
            "i","me","my","myself","we","our","ours","ourselves","you","your","yours",
            "yourself","he","him","his","himself","she","her","hers","herself",
            "it","its","itself","they","them","their","theirs","themselves",
            "what","which","who","whom","this","that","these","those",
            // verbs
            "am","is","are","was","were","be","been","being",
            "have","has","had","having","do","does","did","doing",
            "will","would","could","should","shall","may","might","must",
            "can","need","dare","used","ought",
            "get","got","gets","getting","gotten",
            "feel","felt","feels","feeling",
            "think","thought","thinks","thinking",
            "know","knew","knows","knowing",
            "want","wanted","wants","wanting",
            "make","made","makes","making",
            "see","saw","seen","seeing",
            "come","came","comes","coming",
            "go","went","gone","going","goes",
            "take","took","taken","taking",
            "keep","kept","keeps","keeping",
            "tell","told","tells","telling",
            "give","gave","given","gives","giving",
            "find","found","finds","finding",
            "help","helped","helps","helping",
            "work","worked","works","working",
            "look","looked","looks","looking",
            "turn","turned","turns","turning",
            "seem","seemed","seems","seeming",
            "show","showed","shown","shows","showing",
            "move","moved","moves","moving",
            "live","lived","lives","living",
            "try","tried","tries","trying",
            "ask","asked","asks","asking",
            "mean","meant","means","meaning",
            "let","lets","letting",
            "put","puts","putting",
            "say","said","says","saying",
            "call","called","calls","calling",
            "become","became","becomes","becoming",
            "leave","left","leaves","leaving",
            "start","started","starts","starting",
            "end","ended","ends","ending",
            "stop","stopped","stops","stopping",
            "bring","brought","brings","bringing",
            "set","sets","setting",
            "talk","talked","talks","talking",
            // articles / prepositions / conjunctions
            "a","an","the","and","but","if","or","nor","as","of","at","by","for",
            "with","about","into","through","before","after","to","from","up","down",
            "in","out","on","off","over","under","again","further","once","than",
            "so","yet","both","either","neither","whether","while","since","until",
            "because","though","although","unless","however","therefore","thus",
            "hence","thereby","whereby","whereas","meanwhile","nevertheless",
            // adverbs / filler
            "not","no","nor","never","ever","just","only","even","still","really",
            "very","also","too","quite","rather","almost","already","always","often",
            "sometimes","usually","mostly","generally","actually","basically","literally",
            "honestly","probably","maybe","perhaps","anyway","somehow","somewhere",
            "together","around","every","each","now","then","here","there","when",
            "where","why","how","more","most","other","some","such","same","own",
            "another","enough","else","back","well","away","around","across","along",
            // quantifiers / numbers
            "all","both","few","many","much","more","most","lot","lots","little","less",
            "one","two","three","four","five","six","several","any","every","each",
            // time words
            "today","yesterday","tomorrow","tonight","morning","evening","night",
            "week","month","year","day","days","time","times","moment","while",
            // contractions / fragments
            "d","ll","m","re","s","t","ve",
            "didn","don","won","isn","wasn","aren","weren","hasn","haven","hadn",
            "couldn","wouldn","shouldn","doesn","mustn","mightn","needn","oughtn",
            // common journaling filler
            "thing","things","something","anything","everything","nothing","someone",
            "anyone","everyone","kind","right","good","great","really","just","like",
            "next","last","long","new","old","big","small","own","sure","true","false",
            "okay","ok","yeah","yes","bit","lot","way","place","point","part","side",
        ]
        var freq: [String: Int] = [:]
        for entry in entries where !entry.skipped {
            guard let text = entry.answer else { continue }
            let words = text.lowercased()
                .replacingOccurrences(of: "\u{2019}", with: "'")
                .replacingOccurrences(of: "\u{2018}", with: "'")
                .components(separatedBy: .init(charactersIn: " \n\t.,!?;:\"'()-"))
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { $0.count > 4 && !stopWords.contains($0) }
            for word in words { freq[word, default: 0] += 1 }
        }
        return freq.filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(12)
            .map(\.key)
    }

    private func closingMessage(stats: GroundStats) -> String {
        // Personal data-driven closing — use real numbers
        if let cat = stats.topCategory {
            let catWords = entries
                .filter { !$0.skipped && $0.category == cat }
                .reduce(0) { $0 + $1.wordCount }
            let label = (categoryLabels[cat] ?? cat).lowercased()
            if catWords > 30 {
                return "you wrote \(catWords) words\nabout \(label) ✦"
            }
        }
        if stats.longestStreak >= 7 {
            return "you showed up\n\(stats.longestStreak) days in a row ✦"
        }
        if stats.totalEntries >= 10 {
            return "\(stats.totalEntries) entries.\nthat's not nothing ✦"
        }
        return "keep showing up\nfor yourself ✦"
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
            case let .mood(score, trend):
                MoodSlideView(visible: visible, appeared: appeared, score: score, trend: trend)
            case let .closing(message):
                ClosingSlideView(visible: visible, appeared: appeared, message: message)
            }
        }
        .overlay(NoiseOverlay())
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 32)
        .animation(.easeInOut(duration: 0.47), value: visible)
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
        ZStack { Color(hex: "#1c1610").ignoresSafeArea()
            VStack(spacing: 0) {
                Text("your journey in journaling")
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
                    .font(RFont.header(20, italic: true))
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
        ZStack {
            // Dark base — slightly warmer than other slides
            Color(hex: "#16110c").ignoresSafeArea()

            // App pastels bleeding in from the corners — signals return to the light
            RadialGradient(colors: [Color(hex: "#FFA6C9").opacity(0.13), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 320)
                .ignoresSafeArea()
            RadialGradient(colors: [Color(hex: "#76D7C4").opacity(0.10), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 300)
                .ignoresSafeArea()
            RadialGradient(colors: [Color(hex: "#C39BD3").opacity(0.09), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 280)
                .ignoresSafeArea()

            // Central gold glow — the landing moment
            RadialGradient(colors: [Color(hex: "#f0c060").opacity(0.14), .clear],
                           center: .center, startRadius: 0, endRadius: 220)
                .ignoresSafeArea()

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
        (   0,    0,   0, 56),   // center — largest
        (-140,  -60,  -5, 36),
        ( 140,  -50,   4, 32),
        (-120,   80,  -3, 28),
        ( 130,   85,   6, 26),
        (   8, -130,  -4, 24),
        ( -50,  140,   3, 22),
        ( 170,   10,  -2, 20),
        (-170,   10,   5, 19),
        (  60, -155,   3, 18),
        ( -90,  -145, -3, 17),
        ( 110,  150,  -4, 16),
    ]

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            Text("your words")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .tracking(4).textCase(.uppercase)
                .foregroundColor(Color.white.opacity(0.15))
                .offset(y: -200)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.05), value: appeared)

            ZStack {
                ForEach(Array(words.prefix(layout.count).enumerated()), id: \.offset) { i, item in
                    let (dx, dy, rot, size) = layout[i]
                    let opacity = i == 0 ? 0.92 : max(0.25, 0.78 - Double(i) * 0.06)
                    Text(item.word)
                        .font(RFont.header(size))
                        .foregroundColor(Color.white.opacity(opacity))
                        .rotationEffect(.degrees(rot))
                        .offset(x: dx, y: dy)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.45).delay(0.1 + Double(i) * 0.09), value: appeared)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Mood Slide

struct MoodSlideView: View {
    let visible: Bool
    let appeared: Bool
    let score: Double
    let trend: String?

    private var accent: Color {
        if score >= 0.2  { return Color(hex: "#5edb97") }
        if score >= 0.0  { return Color(hex: "#60d4e8") }
        if score >= -0.2 { return Color(hex: "#ffc840") }
        return Color(hex: "#FFA6C9")
    }

    // score here is delta from personal baseline
    private var moodWord: String {
        if score >= 0.15  { return "brighter" }
        if score >= 0.05  { return "steady" }
        if score >= -0.05 { return "balanced" }
        if score >= -0.15 { return "heavier" }
        return "darker"
    }

    private var trendLine: String {
        switch trend {
        case "upward":   return "lifting above your baseline lately."
        case "downward": return "dipping below your usual lately."
        default:         return "close to your personal baseline."
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "#111a17").ignoresSafeArea()
            VStack(spacing: 0) {
                Text("your mood")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .tracking(5).textCase(.uppercase)
                    .foregroundColor(accent.opacity(0.4))
                    .padding(.bottom, 28)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

                Text(moodWord)
                    .font(RFont.header(88))
                    .foregroundColor(accent)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: appeared)

                Text(trendLine)
                    .font(RFont.header(18, italic: true))
                    .foregroundColor(Color.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)
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
    @State private var animTask: Task<Void, Never>?

    var body: some View {
        Text(displayed)
            .font(font)
            .foregroundColor(color)
            .onChange(of: trigger) { _, isActive in
                if isActive { startAnimation() } else { stopAnimation() }
            }
            .onAppear { if trigger { startAnimation() } }
            .onDisappear { animTask?.cancel() }
    }

    private func startAnimation() {
        animTask?.cancel()
        displayed = ""
        animTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            for char in text {
                guard !Task.isCancelled else { return }
                displayed.append(char)
                try? await Task.sleep(for: .seconds(speed))
            }
        }
    }

    private func stopAnimation() {
        animTask?.cancel()
        displayed = ""
    }
}

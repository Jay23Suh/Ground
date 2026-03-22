import SwiftUI

// MARK: - Slide definitions

enum AbstractSlideType {
    case title
    case count(bg: Color, accent: Color, value: Int, label: String, context: String)
    case text(bg: Color, accent: Color, headline: String, subtext: String)
    case closing
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

        s.append(.init(type: .closing))
        return s
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
            case .closing:
                ClosingSlideView(visible: visible, appeared: appeared)
            }
        }
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
                Text(headline)
                    .font(RFont.header(44))
                    .foregroundColor(accent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.55).delay(0.1), value: appeared)
                Text(subtext)
                    .font(RFont.header(18, italic: true))
                    .foregroundColor(Color.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ClosingSlideView: View {
    let visible: Bool
    let appeared: Bool

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
                Text("keep showing up\nfor yourself ✦")
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

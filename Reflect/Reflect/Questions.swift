import Foundation

enum Category: String, CaseIterable {
    case gratitude    = "gratitude"
    case compassion   = "compassion"
    case values       = "values"
    case emotions     = "emotions"
    case grounding    = "grounding"

    var label: String {
        switch self {
        case .gratitude:  return "gratitude & appreciation"
        case .compassion: return "compassion & kindness"
        case .values:     return "values & meaning"
        case .emotions:   return "emotions & inner life"
        case .grounding:  return "grounding in the present"
        }
    }
}

struct Questions {
    static let bank: [(String, Category)] = [
        // Gratitude
        ("What's something you're grateful for in this exact moment?", .gratitude),
        ("What's one thing about your body you appreciate today?", .gratitude),
        ("What's something in your surroundings you feel thankful for?", .gratitude),
        ("What's a routine or habit you're glad you have?", .gratitude),
        ("What's a comfort you enjoyed today — food, warmth, rest, music?", .gratitude),
        ("Who are you grateful for today, and why?", .gratitude),
        ("What's a past version of you that you feel thankful for?", .gratitude),
        ("What's something you have now that you once really wanted?", .gratitude),
        ("What's a piece of advice you're grateful you received?", .gratitude),
        ("What's a small joy from today you don't want to overlook?", .gratitude),

        // Compassion
        ("How can you be a little gentler with yourself right now?", .compassion),
        ("What's one thing you're willing to forgive yourself for today?", .compassion),
        ("What's something you're struggling with that deserves kindness, not criticism?", .compassion),
        ("How did you show up for yourself today, even in a tiny way?", .compassion),
        ("What's a mistake you can treat as a lesson instead of a failure?", .compassion),
        ("Who could use a bit of understanding from you right now?", .compassion),
        ("What's one kind thought you can offer yourself?", .compassion),
        ("What's a limit or boundary you honored that protected your energy?", .compassion),
        ("What's one way you could make tomorrow a bit easier on yourself?", .compassion),
        ("If a close friend felt like you do now, what would you say to them?", .compassion),

        // Values
        ("What mattered most to you about today?", .values),
        ("What did you do today that felt aligned with your values?", .values),
        ("What's an area of life where you want to show up more fully?", .values),
        ("What gave you a sense of purpose today, even briefly?", .values),
        ("What kind of person do you want to be in small, daily moments?", .values),
        ("What value felt strongest in you today — honesty, curiosity, kindness?", .values),
        ("What's one tiny action you took that moved you toward the life you want?", .values),
        ("Where did you choose what mattered over what was easiest today?", .values),
        ("What's something you said no to that protected what you care about?", .values),
        ("If today had a theme, what would it be?", .values),

        // Emotions
        ("What emotion is most noticeable in you right now?", .emotions),
        ("Where did you feel that emotion in your body today?", .emotions),
        ("What's something that felt surprisingly heavy today?", .emotions),
        ("What's something that felt surprisingly light or easy today?", .emotions),
        ("What emotion did you try to push away, and why?", .emotions),
        ("When did you feel most at ease today?", .emotions),
        ("When did you feel most tense or on edge?", .emotions),
        ("What do you wish you could say out loud that you're holding inside?", .emotions),
        ("What's one emotion you can allow, just for a few breaths?", .emotions),
        ("What helped you regulate or soothe yourself today, even a little?", .emotions),

        // Grounding
        ("What sensations can you feel in your body right now?", .grounding),
        ("What are three things you can see, two you can hear, one you can feel?", .grounding),
        ("What does your breathing actually feel like in this moment?", .grounding),
        ("What's one place in your body that feels okay or neutral?", .grounding),
        ("What's a small detail around you that you hadn't noticed before?", .grounding),
        ("What tells you that you are safe enough in this moment?", .grounding),
        ("How does your body feel when you gently unclench your jaw and shoulders?", .grounding),
        ("What's one thing you can let go of, just for the next minute?", .grounding),
        ("What's a small action you could take right now to feel 5% more settled?", .grounding),
        ("If you named this moment as a weather pattern, what would it be?", .grounding),
    ]

    static func pick() -> (String, String) {
        let item = bank.randomElement()!
        return (item.0, item.1.rawValue)
    }
}

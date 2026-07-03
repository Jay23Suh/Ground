# Ground

A macOS menu bar journaling and mindfulness app. Lives in the menu bar — no dock icon. Users answer daily prompts, write free-form notes, track streaks/stats, and optionally connect with friends to share memories.

## Stack

- Swift + SwiftUI (macOS, menu bar extra)
- Supabase — auth (email) + database (entries, notes, friends, collective events)
- Apple Natural Language framework — on-device place extraction from journal text
- UserNotifications — daily check-in reminders

## Architecture

Single `SupabaseManager` singleton (`@MainActor`) owns all state and data fetching. Views receive it via `.environmentObject`. The menu bar popup is the primary UI surface — no main window.

```
Ground/
  GroundApp.swift          # App entry, MenuBarExtra setup
  AppDelegate.swift
  SupabaseManager.swift    # All Supabase auth + data logic (central singleton)
  PopupState.swift         # Popup open/close state
  MainWindowView.swift     # Root view switching between tabs
  HomeView.swift           # Greeting, streak, recent entries, quote
  JournalPopupView.swift   # Daily prompt answering flow
  HistoryView.swift        # Past entries browser
  StatsView.swift          # Word count, streak, category breakdown
  NotesView.swift          # Free-form notes
  FriendsView.swift        # Friend search, requests, shared memories
  CollectiveEventDetailView.swift  # Shared group events
  ChillView.swift          # Ambient audio / focus mode
  AbstractView.swift
  OnboardingView.swift     # First-run account setup
  SetupView.swift
  SettingsView.swift       # Account, notifications, legal
  NotificationPromptView.swift
  Notifications.swift      # Scheduling daily reminders
  Questions.swift          # Prompt bank
  QuoteService.swift       # Daily quote rotation
  Entry.swift              # Entry model (Codable)
  Note.swift               # Note model
  CollectiveModels.swift   # CollectiveEvent + related models
  DesignSystem.swift       # Colors, fonts, spacing constants
  Components.swift         # Shared UI components
  ChillAudio.swift         # Audio playback logic
```

## Key Models

**Entry** — a journal response. Fields: `id`, `user_id`, `question`, `answer`, `category`, `skipped`, `created_at`. Word count and date derived on the fly. Helpers in `Entry.swift`: `.snippet` (first standalone sentence, whitespace-collapsed — shared by Abstract + Stats) and `[Entry].inGroundWeek(offsetWeeks:)` (Sun–Sat slice via an explicit `firstWeekday=1` Gregorian calendar, locale-independent). `GroundStats` (in `StatsView.swift`) is a pure init over any `[Entry]` slice — reused as-is for both all-time and per-week.

**Note** — free-form note (separate from prompted entries).

**CollectiveEvent** — a shared group event tied to a date, created by a user and visible to friends.

## Features

- **Daily prompts** — rotating questions from a prompt bank, answered in the popup
- **Streak tracking** — counts consecutive days with at least one non-skipped entry
- **History** — scrollable log of past entries with search/filter. Supports deep-linking: a `scrollTarget: Binding<UUID?>` scrolls to + orange-highlights a specific entry (used by Stats highlight cards)
- **Stats** — all-time home for cumulative numbers: totals, streaks, category breakdowns, mood timeline, hour pattern. Also has "top 3 longest / most emotional entries" highlight cards (`TopEntriesListCard`) whose rows tap through to that entry in History
- **Abstract** — strictly a **weekly** (Sun–Sat calendar week) visual wrap, NOT all-time. Shows this-week counts with growth badges ("▲15% vs last week" on entries/words), all-time streak (streak is the one deliberately non-week-scoped stat), empty-week fallback slide. Was previously misleadingly built from all-time data despite weekly framing/notification. Global data lives in Stats, not here — Abstract must not duplicate it
- **Notes** — scratchpad separate from prompted journaling
- **Friends** — find by @handle, send/accept requests, share specific memories
- **Collective events** — group milestones visible to your friend network
- **Chill mode** — ambient audio for focus/relaxation
- **Notifications** — daily reminders via UserNotifications, configured in Settings; Abstract "your week in journaling" notification fires Sunday 10am (matches the Sun–Sat week boundary)

## Secrets

Supabase URL and anon key live in `Secrets.xcconfig` (gitignored). They fall back to hardcoded values in `SupabaseManager.swift` if the xcconfig is missing.

## Legal

- [PRIVACY_POLICY.md](PRIVACY_POLICY.md)
- [TERMS_OF_SERVICE.md](TERMS_OF_SERVICE.md)

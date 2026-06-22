# Ground

A personal journaling and mindfulness app for macOS. Ground lives in your menu bar — always a click away, never in the way.

## Features

- **Daily prompts** — respond to a new question each session, or write a free-form memory
- **Timeline & history** — browse entries by date, filter by place, search across everything
- **Place labels** — automatically detected from your text using Apple's on-device Natural Language framework
- **Collective memories** — invite a friend to write their own perspective on a shared experience, then reveal each other's entries together
- **Friends** — find people by @username and manage connections
- **Stats** — a view of your journaling practice over time
- **Abstract** — a visual review of your journey, unlocked after 10 entries

## Privacy

Ground is built with privacy as a baseline, not an afterthought.

- No advertising or tracking SDKs
- No data sold or shared with third parties (beyond Supabase for storage and zenquotes.io for daily quotes)
- Place extraction runs entirely on-device using Apple's Natural Language framework
- All data in transit is encrypted via HTTPS/TLS
- Supabase Row Level Security ensures your data is only accessible by your account

See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for the full policy.

## Tech Stack

- **SwiftUI** — macOS menu bar app targeting macOS 15.7+
- **Supabase** — authentication, database, and row-level security
- **Apple Natural Language framework** — on-device place name extraction
- **UserNotifications** — check-in reminders and daily quotes

## Requirements

- macOS 15.7 or later
- Xcode 16+
- A `Secrets.xcconfig` file in `Ground/Ground/` with your Supabase credentials (not committed)

```
SUPABASE_URL = your_supabase_url
SUPABASE_ANON_KEY = your_supabase_anon_key
```

## Support

jayyy.suh@gmail.com

# MVP Spec — Tracker App

## Concept
iOS app for tracking anything quantifiable. Chat-driven: users describe what they want to track in plain language; the AI builds tiles, lets them log via free text, and answers questions about their data.

**Positioning:** "Track anything you can count or measure. Your AI will tell you what's changing."

## Tile types (only two)

**Counter** — things you accumulate (+1 each time)
- Examples: water, coffees, workouts, pushups, expenses
- Fields: name, unit, icon, color, daily/weekly goal, reset cadence

**Measurement** — values you record at a moment
- Examples: weight, sleep hours, mood (1–5), blood pressure
- Fields: name, unit, icon, color, target (optional), trend direction (good = up/down)

Both produce time-series of numbers → both can be charted and analyzed.

## The chat does three things

| Action | Example |
|---|---|
| Build a tile | "track my water" → tile created |
| Log via debrief | "drank 6 glasses, gym, 3 coffees" → all tiles update |
| Ask about data | "how much coffee this week vs last?" → insight + comparison |

Same input. No mode switch.

## Interactions

- **Tap +** on tile → quick log (+1 for counter, opens entry sheet for measurement)
- **Tap tile body** → detail view (chart, history, AI insights, edit)
- **Chat input** → build / log / ask

## Home grid
Tiles arranged 2-column. Each shows: icon, name, current value, trend or sub-label, quick-log button. No charts on tiles (those live in detail view). Chat input at the bottom.

## Detail view
Hero value, delta vs prior period, sparkline/chart, time-range tabs (7d/30d/3m/1y), AI insight, recent entries list, FAB for quick log.

## MVP scope

**In:**
- 2 tile types: Counter, Measurement
- Chat builder
- Daily debrief (free-text → multi-tile updates, with review-before-commit)
- AI Q&A on tracked data
- Quick-tap logging + detail view
- All data local (no accounts, no backend for v1)

**Out (for v2+):**
- Checklists, streaks, timers
- External integrations (MCPs, APIs, Apple Health)
- iOS home-screen widgets
- Sharing / social
- Premium tier

## Hypotheses to validate

1. Do people build tiles? (acquisition)
2. Do they come back to log? (retention)
3. Does the daily debrief feel magical or annoying? (core bet)
4. Does AI Q&A drive curiosity opens? (engagement)

## Mockups (in chat above)
1. Tile builder — water (counter)
2. Tile builder — workouts (counter with weekly target)
3. Home grid — counters + measurements mixed
4. Daily debrief — free-text → preview of updates
5. AI Q&A — compare-this-vs-last and rest-vs-workout-day questions
6. Detail view — weight measurement with sparkline + insight

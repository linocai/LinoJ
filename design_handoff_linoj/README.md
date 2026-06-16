# Handoff: LinoJ — macOS + iOS planner app

## Overview
LinoJ is a calm personal planner that cleanly separates **time-bound events** (calendar) from **time-agnostic todos** (tasks). It targets both macOS and iOS as native Swift apps, with shared core logic and platform-specific UI patterns.

Three conceptual surfaces, surfaced as four tabs:
- **Personal** — todos for yourself
- **Company** — work todos + projects (some todos belong to a project, others are standalone)
- **Calendar** — events (anything with a time + place + people)
- **Main** — the unified daily view (todos hero + 7-day events look-ahead + projects strip)

## About the design files
The files in this bundle are **HTML/React design references** — prototypes showing intended look, layout, and behavior. They are **not production code to copy directly**.

Your task is to **recreate these designs in SwiftUI** (the user's stated target stack: native Swift on macOS + iOS). Use the HTML as a precise visual + interaction spec. Use SwiftUI's native primitives (`List`, `NavigationStack`, `TabView`, `.sheet`, `.glassEffect()`, etc.) and Apple-native materials wherever the design specifies them.

## Fidelity
**High-fidelity.** Exact colors, type sizes, spacings, and layouts are committed. Reproduce pixel-perfectly. Where iOS 26 Liquid Glass is called for, use SwiftUI's native `.glassEffect()` / `.regularMaterial` — don't simulate it.

---

## Core design principles (NON-NEGOTIABLE)

These shape the entire data model and UI. Don't deviate.

1. **Todos never carry time.** A `Todo` has `title`, `urgency`, optional `project`, optional `done`. There is **no due date field, no "today", no "tomorrow", no "overdue"** on todos. If something must be tied to a clock, it is an **Event**, not a todo.

2. **Events always carry time; location and attendees are optional** (still defaults to prompting for them). An `Event` has `title`, `start: Date`, `end: Date`, `location: String`, `attendees: [Person]`, optional `project`. The wall stays put: anything with a clock is an Event, anything without a clock is a Todo.

3. **Urgency has exactly two levels.** `urgent` or `normal`. No high/medium/low. Urgent visualizes with blue accent (#2563eb). No decay / auto-demote / countdown / gamified enforcement. When urgent count crosses a soft threshold, a passive, dismissible reflective nudge may appear — non-punishing, non-blocking, a mirror not a cop.

4. **Projects belong to Company.** Projects are NOT a top-level tab. They live inside Company. Tapping a project card opens a detail view.

5. **Time bleeds into Main only via "Heads up" alerts.** When an event starts within ~60 minutes, a soft alert appears at the top of Main. That's the ONLY way time-info shows up alongside todos.

6. **Appearance follows the system.** No in-app light/dark toggle — `colorScheme` is read-only from the OS. Mention "Switch in System Settings to change" in the UI.

---

## Architecture / Data model

```swift
enum Urgency { case urgent, normal }
enum Scope { case personal, company }

struct Todo {
    let id: UUID
    var title: String
    var urgency: Urgency
    var scope: Scope          // personal | company
    var projectID: UUID?      // nil for standalone or personal
    var done: Bool
}

struct Project {
    let id: UUID
    var title: String
    var intro: String         // 1-2 sentence summary
    var notes: String         // longer free-form
    var tag: String           // free-form status label, e.g. "Shipping June"
    var members: [Person]
    var createdAt: Date
}

struct Event {
    let id: UUID
    var title: String
    var start: Date
    var end: Date
    var location: String
    var attendees: [Person]
    var projectID: UUID?      // optional link to a project
}

struct Person {
    let id: UUID
    var name: String
    // initial = name.first
}
```

Persist with SwiftData or CoreData. Sync via CloudKit (user-facing toggle in Settings).

---

## Navigation

### macOS
- Custom `NSWindow` with top-bar `Picker` (segmented control) for tabs: **Main / Personal / Company / Calendar**
- No sidebar
- `Command-K` opens search palette (Spotlight-style centered modal)
- `Command-N` opens Quick Add modal
- `Command-1..4` jumps to tabs
- `Command-,` opens Settings (sheet-style window)
- Min window size: `1200 × 720`

### iOS
- `TabView` with bottom-floating glass tab bar (use `.glassEffect()` capsule)
- Tabs: **Main / Personal / Company / Calendar**
- Two floating glass action buttons top-right: search 🔍 and `+`
- Search → full-screen sheet
- `+` → bottom sheet with type picker (Todo / Event / Project)
- Project detail → push navigation inside Company tab
- Settings → modal sheet from anywhere

---

## Design tokens

### Colors (light mode)
```
bg          #fafaf9   app background
bgSoft      #f3f2ef   secondary surface
panel       #ffffff   cards / list rows
border      rgba(15,15,15,0.07)
borderStrong rgba(15,15,15,0.12)
ink         #0a0a0a   primary text
inkSoft     rgba(10,10,10,0.62)
inkMute     rgba(10,10,10,0.42)
inkDim      rgba(10,10,10,0.22)
chip        rgba(10,10,10,0.05)

blue        #2563eb   ONLY for urgent / heads-up
blueInk     #1e40af   urgent text on light
blueSoft    rgba(37,99,235,0.08)
blueSofter  rgba(37,99,235,0.045)
blueBorder  rgba(37,99,235,0.22)
```

### Colors (dark mode)
```
bg          #0d0d0e
bgSoft      #161617
panel       #181819   (iOS panel: #161618, iOS bg: #000)
border      rgba(255,255,255,0.07)
borderStrong rgba(255,255,255,0.14)
ink         #f6f6f5
inkSoft     rgba(246,246,245,0.65)
inkMute     rgba(246,246,245,0.42)
inkDim      rgba(246,246,245,0.22)
chip        rgba(255,255,255,0.06)

blue        #60a5fa
blueInk     #93c5fd
blueSoft    rgba(96,165,250,0.12)
blueBorder  rgba(96,165,250,0.32)
```

### iOS Main page background
`#f4f3ef` (a hair warmer than macOS to feel cozier on phone).

### Typography
- **Display**: `.system(.title3, design: .default, weight: .semibold)` — SF Pro Display
- **Body**: `.system(.body, design: .default)` — SF Pro Text
- **Mono**: `.system(.caption, design: .monospaced)` — SF Mono, for times / kbd / numbers / project counts

Specific sizes (use as type ramp guidance):

| Use | macOS | iOS | Weight | Letter-spacing |
|---|---|---|---|---|
| Big screen title (e.g. "To do") | 26 | 34 | 600/700 | −0.025 / −0.03 em |
| Section header ("Urgent") | 17 | 17 | 600/700 | −0.015 / −0.02 em |
| Card title (project / event) | 13–17 | 13–16 | 600 | −0.015 em |
| Todo bubble title (urgent) | 14.5 | 15.5 | 600 | −0.005 em |
| Todo bubble title (normal) | 13.5 | 14.5 | 500 | −0.005 em |
| Body | 12.5–13 | 13–14 | 500 | −0.005 em |
| Caption / meta | 11–12 | 11–12.5 | 500 | — |
| Uppercase tag | 10.5–11 | 10–11 | 600/700 | +0.06–0.08 em, ALL CAPS |
| Mono / time | 10–12 | 11–12 | 500/600 | −0.02 em, tabular-nums |

### Spacing
8px grid. Common values: 4, 6, 8, 10, 12, 14, 16, 18, 22, 28, 32.

### Radii
- Buttons / chips: 6–8 (macOS), 8–12 (iOS)
- Cards / bubbles: 11–14
- Modal corners: 14 (macOS), 24 (iOS bottom sheet)
- Pill: full (999)

### Shadows
Cards: subtle, mostly use 0.5px borders.
Floating modals: `0 24px 80px rgba(0,0,0,0.45), 0 0 0 0.5px rgba(0,0,0,0.18)`
iOS glass: rely on `.glassEffect()`; don't hand-roll.

---

## Screens (in order of priority)

### 1. Main view
**Both platforms.** The default tab.

**macOS layout** — `1fr 360px` two-column grid:
- **Left column** (flex column with 16pt gap):
  - Optional Heads-up event alert (when imminent event today)
  - Header row: "To do" 26pt + counts "12 open · 3 urgent" (urgent number in blue)
  - **Two-column bubble kanban** (1fr 1fr, 18pt gap, `flex: 1` height):
    - "Urgent" column: blue dot + label, blue-soft bubbles with 3px blue left accent
    - "Normal" column: ink-color label, white bubbles
    - Each column scrolls internally — Projects strip stays pinned
  - **Projects strip** (pinned bottom, no scroll): top-border rule, 3 inline editorial rows. Each row: `1fr 200px 110px` grid = title+tag+intro | mono stat numbers | avatar stack.
- **Right rail** (360px):
  - "Next 7 days" header
  - 7 day-rows: day label + date + first 3 events (mono time + title). "+N more" overflow.
  - Pinned at bottom: gray-bg dashed-border "From yesterday" box with checkable missed events.

**iOS layout** — single scroll column:
- Two floating glass buttons top-right (search + `+`)
- Big "To do" title 34pt
- Single stat line: "X open · Y urgent · Z events today"
- Optional Heads-up event alert (full-width pill)
- **Urgent section**: section header with blue dot, full-width blue-tinted bubbles stacked
- **Normal section**: section header, then a SINGLE white card containing all normal todos as compact single-line rows (`<List>` of `<Row>`)
- **Upcoming today**: horizontal scroll of 3 mini event cards (200pt wide each)
- **Projects**: horizontal scroll of 3 mini project cards (240pt wide each)
- Floating glass tab bar at bottom (14pt margin each side, 24pt above home indicator)

### 2. Personal view
**Both platforms.**

- Big title "Personal"
- Stats: "X open · Y done"
- 2-column kanban (macOS) or 2 sections (iOS): Urgent + Normal bubbles
- **Completed storage box** at the bottom: dashed-border card, collapsible (chevron rotates), shows completed todos with strikethrough + mute color + "done" italic suffix
- iOS Completed box uses the same dashed-border pattern but with 14pt radius

### 3. Company view
**Both platforms.**

- Big title "Company"
- Stats: "X todos · Y projects"
- Scope chips: All work / Standalone / individual projects (pill row)
- 2-column kanban: Urgent + Normal bubbles
- **Projects** sub-section:
  - macOS: 3 rich full-width cards in a column. Each has `1.4fr 1fr 1fr` 3-column body: (title+intro+tag+members) | (Todos count + 4 preview todos) | (Linked events count + chronological list)
  - iOS: stacked detailed project cards (title + tag + intro + stats row + linked events preview)

### 4. Calendar view
**Both platforms.**

- Big title "Calendar"
- macOS: 7-column week grid, 52pt time-label column on left, 14 hours visible (7 AM → 9 PM), 46pt per hour. Today column has subtle background tint + black "now" line + dot at left edge. Events as cards within their hour-span with 2px black left accent.
- iOS: horizontal 7-day strip (selected day = ink fill), then below = single-day list of event cards (large iOS event cards with time, title, where, attendees stack)
- Header: title + count + `‹ May 27 — Jun 2 ›` nav + "Today" button + `+ New event` ink button
- Drop the Day/Week/Month switcher (we only show week)
- iOS only: bottom "From yesterday" box when looking at today

### 5. Project detail view
**Both platforms.** Opens from a project card in Company tab.

- macOS:
  - Breadcrumb: `← Company / LinoJ for macOS v1` + `⋯` icon button top-right
  - Hero: project title 30pt + tag pill + intro paragraph (max-width 720) + "Edit project" outline button right
  - Meta row: avatars | divider | open / urgent / done stats | divider | linked events / created stats
  - 2-column body (`1.3fr 1fr`):
    - Left: Urgent + Normal bubbles + Completed collapsible box (filtered to this project)
    - Right: Linked events grouped by day (each day = small uppercase header + event rows with time + title + where + avatars) ; below = Notes section (white-space: pre-line)
- iOS:
  - Two top floating glass buttons: `← Company` (with chevron) + `⋯`
  - Hero: tag pill (above title) → title 30pt → intro → avatar row + "3 members · since Apr 12"
  - Stats card: open / urgent / done / events 4-column with thin dividers between, mono numbers 20pt
  - Sections: Urgent bubbles → Normal compact list → Linked events grouped by day → Notes card → Completed box

### 6. New (Quick Add) modal/sheet
**Both platforms.** Single entry point with type picker.

- Type picker: Todo / Event / Project (3-way segmented control with type icons)
- **Todo form**: title input (big display 22pt) + Urgency toggle (Urgent blue / Normal) + Scope toggle (Personal / Company) + Project picker (horizontal chip row including "None" + each project)
- **Event form**: title + Date + Start time + End time + Location + Attendees (avatar chip row + "+ Add" dashed chip) + optional Link to project
- **Project form**: title + multi-line description textarea + Tag free-text + Members chip row + "+ Invite" dashed chip
- macOS: 520pt wide centered modal with backdrop, footer has keyboard hints (`esc` cancel · `⌘↵` create) + Cancel + Create buttons
- iOS: bottom sheet with grab handle, Cancel (left) / "New" title (center) / Create (right ink pill) at top, then segmented control, then scrollable body

### 7. Search / Command palette
**Both platforms.**

- Search input (auto-focused) + Scope chips (All / Todos / Events / Projects)
- Grouped results: Quick actions / Todos / Events / Projects — each group with uppercase mini-header
- Each result row: type icon (in chip) + title + meta hint. Urgent items get inline blue dot + bold title.
- macOS first result is highlighted with subtle background + `↵` kbd hint on right
- Footer: keyboard hints + perf reading "X results in Y ms"
- iOS: full-screen sheet, search field with × clear button + Cancel link top-right, scope chips, grouped result cards (one per group, each is a white card with rows)

### 8. Settings
**Both platforms.** Appearance is locked to "System" with a small "locked" mono kbd badge.

Sections:
- **General**: Appearance (System, locked) · Default tab · Default todo scope · Show completed in counts · Start week on
- **Notifications**: Heads-up timing (30 min) · System banner · Yesterday missed reminder · Daily summary time · Quiet hours range
- **Sync**: iCloud sync · Account · Apple Calendar mirror · Apple Reminders mirror · Last-synced status pill
- **Shortcuts** (macOS only): Navigation / Create / On a todo — mono kbd table
- **About**: app name + version + tagline + Release notes / Feedback / Privacy / Acknowledgements

macOS: 760×540 modal with sidebar nav.
iOS: full-screen `.sheet` with iOS grouped list, Cancel/Done top, Sign out red button at bottom.

### 9. Empty states
Use a small geometric SVG + display title + warm friendly subtitle + optional CTA. Keep the layout skeleton (kanban columns, 7-day strip, search field) visible — the empty state is centered within the existing chrome, never replaces it.

Variants:
- Inbox zero (Main fully empty): "Inbox zero." / "+ New todo"
- Personal urgent empty (partial): "Nothing urgent." / "Nice." inside dashed-border column
- Clear week (Calendar): "A clear week."
- No search results: 'No matches for "..."'

---

## Interactions & behavior

### Animations
- Todo bubble hover (macOS): `translateY(-1px)` over 0.12s
- Heads-up alert: pulsing dot (`opacity 0.4 ↔ 0.9` + scale 0.7 ↔ 1.0, 2s ease-in-out infinite)
- Tab switching: instant, no transition
- Sheet/modal open: standard system spring
- Completed-box toggle: chevron rotates 90deg over 0.18s; content slides
- Empty state appearance: fade-in 0.2s

### Hover/press states
- macOS bubble: background lifts slightly (transform + bg)
- macOS list row: bg → `hover` token (rgba(10,10,10,0.04))
- iOS row: tap-bg → momentarily lighter
- All interactive elements: cursor pointer / haptic light on iOS

### Heads-up alert logic
- Show on Main when an event starts within 60 minutes from now and hasn't ended
- Display: "Heads up · in X min · Event title · Location" + Snooze + Open
- Schedule a local `UNNotificationRequest` 30 min before event start (configurable in Settings)

### Yesterday's missed events
- Compute on app open: events from yesterday that the user hasn't marked attended
- Show as a gray dashed-border box at bottom of Main right-rail (macOS) or bottom of Calendar Today view (iOS)
- Tapping checkbox marks attended; item dims + strike-through + "done" suffix

### Keyboard shortcuts (macOS)
| Keys | Action |
|---|---|
| ⌘1 / ⌘2 / ⌘3 / ⌘4 | Jump to Main / Personal / Company / Calendar |
| ⌘K | Search / jump |
| ⌘N | New (default Todo) |
| ⌘⇧T / ⌘⇧E / ⌘⇧P | New Todo / Event / Project |
| ⌘, | Settings |
| ⌘↵ (in modal) | Submit |
| esc | Cancel modal |
| ⌘U (on todo) | Toggle Urgent/Normal |
| ⌘↵ (on todo) | Toggle done |
| ⌫ (on todo) | Delete |

### Responsive behavior (macOS)
At narrow window widths:
- < 1200pt: Company project cards stack 1 row → 2 rows internally
- < 1100pt: Calendar 7-col → enable horizontal scroll, sticky day headers
- < 900pt: degrade Calendar week → 3-day view; consider hiding Main right rail

---

## Liquid Glass (iOS 26)
Use SwiftUI native materials:
- Floating tab bar: `.glassEffect()` on a capsule shape with 14pt insets from edges, 24pt above home indicator
- Floating action buttons (search, `+`): same `.glassEffect()` on round 40pt capsules
- Top bar on Project Detail: glass capsules for back button + ⋯
- Settings top bar (sticky): `.regularMaterial` background with 20pt blur

Don't hand-roll glass with manual blur + tint — use the system primitive.

---

## Assets / icons
- All icons in the design are inline SVG. In SwiftUI use **SF Symbols**:
  - Tab bar: `house` / `person` / `briefcase` / `calendar`
  - Search: `magnifyingglass`
  - More: `ellipsis`
  - Back: `chevron.backward`
  - New: just a `+` character
  - Chevron: `chevron.right`
  - Checkbox: build custom (rectangle stroke + checkmark fill)
- No raster assets to migrate.

---

## File map (in this bundle)

| File | What it contains |
|---|---|
| `LinoJ.html` | Master design canvas. Open this to see all screens side-by-side with pan/zoom. |
| `data.js` | Sample data model. Mirror the structure into Swift types. |
| `direction-a.jsx` | macOS Main view + bubble column + project strip + event alert + window chrome |
| `direction-a-detail.jsx` | macOS Personal / Company / Calendar / Completed box |
| `macos-overlays.jsx` | macOS New modal (Todo/Event/Project tabs) + Search palette |
| `macos-project-detail.jsx` | macOS project detail page (breadcrumb + hero + 2-col body) |
| `macos-settings.jsx` | macOS Settings modal (5 sections + sidebar nav) |
| `ios-main.jsx` | iOS Main view + glass primitive + bubble + tab bar + top actions |
| `ios-detail.jsx` | iOS Personal / Company / Calendar / Completed box |
| `ios-overlays.jsx` | iOS New sheet + Search screen |
| `ios-project-detail.jsx` | iOS project detail page |
| `ios-settings.jsx` | iOS Settings (grouped list modal) |
| `empty-states.jsx` | Empty-state geometric icons + EmptyBlock + per-screen empty variants |
| `design-canvas.jsx` | Canvas viewer (not part of the app) |
| `macos-window.jsx` | macOS window chrome reference (not used directly) |
| `ios-frame.jsx` | iPhone device frame reference (not part of the app) |

---

## Recommended implementation order

1. **Bootstrap the project**: Two SwiftUI targets (`LinoJ-macOS`, `LinoJ-iOS`), shared package `LinoJCore` for models + persistence + view models.
2. **Models + sample data**: Translate `data.js` into Swift; seed in-memory for development.
3. **Design system module**: Colors, typography, spacing constants; shared View modifiers (`.bubbleStyle(urgent: Bool)`, `.cardStyle()`).
4. **Tab navigation shell**: macOS top segmented control window, iOS bottom glass TabView. Wire stub views.
5. **Main view** for both platforms (most complex; everything else reuses these primitives).
6. **Personal + Company** (mostly reuse from Main).
7. **Calendar** (week grid macOS, day-list iOS).
8. **Project detail** (push navigation iOS, separate view macOS).
9. **Quick Add** modal + Search palette.
10. **Settings + Empty states.**
11. **Heads-up logic** + local notifications.
12. **CloudKit sync.**

---

## Questions to surface to the user during build

- "iCloud sync" toggle is in the spec — should this be opt-in (off by default) or assumed on?
- The "Edit project" button has no edit flow designed yet — should that reuse the New Project modal in edit mode?
- The "From yesterday" check is a UX guess (a way to retroactively confirm event attendance). Confirm this is desired behavior before shipping.
- Widget designs are explicitly out of scope. When the user asks for widgets, design them first before implementing.

# PostCode
A professional timecode calculator and converter app. Made by an editor, for editors.

Whether you're calculating clip durations, spotting VFX shots, converting frame rates for international delivery, or totalling segments for a programme run time — PostCode handles the maths so you can focus on the edit.

---

## Features

### Calculator Mode
Add, subtract, multiply, and divide timecode with a scrollable paper tape history. Long-press any line to copy or delete it. Supports negative values for pre-roll calculations.

### Run Mode
Enter In and Out points for multiple segments to calculate the total run time. Reorder segments with drag-and-drop. Save as TXT or CSV to share with others, or use in other apps.

### Converter Mode
Cross-convert timecode between different frame rates. Supports PAL conversions, NTSC pull-down and Drop Frame.

### TC / FR Toggle
Instantly toggle between timecode display (`01:00:00:00`) and frame count (`90000`) anywhere — useful for VFX and animation workflows.

### Frame Rates
Supports all SMPTE standards: `23.976`, `24`, `25`, `29.97 Drop frame`, `29.97 Non-drop frame`, `30`, `50`, `59.94 Drop frame`, `59.94 Non-drop frame`, and `60`. Plus custom frame rates.

### Export
Share calculations as plain TXT or CSV via the system share sheet.

---

## Architecture

**Pattern:** MVVM (Model–View–ViewModel), using Swift's `@Observable` macro (no Combine dependency).

**Core principle:** All timecode values are stored and computed as **integer frame counts**. This eliminates floating-point drift and makes arithmetic trivial. Timecode strings are strictly a display format, generated on demand from the frame count.

### Project Structure
```
PostCode/
├── App/
│   ├── PostCodeApp.swift              App entry point, scene lifecycle
│   └── AppCommands.swift              Menu bar commands for Mac and iPad
│
├── Model/
│   ├── Models.swift                   Data types: TapeEntry, FrameRate, Segment, AppStateSnapshot
│   └── Timecode.swift                 Pure maths: frames↔string, drop frame, real time
│
├── ViewModel/
│   ├── AppViewModel.swift             Central state: keypad routing, persistence, mode switching
│   ├── AppViewModel+Calculator.swift  Calculator operations, tape management, recalculation
│   ├── AppViewModel+Converter.swift   Frame rate conversion formula
│   └── AppViewModel+Run.swift         Segment management, TRT calculation, CSV export
│
├── View/
│   ├── ContentView.swift              Adaptive layout (iPhone/iPad), hardware keyboard handler
│   ├── CalculatorView.swift           Paper tape display with active "hero" line
│   ├── ConverterView.swift            Source/destination conversion cards
│   ├── RunView.swift                  Segment list, TRT header, In/Out input area
│   ├── WelcomeView.swift              Onboarding screen (shown on version update)
│   ├── KeypadView.swift               Responsive numeric keypad (adapts to screen height)
│   ├── UIChrome.swift                 iPhone header & iPad sidebar
│   └── UIComponents.swift             HeroText, CalcButton, theme, animations, buttons
│
└── Tests/
    └── PostCodeTests.swift            Unit tests for timecode maths and data models
```

### Key Decisions

| Decision | Rationale |
|---|---|
| Frames as integers | Avoids floating-point rounding errors across long calculations. |
| Inclusive frame counting | `duration = out − in + 1` matches Avid/Premiere convention where In == Out is 1 frame. |
| Per-mode frame rates | Users often work at 25fps for broadcast but 23.976 for conversion — independent rates avoid forced resets. |
| `switch mode` exhaustive matching | Compiler catches every location that needs updating if a new mode is added. |
| Debounced persistence | State auto-saves 2 seconds after changes to avoid disk thrashing. Immediate save on app background/inactive cancels the debounce to prevent stale overwrites. |
| Synchronous `saveImmediate()` | Writes directly on the main thread — guarantees completion before the system suspends the process. The rrevious `Task.detached` implementation could be killed prematurely. |
| `tapeRevision` counter | O(1) change detection for scroll-to-bottom, replacing O(n) array diffing on every tape mutation. Suppressed during `loadState()` via `isLoading` flag. |
| `HeroText` shared component | Single source of truth for the large display font size across all modes — derives point size from available width so TC and FR text are always identical, with no truncation on compact devices. |
| `CalcOperation.symbol` | Operator display strings defined once on the model, eliminating duplicate `switch` blocks in views and export logic. |
| `@ObservationIgnored` on internal state | Prevents unnecessary SwiftUI redraws for properties the UI never reads. |
| Static `NumberFormatter` on `FrameRate` | Cached formatter for custom rate display strings — eliminates per-access allocation in `FrameRate.id`. |

## Timecode Maths

### Non-drop Frame
Straightforward positional arithmetic:
```
totalFrames = (HH × 3600 + MM × 60 + SS) × baseFPS + FF
```

### Drop Frame
SMPTE drop frame (29.97 DF / 59.94 DF) skips frame *numbers* — not actual frames — to keep timecode aligned with wall-clock time.

- **29.97 DF** skips `;00` and `;01` at the start of every minute, *except* every 10th minute.
- **59.94 DF** skips `;00` through `;03` on the same schedule.

The implementation uses the standard SMPTE algorithm. See `framesToString()` and `inputToFrames()` in `Timecode.swift` for the full logic.

### Conversion Formula
```
destFrames = srcFrames × (srcMultiplier / srcBaseFPS) × (dstBaseFPS / dstMultiplier)
```
The middle term converts source frames to real-time seconds. The last term converts real-time seconds to destination frames. When both rates share the same NTSC multiplier (1.001), the multipliers cancel out cleanly.

---

## Persistence

App state is serialised to `PostCodeState.json` in the Documents directory.

- **Auto-save:** Triggers 2 seconds after any state change (debounced to avoid rapid writes during keypad input)
- **Immediate save:** On `scenePhase` transition to `.background` **or** `.inactive`. The `.inactive` save is critical for iPad Stage Manager, where apps can sit in `.inactive` without ever reaching `.background`. Cancels any pending debounce to prevent a stale write arriving afterward.
- **Synchronous writes:** `saveImmediate()` writes directly on the main thread with the `.atomic` option, guaranteeing the file is either fully written or not modified at all. This ensures completion before the system suspends the process.
- **Stored data:** Active mode, frame rates, input strings, paper tape history, run segment list, frames mode toggle, `lastWasEquals` result state
- **Migration:** Legacy `Segment` format (duration-only) is automatically migrated to the current In/Out frame model on decode. `lastWasEquals` falls back to tape-end detection for saves from older versions.
- **Load guard:** An `isLoading` flag suppresses side-effects (e.g. `tapeRevision` bumps and scroll animations) during state restoration.

---

## Feedback

### Audio
`AudioToolbox` system sounds provide audible click feedback through the speaker (keyboard click, delete tone, modifier pop).

### Haptics
SwiftUI `.sensoryFeedback` modifiers provide tactile feedback via the Taptic Engine: light impact on mode change, success pulse on equals/copy, error buzz on invalid operations.

---

## Design

- **Dark mode** Optimal for edit suites and control rooms.
- **SF Mono** for all numeric displays, ensuring column alignment.
- **`HeroText` component** derives the large display font size from available width, guaranteeing identical sizing across all three modes and both TC/FR display formats. Never truncates, even on iPhone SE.
- **Responsive layout:** Buttons and spacing scale smoothly between compact (iPhone SE) and full-size (iPad Pro) using linear interpolation against available height.
- **iPad:** Landscape uses a sidebar + split-pane layout.
- **iPhone:** Portrait falls back to the iPhone stack layout.

### Colour Palette
| Colour | Usage | Value |
|---|---|---|
| Orange | Operators, active states, branding. | `#FF9500` |
| Green | Results, totals, destination values. | `#00FF00` |
| Dark Grey | Card backgrounds, input fields. | `rgb(0.2, 0.2, 0.2)` |
| Light Grey | Secondary buttons, dividers. | `rgb(0.6, 0.6, 0.6)` |

---

## Requirements

- iOS 17.0+
- macOS 14.0+
- Built with Swift 6 and SwiftUI

---

## License

Copyright © 2026 Martin McLean. All rights reserved.

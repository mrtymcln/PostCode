# PostCode

PostCode is the timecode calculator & frame rate converter for video editors and post-production teams. Add, subtract, multiply, and divide timecode — then convert between any frame rate instantly.

Made by an editor, for editors.

Whether you're calculating durations, spotting VFX shots, converting frame rates for delivery, or totalling segments for a programme run time — PostCode handles the maths so you can handle the edit.

[![Download on the App Store](https://toolbox.marketingtools.apple.com/api/badges/download-on-the-app-store/black/en-gb)](https://apps.apple.com/app/id6758260094)

![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20iPadOS%20%7C%20macOS-blue)
![App Store](https://img.shields.io/itunes/v/6758260094)
![Swift](https://img.shields.io/badge/Swift-6.2-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-1575F9)

---

## Features

**Calculator Mode.** Add, subtract, multiply, and divide timecode. Your history is kept on the paper tape. Tap any line on the tape to drop its value back into the input. Touch and hold any line to copy or delete it. Supports negative values for pre-roll calculations.

**Run Mode.** Enter the In and Out points for multiple segments to calculate the total run time — like a simplified EDL. Reorder segments with drag-and-drop. Set a target to show how far over or under you are.

**Converter Mode.** Convert timecode between any two frame rates instantly. Supports drop frame and non-drop frame, plus NTSC pull-down.

**TC / FR toggle.** Flip the whole app between timecode (`01:00:00:00`) display, and frame count (`90000`) display. Perfect for VFX or animation workflows.

**Frame rates.** Supports all SMPTE standard frame rates — `23.976`, `24`, `25`, `29.97 Non-drop Frame`, `29.97 Drop Frame`, `30`, `50`, `59.94 Non-drop Frame`, `59.94 Drop Frame`, `60` — as well as custom frame rates.

**Undo.** Each mode keeps its own undo history. Shake your iPhone or press `⌘Z` to undo any destructive action.

**Copy & paste.** Touch and hold any value to copy and paste it as timecode or as frames. PostCode automatically validates and formats the timecode for you.

**Built for pros.** Hardware keyboard support on iPad and Mac. Dark mode optimised for edit suites and control rooms. Export calculations as TXT or CSV. All calculations and conversions are performed on-device — no Internet connection required.

---

## Timecode maths

### Non-drop frame
Standard timecode reads `HH:MM:SS:FF`: hours, minutes, seconds, and frames, each padded to two digits and separated by colons. So `01:23:45:12` is 1 hour, 23 minutes, 45 seconds and 12 frames.

The only field that doesn't behave like a clock is the last one. Frames (`FF`) count from `00` up to one below the frame rate, then roll over and tick the seconds up.

At 25 fps, it runs `00`–`24`, so the frame straight after `00:00:00:24` is `00:00:01:00`. Every frame gets a number and nothing is ever skipped. The colon separator (`01:00:00:00`) tells us we're in **non-drop frame**.

Working out the frame count is just positional arithmetic:

```
totalFrames = (HH × 3600 + MM × 60 + SS) × baseFPS + FF
```

### Drop frame

29.97 and 59.94 aren't whole numbers of frames per second. If you just counted up, your timecode would slide away from the real time of the footage — about 3.6 seconds per hour. **Drop frame** fixes that by skipping frame *numbers* (never actual frames, just the labels) to keep the display honest against the clock.

- **29.97 DF** skips numbers `;00` and `;01` at the top of every minute.
- **59.94 DF** skips numbers `;00` through `;03` at the top of every minute.
- Except every tenth minute, which doesn't skip.

This is the SMPTE algorithm: run forwards in `TimecodeFormatStyle` (frames → string) and backwards in `inputToFrames` (string → frames). The semicolon separator (`01;00;00;00`) tells us we're in **drop frame**.

### Conversion

```
destFrames = srcFrames × (srcMultiplier / srcBaseFPS) × (dstBaseFPS / dstMultiplier)
```

Read it left to right: the middle term turns source frames into real-time seconds, and the last term turns real-time seconds into destination frames. When both rates are on the NTSC 1.001 multiplier, those multipliers cancel and you're left with clean maths.

---

## Architecture

- PostCode uses a Model–View–ViewModel architecture, built on Swift's modern `@Observable` macro.

- A single `AppViewModel` which is `@MainActor`-isolated and sliced across extension files (`+Calculator`, `+Run`, `+Converter`, and so on) to keep the codebase readable.

- Every value is stored and calculated as an integer frame count, to avoid floating-point drift. Timecode strings are generated on demand for display only.

- Frames are counted inclusively `duration = out − in + 1`, just like Avid Media Composer and Final Cut Pro. An in and out point on the same frame is a one-frame segment, not zero.

- Each mode keeps its own frame rate & undo stack. Different tasks require different modes, so PostCode remembers the context for each one.

---

## What's in each file

### App/

- **`PostCodeApp.swift`** — The `@main` entry. Owns the `AppViewModel`, kicks off the initial load, and wires the `scenePhase` changes to the save logic.

- **`AppCommands.swift`** — The menu bar and modified ⌘/⌥ keys. Bare, unmodified keys are handled separately by `ContentView`; the two own disjoint key sets.

### Model/

- **`Timecode.swift`** — The timecode maths lives here. Frames → timecode string, typed digits → frames, frames → real-time seconds, and the drop-frame algorithm in both directions. Also home to the overflow-safe `Int` helpers (`saturatingAdd`, `saturatingDividing`, and friends). If you want to understand the app, read this file first.

- **`FrameRate.swift`** — The `FrameRate` enum: one case per SMPTE rate, plus `.custom`. Each case knows everything the maths needs about itself — its integer base (30 for 29.97), whether it's drop frame, the NTSC 1.001 pull-down multiplier, the separator it uses (`:` or `;`), and how many frame digits to display.

- **`Models.swift`** — The plain data types: what a tape entry, a segment, an app mode, a calculator operation, and the saved-state snapshot actually look like. No behaviour, just the data definitions and their `Codable` conformances, so they can be written to and read from disk.

### ViewModel/

- **`AppViewModel.swift`** — Holds the state shared across modes and the logic that isn't tied to a single feature: routing keypad presses to the correct field, switching modes, the TC/FR display toggle, and the formatting helpers.

- **`AppViewModel+Calculator.swift`** — Calculator Mode: operators, equals, arithmetic, and the paper tape.

- **`AppViewModel+Run.swift`** — Run Mode: adding, editing, reordering and deleting segments; the total run time; the target run time, and how far over or under you are; and the real-time duration for NTSC rates.

- **`AppViewModel+Converter.swift`** — Converter Mode: takes a timecode at one frame rate and works out the equivalent at another — e.g. conforming a 24 fps offline to 25 fps PAL, or seeing where a 23.976 cut lands at 29.97. The conversion formula is guarded against nonsense inputs like zero divisors or infinity.

- **`AppViewModel+Export.swift`** — TXT and CSV export. `exportText` builds a plain text summary for any mode; `generateCSV()` writes the segment list to a temporary `.csv` and returns its file URL. Both are handed to `ShareLink`.

- **`AppViewModel+Persistence.swift`** — Saves and loads the entire app state as a JSON file (debounced during use, with an immediate write when the app is backgrounded), and migrates save files from the legacy schema so an update never loses your work. Full details in the [Persistence](#persistence) section.

- **`AppViewModel+Paste.swift`** — Handles the pasteboard. It first tries to read as a real timecode (like `01:00:00:00` or `01;00;00;00`); if that doesn't work, it falls back to pulling out just the digits. Either way, it checks the result converts back to exactly what was pasted, so a pasted value never mutates to a different value.

- **`AppViewModel+Undo.swift`** — The per-mode undo stacks. Each entry only captures the mode it happened in, so pressing `⌘Z` in one mode never touches another.

### View/

- **`ContentView.swift`** — The user interface container. Picks the iPhone layout or the iPad/Mac layout, and owns the hardware keyboard handler.

- **`CalculatorView.swift`** — The paper tape of calculations. A scrollable list of previous inputs, with a 'hero' line at the bottom that shows your current input or the result.

- **`RunView.swift`** — A list of segments, a card displaying the total run time of all segments, and the In/Out input area.

- **`ConverterView.swift`** — The cards displaying the source and destination frame rates.

- **`KeypadView.swift`** — The numeric keypad, which resizes itself based on how much height is available on the current device.

- **`WelcomeView.swift`** — A pop-up sheet describing PostCode's features, shown on first run and after an update.

- **`AppHeader.swift`** — The top header bar, shown on iPhone and iPad.

- **`AppSidebar.swift`** — The side bar, shown on iPad.

- **`Components.swift`** — All the reusable components: the colours, text formatting, the keypad buttons, the share buttons, the animations and icons.

- **`ShakeDetector.swift`** — The custom 'shake to undo' implementation.

### `PrivacyInfo.xcprivacy`

The privacy manifest which declares `UserDefaults`, and confirms no tracking or data collection takes place.

### `PostCodeTests/`

The unit tests, written with Swift Testing. They cover the timecode maths (including the drop-frame boundaries and full round-trips), the calculator and tape replay, run totals, conversion, paste parsing, undo, export, the TC/FR toggle, and the persistence migration.

---

## Persistence

State gets written to `PostCodeState.json` in the app's Documents folder.

- Auto Save is debounced — two seconds after you stop touching things, it writes. That keeps the disk from getting thrashed whilst you punch numbers into the keypad.

- Immediate Save fires the moment the app goes inactive or to the background. It also cancels that pending timer, so a stale write can't land afterwards. The inactive case matters because iOS may suspend the app without it ever reaching full background.

- The write is synchronous, on the main thread, and atomic. It has to finish before iOS suspends the process, and an async task may be killed mid-write. Atomic means you get either the complete new file or the complete old one, never a half-written one.

- In legacy versions, a segment only recorded the duration. Now it records the In and Out points, so the decoder rebuilds the old segments with `In = 0, Out = duration − 1`. Fields added later are optional and fall back to `nil`. You can move between app versions without losing your work.

---

## Requirements

- **iOS 17** or later.
- **macOS 14 Sonoma** or later, on Apple Silicon.
- Built with Swift 6.2 and SwiftUI.

---

## What's new

### 1.4
- Set a Target Run Time, and PostCode shows how far over or under you are.
- In Run Mode, tap a segment to adjust its In and Out points.
- Tap any line on the calculator tape to drop its value back into the input.
- Fixes bug whereby a stray '0' could appear when starting a new calculation straight after a zero result.
- VoiceOver support for improved accessibility.

### 1.3
- Shake to undo.
- Improved keypad responsiveness.
- Out point highlights red if less than In point.
- Lowered the minimum requirement to iOS 17 and macOS 14.
- Refactored the architecture to make room for future improvements.

### 1.2
- Fixes bug whereby custom frame rates did not apply correctly.
- Hardware keyboard support for iPad and Mac.

### 1.1
- Touch and hold a value to copy and paste it.
- Drag and drop segments in Run mode to reorder them.

---

Copyright © 2026 Martin McLean. All rights reserved.

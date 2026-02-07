# PostCode v1.2

**PostCode** is a professional timecode calculator & converter. Made by an editor, for editors.
Whether you are calculating clip durations, spotting VFX shots, converting frame rates for international delivery, or adding up multiple segments to get the total run time—PostCode handles the maths, so you can handle the edit.

## Calculator Mode
Add, subtract, multiply, and divide timecode. PostCode automatically wraps negative numbers for pre-roll.
Maintains a 'paper tape' history of operations.
Tap a history line to copy or delete it.
Supports toggling between Timecode format (00:00:00:00) and Frame Count (00000).

## Run Mode
Enter the In and Out points of multiple segments to calculate the total run time. New in version 1.1, you can reorder segments.
Export the list as a TXT or CSV file.
The 'KeypadView' dynamically changes its 'Plus' button to 'Add' when in this mode.

## Converter Mode
Cross-convert a timecode between different frame rates instantly. Drop Frame and Non-drop Frame supported.

## Tc/Fr
Instantly toggle between displaying timecode or frames—perfect for VFX and animation workflows.

## Frame Rates
Supports all SMPTE standard frame rates (23.976, 24, 25, 29.97 Drop Frame, 29.97 Non-drop Frame, 30, 50, 59.94 Drop Frame, 59.94 Non-drop Frame, 60), as well as custom frame rates.

## Paper Tape
PostCode keeps a running log of your calculations in a scrollable paper tape.

## Export
Save your calculations as plain text for easy sharing. New in version 1.1, save as a CSV file for use in other applications.


# Overview
**Architecture:** Model-View-ViewModel.
**Tech Stack:** Swift, SwiftUI, Combine.
**Logic Core:** All calculations are performed in Frames (Integer) to ensure mathematical precision, then converted to Timecode Strings for display.
**Persistence:** User state is autosaved to JSON in the Documents directory.


# Project Structure
## Logic
**PostCodeApp.swift** Application entry point. Handles scene phase changes for autosave.
**AppViewModel.swift** The central brain. Holds the state for Calculator, Run, and Converter modes. Handles persistence and business logic.
**TimecodeLogic.swift**  Contains the mathematical core.
    *FrameRate* Enum definition for all SMPTE rates (standard and Drop Frame).
    *TimecodeCalculator* Static functions for Frames <-> String conversion.
    *AppStateSnapshot* Data structure for JSON persistence.

## User Interface
**ContentView.swift** Main layout container. Handles adaptive layout (iPhone vs iPad) and hardware keyboard events.
**AppNavigation.swift** Contains the Header UI (for iPhone) and the Sidebar UI (for iPad).
**KeypadView.swift** The shared numeric keypad. Uses a LazyVGrid to adapt button sizes dynamically to the screen width.
**Components.swift** Reusable UI elements, specifically the CalcButton styling, RunInputArea and custom modifiers.

## Views
**CalculatorView.swift** Standard calculator mode with a 'paper tape' history.
**RunView.swift** A list-based view for calculating the Total Run Time (TRT) from multiple segments (In/Out/Duration).
**ConverterView.swift** A utility to convert timecode values between different frame rates.
**WelcomeView.swift** An onboarding screen showing new features.


# Maths Logic & Drop Frame Handling
Internally, the app treats all timecodes as an absolute frame count (Interger).
**Non-Drop Frame** Simple calculation (Hours * 3600 + Minutes * 60 + Seconds) * FPS + Frames.
**Drop Frame** Uses the standard SMPTE algorithm. It skips two frames (or four for 59.94) every minute, except for every tenth minute, to align video time with real-world clock time.
*See framesToString and inputToFrames in TimecodeLogic.swift, for implementation details.


# Persistence
State is saved to 'PostCodeState.json'.
**Trigger** Saves automatically when the app goes to the background or when key data changes (with a debounce).
**Data** Saves the active mode, input strings, history tape, run lists, and selected frame rates.


# Design
**Colour Palette** Dark mode optimised. Uses high-contrast Orange (#FF9500), Dark Grey (0.2 white), and Light Grey (0.45 white).
**Typography** SF Monospaced is the font for all digits, to ensure alignment.
**Haptics:** 'UIImpactFeedbackGenerator' is used for keypad interactions. 'UINotificationFeedbackGenerator' is used for errors or illegal operations.

# License
Copyright © 2026 Martin McLean. All rights reserved.

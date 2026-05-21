import SwiftUI

// MARK: - APP COMMANDS

struct AppCommands: Commands {
	var vm: AppViewModel
	var body: some Commands {

		// MARK: - VIEW MENU

		CommandGroup(after: .sidebar) {
			Divider()

			Text("Mode")

			Button("Calculator") {
				withAnimation { vm.mode = .calc }
			}
			.keyboardShortcut("1", modifiers: .command)

			Button("Run") {
				withAnimation { vm.mode = .run }
			}
			.keyboardShortcut("2", modifiers: .command)

			Button("Converter") {
				withAnimation { vm.mode = .conv }
			}
			.keyboardShortcut("3", modifiers: .command)

			Divider()

			Button("Toggle TC/FR") {
				withAnimation { vm.toggleDisplayMode() }
			}
			.keyboardShortcut("t", modifiers: .option)
		}

		// MARK: - EDIT MENU
		// Replaces the default pasteboard commands, so Cmd-C copies the
		// active display value (not selected text) and Cmd-V pastes
		// structured timecode or raw digits into the current field.

		CommandGroup(replacing: .pasteboard) {
			Button("Copy") {
				UIPasteboard.general.string = vm.getActiveValueToCopy()
			}
			.keyboardShortcut("c", modifiers: .command)

			Button("Paste") {
				if let string = UIPasteboard.general.string {
					withAnimation { vm.processPastedText(string) }
				}
			}
			.keyboardShortcut("v", modifiers: .command)
		}

		// MARK: - UNDO MENU
		// Replaces the system undo/redo group so Cmd-Z works globally,
		// regardless of which view has focus.

		CommandGroup(replacing: .undoRedo) {
			Button("Undo") {
				vm.requestUndo()
			}
			.keyboardShortcut("z", modifiers: .command)
		}

		CommandGroup(after: .pasteboard) {
			Divider()

			Button("Delete") {
				vm.backspace()
			}
			.keyboardShortcut(.delete, modifiers: [])

			Button("Clear All") {
				vm.handleTrashTap()
			}
			.keyboardShortcut("c", modifiers: .option)
		}

		// MARK: - ACTIONS MENU

		CommandMenu("Actions") {

			// MARK: Calc Mode
			Text("Calculator")

			Button("Add") {
				if vm.mode == .calc { vm.setOperation(.add) }
			}
			.keyboardShortcut("+", modifiers: [])

			Button("Subtract") {
				if vm.mode == .calc { vm.setOperation(.subtract) }
			}
			.keyboardShortcut("-", modifiers: [])

			Button("Multiply") {
				if vm.mode == .calc { vm.setOperation(.multiply) }
			}
			.keyboardShortcut("*", modifiers: [])

			Button("Divide") {
				if vm.mode == .calc { vm.setOperation(.divide) }
			}
			.keyboardShortcut("/", modifiers: [])

			Button("Negate") {
				if vm.mode == .calc { vm.toggleNegate() }
			}
			.keyboardShortcut("-", modifiers: .option)

			Divider()

			/// Equals key fires calculateResult in calc mode.
			Button("Equals") {
				if vm.mode == .calc { vm.calculateResult() }
			}
			.keyboardShortcut("=", modifiers: [])

			// Return key (equals in calc, add segment in run) is handled
			// by `ContentView.handleHardwareKey`, not the menu.

			Button("Recall Answer") {
				if vm.mode == .calc { vm.recallResult() }
			}
			.keyboardShortcut("a", modifiers: .option)

			Divider()

			// MARK: Run Mode
			Text("Run")

			/// Tab toggles focus between In and Out point fields.
			Button("Tab In/Out") {
				if vm.mode == .run {
					withAnimation {
						if vm.activeRunField == .inPoint {
							vm.activeRunField = .outPoint
						} else {
							vm.activeRunField = .inPoint
						}
					}
				}
			}
			.keyboardShortcut(.tab, modifiers: [])

			/// Cmd-Return adds the current In and Out points to a new segment.
			Button("Add Segment") {
				if vm.mode == .run { withAnimation { vm.addSegment() } }
			}
			.keyboardShortcut(.return, modifiers: .command)

			/// Cmd-Delete clears both In and Out points.
			Button("Clear In/Out") {
				if vm.mode == .run {
					withAnimation {
						vm.runInString = ""
						vm.runOutString = ""
						vm.activeRunField = .inPoint
					}
				}
			}
			.keyboardShortcut(.delete, modifiers: .command)

			/// Cmd-Shift-C copies the total run time of all segments.
			Button("Copy Total Run Time") {
				if vm.mode == .run {
					UIPasteboard.general.string = vm.runTotalString
				}
			}
			.keyboardShortcut("c", modifiers: [.command, .shift])
		}
	}
}

import SwiftUI

// MARK: - KEY PRESS HANDLER
//
// Menubar commands & keyboard (with modifier) commands are defined here.
// Bare keyboard commands are captured by ContentView.handleBareKeyPress
// instead. The two files own disjoint key sets.

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
		// Our own Copy/Paste, so ⌘-C copies the active value
		// and ⌘-V pastes a string into the current field.

		CommandGroup(replacing: .pasteboard) {
			Button("Copy") {
				UIPasteboard.general.string = vm.valueToCopy
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
		// Our own Undo, so ⌘-Z works everywhere regardless of focus.

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

			// MARK: Calc mode
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

			Button("Equals") {
				if vm.mode == .calc { vm.calculateResult() }
			}
			.keyboardShortcut("=", modifiers: [])

			// Return (Calc: equals; Run: add segment) is handled in handleBareKeyPress.

			Button("Recall Answer") {
				if vm.mode == .calc { vm.recallResult() }
			}
			.keyboardShortcut("a", modifiers: .option)

			Divider()

			// MARK: Run mode
			Text("Run")

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

			Button("Add Segment") {
				if vm.mode == .run { withAnimation { vm.addSegment() } }
			}
			.keyboardShortcut(.return, modifiers: .command)

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

			Button("Copy Total Run Time") {
				if vm.mode == .run {
					UIPasteboard.general.string = vm.runTotalString
				}
			}
			.keyboardShortcut("c", modifiers: [.command, .shift])
		}
	}
}

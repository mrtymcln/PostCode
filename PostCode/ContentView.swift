import StoreKit
import SwiftUI

// MARK: - CONTENT VIEW

struct ContentView: View {
	@Bindable var vm: AppViewModel

	/// Focus state for hardware keyboard capture. Set to true on appear
	/// so key presses are routed to handleHardwareKey immediately.
	@FocusState private var isViewFocused: Bool

	/// Controls the easter egg visibility.
	@State private var showBolt = false

	/// Editing of the segment list in Run mode.
	@State private var runListEditMode: EditMode = .inactive

	@Environment(\.requestReview) var requestReview
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass

	/// True on iPad and Mac devices. Drives layout decisions.
	private var isPad: Bool { horizontalSizeClass == .regular }

	// MARK: - BODY

	var body: some View {
		GeometryReader { geo in
			let useSidebarLayout = isPad && geo.size.width > geo.size.height
			ZStack {
				Color.black.ignoresSafeArea()

				if useSidebarLayout {
					IpadLayout(
						vm: vm,
						runListEditMode: $runListEditMode,
						isViewFocused: $isViewFocused,
						width: geo.size.width,
						height: geo.size.height
					)
				} else {
					IphoneLayout(
						vm: vm,
						runListEditMode: $runListEditMode,
						isViewFocused: $isViewFocused,
						width: geo.size.width,
						height: geo.size.height
					)
				}
			}
			// Inject available height into the environment so child views
			// (KeypadView, RunInputArea) can scale their spacing responsively.
			.environment(\.availableHeight, geo.size.height)
			.task {
				// Brief delay ensures the view hierarchy is fully mounted
				// before requesting focus — prevents dropped key events.
				try? await Task.sleep(for: .seconds(0.1))
				isViewFocused = true
			}
			.focusable(true)
			.focused($isViewFocused)
			.focusEffectDisabled()
			.onKeyPress { press in handleHardwareKey(press) }
		}
		.ignoresSafeArea(.keyboard)

		// MARK: Exit List Edit On State Change
		.onChange(of: vm.mode) { _, _ in
			Task { @MainActor in
				runListEditMode = .inactive
			}
		}

		// MARK: Easter Egg Trigger
		.onChange(of: vm.showEasterEgg) { _, show in
			if show {
				withAnimation(.easeIn(duration: 0.2)) { showBolt = true }
				Task { @MainActor in
					try? await Task.sleep(for: .seconds(1.5))
					withAnimation(.easeOut(duration: 0.5)) { showBolt = false }
					vm.showEasterEgg = false
				}
			}
		}

		// MARK: App Store Review Prompt
		.onChange(of: vm.calculationCount) { _, count in
			if count == 10 || count == 50 {
				requestReview()
			}
		}

		// MARK: Sensory Feedback Bindings
		.sensoryFeedback(.selection, trigger: vm.mode)
		.sensoryFeedback(.error, trigger: vm.errorShakeTrigger)
		.sensoryFeedback(.success, trigger: vm.calculationCount)

		// MARK: Welcome Sheet
		.sheet(isPresented: $vm.showWelcomeSheet) {
			WelcomeView(onContinue: { vm.markWelcomeComplete() })
				.interactiveDismissDisabled()
				.preferredColorScheme(.dark)
		}

		// MARK: Custom Frame Rate Alert
		.alert("Custom frame rate", isPresented: $vm.showCustomFpsAlert) {
			TextField(" 1-999", text: $vm.customFpsInput).keyboardType(
				.decimalPad
			)
			Button("Cancel", role: .cancel) {}
			Button("OK") {
				let codes = ["14", "88", "1488"]
				if codes.contains(vm.customFpsInput) {
					vm.triggerEasterEgg()
				}
				if let val = Double(vm.customFpsInput), val >= 1, val <= 999 {
					vm.changeFrameRate(to: FrameRate.custom(val))
				} else {
					vm.triggerErrorShake()
				}
				vm.customFpsInput = ""
			}
		}

		// MARK: Clear Confirmation Alert
		.alert(
			"Clear all?",
			isPresented: $vm.showClearAlert
		) {
			Button("Cancel", role: .cancel) {}
			Button("Clear", role: .destructive) {
				vm.clearAll()
			}
		}

		// MARK: Easter Egg View
		.overlay(
			Group {
				if showBolt {
					Text("⚡️").font(.system(size: 200)).shadow(
						color: .orange,
						radius: 20
					)
					.transition(.opacity).zIndex(100)
				}
			}
		)

		// MARK: Shake To Undo
		.onShake { vm.requestUndo() }

		// MARK: Undo Confirmation Alert
		.alert("Undo \(vm.undoActionLabel)?", isPresented: $vm.showUndoAlert) {
			Button("Undo") { withAnimation { vm.undo() } }
			Button("Cancel", role: .cancel) {}
		}
	}

	// MARK: - HARDWARE KEYBOARD HANDLER
	// Routes hardware key presses to ViewModel actions. This handler covers
	// keys that the menu bar system (AppCommands.swift) can not intercept.
	// Modifiers are checked first (Cmd, Opt), then operators, then digits, then
	// special keys (Delete, Return, Tab).

	func handleHardwareKey(_ press: KeyPress) -> KeyPress.Result {
		let char = press.characters
		let mods = press.modifiers

		// MARK: Cmd+digit — mode switch (any mode)
		if mods.contains(.command) {
			switch char {
			case "1":
				withAnimation { vm.mode = .calc }
				return .handled
			case "2":
				withAnimation { vm.mode = .run }
				return .handled
			case "3":
				withAnimation { vm.mode = .conv }
				return .handled
			default: break
			}
		}

		// MARK: Opt+letter — app actions (any mode)
		// `ç` and `å` are the characters macOS produces for Opt-C and Opt-A.
		if mods.contains(.option) {
			switch char {
			case "t", "T":
				withAnimation { vm.toggleDisplayMode() }
				return .handled
			case "c", "C", "ç":
				vm.handleTrashTap()
				return .handled
			case "a", "A", "å":
				if vm.mode == .calc { vm.recallResult() }
				return .handled
			default: break
			}
		}

		// MARK: Calc mode operators
		if vm.mode == .calc {
			// Opt+- negates the current input
			if mods.contains(.option) && (char == "-" || char == "–") {
				vm.toggleNegate()
				return .handled
			}
			switch char {
			case "+":
				vm.setOperation(.add)
				return .handled
			case "=" where mods.contains(.shift):
				// Shift-= produces "+" on US keyboards
				vm.setOperation(.add)
				return .handled
			case "*":
				vm.setOperation(.multiply)
				return .handled
			case "-":
				vm.setOperation(.subtract)
				return .handled
			case "/":
				vm.setOperation(.divide)
				return .handled
			case "=":
				vm.calculateResult()
				return .handled
			default: break
			}
		}

		// MARK: Digits (no Shift, no Cmd)
		if !mods.contains(.shift) && !mods.contains(.command)
			&& "0123456789".contains(char)
		{
			vm.addDigit(char)
			return .handled
		}

		// MARK: Special keys
		switch press.key {
		case .delete:
			if mods.contains(.command) && vm.mode == .run {
				// Cmd+Delete clears both In and Out fields
				withAnimation {
					vm.runInString = ""
					vm.runOutString = ""
					vm.activeRunField = .inPoint
				}
			} else {
				vm.backspace()
			}
			return .handled

		case .return:
			if vm.mode == .calc {
				vm.calculateResult()
			} else if vm.mode == .run {
				withAnimation { vm.addSegment() }
			}
			return .handled

		case .tab where vm.mode == .run:
			Task { @MainActor in
				withAnimation {
					vm.activeRunField =
						(vm.activeRunField == .inPoint) ? .outPoint : .inPoint
				}
			}
			return .handled

		default: break
		}

		// Some keyboards emit \r or \n directly instead of `.return`.
		if char == "\r" || char == "\n" {
			if vm.mode == .calc {
				vm.calculateResult()
			} else if vm.mode == .run {
				withAnimation { vm.addSegment() }
			}
			return .handled
		}

		return .ignored
	}
}

// MARK: - IPAD LAYOUT

private struct IpadLayout: View {
	var vm: AppViewModel
	@Binding var runListEditMode: EditMode
	@FocusState.Binding var isViewFocused: Bool
	let width: CGFloat
	let height: CGFloat

	var body: some View {
		let contentWidth = width - AppTheme.sidebarTotalWidth
		let leftPaneWidth = (contentWidth * 0.60) + AppTheme.sidebarLeadingPad
		let rightPaneWidth = (contentWidth * 0.40) - AppTheme.sidebarLeadingPad

		HStack(spacing: 0) {
			AppSidebar(vm: vm)
			Rectangle().fill(Color(UIColor.systemGray6)).frame(width: 1)
				.opacity(0.15)

			HStack(spacing: 0) {

				// MARK: Left Pane
				ZStack {
					Color.black.ignoresSafeArea()
					VStack {
						Group {
							if vm.mode == .calc {
								CalculatorView(vm: vm).transition(.slideAndFade)
							} else if vm.mode == .run {
								RunView(vm: vm, editMode: $runListEditMode)
									.transition(.slideAndFade)
							} else {
								ConverterView(vm: vm).transition(.slideAndFade)
							}
						}
					}
					.frame(maxWidth: min(800, leftPaneWidth - 40))
					.padding(.top, 30)
					.padding(.bottom, 50)
					.padding(.horizontal, 24)
				}
				.frame(width: leftPaneWidth, height: height)
				.contentShape(Rectangle())
				// onTapGesture kept: this refocuses the hardware-keyboard
				// FocusState when the user taps anywhere on the layout.
				// Wrapping the ZStack in a Button would consume taps from
				// CalcButton/context menus inside CalculatorView etc.
				.onTapGesture { isViewFocused = true }
				.animation(
					.spring(response: 0.35, dampingFraction: 0.8),
					value: vm.mode
				)

				Rectangle().fill(Color(UIColor.systemGray6)).frame(width: 1)
					.opacity(0.15)

				// MARK: Right Pane
				VStack(spacing: 0) {
					AppHeader(
						vm: vm,
						runListEditMode: $runListEditMode,
						isPad: true
					)
					.padding(.vertical, 30).padding(.horizontal, 30)
					.zIndex(10)
					Spacer()
					if vm.mode == .run {
						RunInputArea(vm: vm, editMode: $runListEditMode)
							.padding(.bottom, 30).padding(.horizontal, 30)
							.transition(
								.move(edge: .bottom).combined(with: .opacity)
							)
					}
					let keypadW = min(rightPaneWidth, 420)
					KeypadView(vm: vm, width: keypadW)
						.frame(width: keypadW).padding(.bottom, 50)
				}
				.frame(width: rightPaneWidth, height: height)
				.background(Color.black)
			}
		}
	}
}

// MARK: - IPHONE LAYOUT

private struct IphoneLayout: View {
	var vm: AppViewModel
	@Binding var runListEditMode: EditMode
	@FocusState.Binding var isViewFocused: Bool
	let width: CGFloat
	let height: CGFloat

	var body: some View {
		let runInputPadBottom = AppTheme.scaled(
			compact: 6,
			regular: 10,
			forHeight: height
		)
		let keypadPadBottom = AppTheme.scaled(
			compact: 10,
			regular: 20,
			forHeight: height
		)
		let headerPadBottom = AppTheme.scaled(
			compact: 0,
			regular: 8,
			forHeight: height
		)

		VStack(spacing: 0) {

			// MARK: Top Pane
			ZStack {
				if vm.mode == .calc {
					CalculatorView(vm: vm).transition(.slideAndFade)
				} else if vm.mode == .run {
					RunView(vm: vm, editMode: $runListEditMode).transition(
						.slideAndFade
					)
				} else {
					ConverterView(vm: vm).transition(.slideAndFade)
				}
			}
			.animation(
				.spring(response: 0.35, dampingFraction: 0.8),
				value: vm.mode
			)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.contentShape(Rectangle())
			// onTapGesture kept: see the iPad layout comment — same reason.
			.onTapGesture { isViewFocused = true }
			.padding(.horizontal, 12)
			.padding(.bottom, 10)
			.zIndex(0)

			// MARK: Bottom Pane
			if runListEditMode == .inactive {
				VStack(spacing: 0) {
					if vm.mode == .run {
						RunInputArea(vm: vm, editMode: $runListEditMode)
							.padding(.horizontal, 12)
							.padding(.bottom, runInputPadBottom)
					}
					KeypadView(vm: vm, width: width)
						.padding(.bottom, keypadPadBottom)
				}
				.background(Color.black)
				.transition(.move(edge: .bottom))
				.zIndex(1)
			}
		}
		.frame(width: width)
		.animation(.easeInOut(duration: 0.35), value: runListEditMode)
		.safeAreaInset(edge: .top) {
			AppHeader(vm: vm, runListEditMode: $runListEditMode, isPad: false)
				.padding(.top, 0)
				.padding(.bottom, headerPadBottom)
				.background(Color.black)
				.zIndex(20)
		}
	}
}

// MARK: - CUSTOM TRANSITION

extension AnyTransition {
	/// Slide-and-fade used for mode switching animations.
	/// Insertion slides in from the trailing edge;
	/// Removal scales down slightly then fades.
	static var slideAndFade: AnyTransition {
		.asymmetric(
			insertion: .move(edge: .trailing).combined(with: .opacity),
			removal: .scale(scale: 0.95).combined(with: .opacity)
		)
	}
}

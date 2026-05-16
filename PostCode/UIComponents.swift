import AudioToolbox
import SwiftUI

// MARK: - APP THEME

struct AppTheme {

	// MARK: Colour Palette
	static let darkGrey = Color(white: 0.2)
	static let lightGrey = Color(white: 0.6)
	static let orange = Color(red: 1.0, green: 0.584, blue: 0.0)  // #FF9500
	static let green = Color(red: 0.0, green: 1.0, blue: 0.0)  // #00FF00

	// MARK: Dimensions
	static let cornerRadius: CGFloat = 12

	// MARK: iPad Sidebar Layout
	static let sidebarButtonWidth: CGFloat = 78
	static let sidebarLeadingPad: CGFloat = 24
	static let sidebarTotalWidth: CGFloat =
		sidebarButtonWidth + sidebarLeadingPad

	// MARK: Responsive Scaling
	/// Linearly interpolates between two values based on available height.
	/// Returns `compact` at 600pt or below, `regular` at 850pt or above,
	/// and smoothly scales between.
	///
	/// Used throughout the app for spacing, padding, and font sizes so the
	/// layout adapts gracefully from iPhone SE (667pt) to iPad Pro (1366pt).
	static func scaled(
		compact: CGFloat,
		regular: CGFloat,
		forHeight height: CGFloat
	) -> CGFloat {
		let t = min(1.0, max(0.0, (height - 600) / 250))
		return compact + (regular - compact) * t
	}
}

// MARK: - HERO TEXT
/// Derives font size from available width so timecode and frame count
/// always render at the same point size — no jumps when changing views,
/// and no truncation on small devices.
///
/// Uses a background GeometryReader for width measurement so the Text
/// retains its intrinsic height and parent containers size correctly.
///
/// The `referenceChars` parameter controls how many characters the layout
/// should accommodate. Defaults to 12 (e.g. "=00:00:00:00"), which is
/// the longest string the calculator hero line can display.
struct HeroText: View {
	let text: String
	var color: Color = .white

	/// Longest reference string the layout should accommodate.
	var referenceChars: Int = 12

	@Environment(\.horizontalSizeClass) private var sizeClass
	private var isPad: Bool { sizeClass == .regular }
	private var maxSize: CGFloat { isPad ? 70 : 44 }

	/// SF Mono glyph advance ≈ 0.6 × point size; 0.62 adds breathing room
	private let glyphRatio: CGFloat = 0.62

	@State private var measuredWidth: CGFloat = 350

	private var fontSize: CGFloat {
		min(measuredWidth / (CGFloat(referenceChars) * glyphRatio), maxSize)
	}

	var body: some View {
		Text(text)
			.font(
				.system(size: fontSize, weight: .semibold, design: .monospaced)
			)
			.foregroundStyle(color)
			.lineLimit(1)
			.fixedSize(horizontal: false, vertical: true)
			.frame(maxWidth: .infinity, alignment: .trailing)
			// AGENTS.md prefers `onGeometryChange` over `GeometryReader`
			// for self-measurement. Fires once on appear and again on
			// each width change — no need for a background measuring view.
			.onGeometryChange(for: CGFloat.self) { proxy in
				proxy.size.width
			} action: { newWidth in
				measuredWidth = newWidth
			}
	}
}

// MARK: - AVAILABLE HEIGHT ENVIRONMENT KEY
/// Custom environment key that propagates the root GeometryReader's height
/// down to child views so they can scale spacing responsively without each
/// needing their own GeometryReader.
private struct AvailableHeightKey: EnvironmentKey {
	static let defaultValue: CGFloat = 850
}

extension EnvironmentValues {
	var availableHeight: CGFloat {
		get { self[AvailableHeightKey.self] }
		set { self[AvailableHeightKey.self] = newValue }
	}
}

// MARK: - ANIMATION MODIFIERS
/// Horizontal shake animation triggered by an error.
/// Replicates the 'head shake' from the Tiger era.

struct ShakeEffect: ViewModifier {
	var trigger: Int

	func body(content: Content) -> some View {
		content
			.keyframeAnimator(
				initialValue: 0.0,
				trigger: trigger
			) { content, value in
				content.offset(x: value)
			} keyframes: { _ in
				MoveKeyframe(0.0)
				CubicKeyframe(-16.0, duration: 0.07)
				CubicKeyframe(16.0, duration: 0.07)
				CubicKeyframe(-12.0, duration: 0.07)
				CubicKeyframe(12.0, duration: 0.07)
				CubicKeyframe(-6.0, duration: 0.07)
				CubicKeyframe(6.0, duration: 0.07)
				CubicKeyframe(0.0, duration: 0.07)
			}
	}
}

extension View {
	/// Usage: `.shake(trigger: vm.errorShakeTrigger)`
	func shake(trigger: Int) -> some View {
		modifier(ShakeEffect(trigger: trigger))
	}
}

// MARK: - BOUNCY BUTTONS ON KEYPAD

struct BouncyButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.scaleEffect(configuration.isPressed ? 0.92 : 1.0)
			.animation(
				.interactiveSpring(response: 0.2, dampingFraction: 0.6),
				value: configuration.isPressed
			)
			.opacity(configuration.isPressed ? 0.8 : 1.0)
	}
}

// MARK: - KEYPAD BUTTON
/// The `isActive` flag inverts colours to indicate a selected operator.
/// Uses the AudioToolbox for keyboard click for digits, backspace and modifiers.
/// Uses the .sensoryFeedback for light haptics.
struct CalcButton: View {
	let label: String
	var systemImage: String? = nil
	let color: Color
	var textColor: Color = .white
	var customSize: CGFloat? = nil
	var customWidth: CGFloat? = nil
	var customHeight: CGFloat? = nil
	var isActive: Bool = false
	let action: () -> Void

	@State private var feedbackTrigger = false

	// MARK: Sound Selection
	///	1123: digits
	///	1155: delete
	///	1156: operators, AC, Ans, etc.
	private var soundID: SystemSoundID {
		if label == "Backspace" || systemImage == "delete.left" {
			return 1155
		}
		if ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "00"].contains(
			label
		) {
			return 1123
		}
		return 1156
	}

	// MARK: VoiceOver Label
	private var accessibilityText: String {
		switch label {
		case "00": return "Double zero"
		case "AC": return "All clear"
		case "Ans": return "Recall answer"
		case "Negate": return "Toggle negative"
		case "Plus": return "Add"
		case "Minus": return "Subtract"
		case "Multiply": return "Multiply"
		case "Divide": return "Divide"
		case "Equals": return "Equals"
		case "Add": return "Add segment"
		default: return label
		}
	}

	// MARK: Body
	var body: some View {
		// Haptics fire for operators, modifiers, and equals only —
		// not digits or delete, matching iOS 26 Calculator behaviour.
		let wantsHaptic = soundID == 1156

		Button(action: {
			AudioServicesPlaySystemSound(soundID)
			if wantsHaptic { feedbackTrigger.toggle() }
			action()
		}) {
			ZStack {
				if isActive {
					Color.white
				} else {
					color
				}

				// MARK: Optical Sizing
				// SF Symbols and text labels have different visual density
				// at the same point size. These ratios equalise them so
				// mixed rows (e.g. [AC] [±] [Ans] [÷]) feel uniform.
				//   • SF Symbols:   0.42 × height, .medium weight
				//   • Single chars: 0.45 × height, .regular weight  (digits)
				//   • Multi chars:  0.36 × height, .medium weight   (AC, Ans, 00)
				let h = customHeight ?? customSize ?? 80

				if let systemImage = systemImage {
					// MARK: Optical Centreing for Delete icon
					let isBackspace = systemImage == "delete.left"
					let opticalOffsetX: CGFloat = isBackspace ? -2.0 : 0.0
					let opticalOffsetY: CGFloat = isBackspace ? -0.5 : 0.0

					Image(systemName: systemImage)
						.font(
							.system(
								size: h * 0.42,
								weight: .medium
							)
						)
						.foregroundStyle(isActive ? color : textColor)
						.offset(x: opticalOffsetX, y: opticalOffsetY)
				} else {
					let isMultiChar = label.count > 1
					Text(label)
						.font(
							.system(
								size: h * (isMultiChar ? 0.36 : 0.45),
								weight: isMultiChar ? .medium : .regular
							)
						)
						.foregroundStyle(isActive ? color : textColor)
				}
			}
			.frame(
				width: customWidth ?? customSize ?? 80,
				height: customHeight ?? customSize ?? 80
			)
			.clipShape(Capsule())
		}
		.buttonStyle(BouncyButtonStyle())
		.accessibilityLabel(accessibilityText)
		.accessibilityAddTraits(isActive ? .isSelected : [])
		.sensoryFeedback(
			.impact(weight: .light, intensity: 1.0),
			trigger: feedbackTrigger
		)
	}
}

// MARK: - PILL/CAPSULE BUTTON

struct PillLabel: View {
	let text: String
	let icon: String
	var color: Color = AppTheme.lightGrey

	var body: some View {
		HStack(spacing: 6) {
			Image(systemName: icon)
				.font(.system(size: 14, weight: .medium))
			Text(text)
				.font(.system(size: 15, weight: .medium))
		}
		.foregroundStyle(.white)
		.padding(.vertical, 8)
		.padding(.horizontal, 16)
		.background(color)
		.clipShape(Capsule())
	}
}

// MARK: - RUN INPUT FIELD

/// The border colour changes to indicate active state and validation:
/// 	Active + valid: green border
/// 	Active + invalid: red border
///		Inactive: grey border
struct RunInputField: View {
	let label: String
	let value: String
	let isActive: Bool
	var activeColor: Color = AppTheme.green

	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(label).font(.caption).bold().foregroundStyle(.white)
			Text(value.isEmpty ? "00:00:00:00" : value)
				.font(.system(.body, design: .monospaced).weight(.regular))
				.foregroundStyle(.white)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(8)
		.background(isActive ? Color.white.opacity(0.1) : Color.clear)
		.clipShape(RoundedRectangle(cornerRadius: 8))
		.overlay(
			RoundedRectangle(cornerRadius: 8)
				.stroke(
					isActive ? activeColor : Color.gray.opacity(0.3),
					lineWidth: isActive ? 2 : 1
				)
		)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("\(label) \(value.isEmpty ? "empty" : value)")
		.accessibilityAddTraits(isActive ? .isSelected : [])
	}
}

// MARK: - FRAME RATE MENU

struct FrameRateMenu<Trigger: View>: View {
	let onSelect: (FrameRate) -> Void
	let onCustom: () -> Void
	@ViewBuilder let label: () -> Trigger

	var body: some View {
		Menu {
			ForEach(FrameRate.allCases) { rate in
				Button(action: { onSelect(rate) }) {
					Text(rate.id)
				}
			}
			Button(action: onCustom) {
				Text("Custom...")
			}
		} label: {
			label()
		}
	}
}

// MARK: - CONVERTER CARD

struct ConverterCard: View {
	let title: String
	let textDisplay: String
	let color: Color  // Orange for source, green for destination
	let frameRate: FrameRate
	let shakeTrigger: Int

	let onSelectRate: (FrameRate) -> Void
	let onCustomRate: () -> Void
	let onCopy: () -> Void
	let onPaste: (() -> Void)?  // read-only for destination

	var body: some View {
		VStack {
			HStack {
				FrameRateMenu(
					onSelect: onSelectRate,
					onCustom: onCustomRate
				) {
					PillLabel(
						text: frameRate.id,
						icon: "chevron.up.chevron.down",
						color: Color.black.opacity(0.3)
					)
				}
				Spacer()
				Text(title).font(.headline).bold().foregroundStyle(
					.white
				)
			}

			HeroText(text: textDisplay, color: color)
				.shake(trigger: shakeTrigger)
				.contextMenu {
					Button(action: onCopy) {
						Label("Copy", systemImage: "doc.on.document")
					}
					if let onPaste = onPaste {
						Button(action: onPaste) {
							Label("Paste", systemImage: "doc.on.clipboard")
						}
					}
				}
		}
		.frame(maxWidth: .infinity)
		.padding()
		.background(AppTheme.darkGrey)
		.clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("\(title) \(frameRate.id), \(textDisplay)")
		.accessibilityHint(
			onPaste != nil
				? "Long press for copy and paste" : "Long press to copy"
		)
	}
}

// MARK: - CUSTOM CALCULATOR ICON

struct CalculatorIcon: View {
	var color: Color = .white

	var body: some View {
		Canvas { context, size in
			let drawW = size.width * 0.70
			let drawH = size.height * 0.90
			let offsetX = (size.width - drawW) / 2
			let offsetY = (size.height - drawH) / 2

			let lineWidth = size.width * 0.08

			// MARK: Calculator Body Outline
			let bodyRect = CGRect(
				x: offsetX,
				y: offsetY,
				width: drawW,
				height: drawH
			)
			let bodyPath = Path(
				roundedRect: bodyRect,
				cornerRadius: drawW * 0.2
			)
			context.stroke(bodyPath, with: .color(color), lineWidth: lineWidth)

			// MARK: Calculator Screen
			let screenW = drawW * 0.65
			let screenH = drawH * 0.18
			let screenRect = CGRect(
				x: offsetX + (drawW - screenW) / 2,
				y: offsetY + (drawH * 0.15),
				width: screenW,
				height: screenH
			)
			context.fill(
				Path(roundedRect: screenRect, cornerRadius: screenH * 0.3),
				with: .color(color)
			)

			// MARK: Calculator Buttons
			let cols = 3
			let rows = 3

			let btnSize = drawW * 0.18
			let gridStartY = offsetY + (drawH * 0.47)
			let gapX = (drawW * 0.5) / 2
			let gapY = drawH * 0.17

			let startX = offsetX + (drawW / 2)

			for r in 0..<rows {
				for c in 0..<cols {
					let colOffset = CGFloat(c - 1)

					let cx = startX + (colOffset * gapX)
					let cy = gridStartY + (CGFloat(r) * gapY)

					let circleRect = CGRect(
						x: cx - btnSize / 2,
						y: cy - btnSize / 2,
						width: btnSize,
						height: btnSize
					)

					context.fill(
						Path(ellipseIn: circleRect),
						with: .color(color)
					)
				}
			}
		}
		.aspectRatio(1, contentMode: .fit)
		.accessibilityHidden(true)
	}
}

// MARK: - SHARE BUTTONS

/// ShareLink wrapper for plain text export.
struct TextShareButton: View {
	let text: String

	var body: some View {
		ShareLink(item: text) {
			Label("Save as TXT", systemImage: "text.document")
		}
	}
}

/// ShareLink wrapper for CSV file export. URL-based ShareLink — the
/// simplest, most cross-platform-compatible path (see the trade-off
/// note on `AppViewModel.generateCSV()` re. Mac Designed-for-iPad).
struct CSVShareButton: View {
	let url: URL

	var body: some View {
		ShareLink(item: url) {
			Label("Save as CSV", systemImage: "tablecells")
		}
	}
}

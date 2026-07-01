import AudioToolbox
import SwiftUI

// MARK: - APP THEME
struct AppTheme {

	// MARK: Colour palette
	static let darkGrey = Color(white: 0.2)
	static let lightGrey = Color(white: 0.6)
	static let orange = Color(red: 1.0, green: 0.584, blue: 0.0)
	static let green = Color(red: 0.0, green: 1.0, blue: 0.0)

	// MARK: Dimensions
	static let cornerRadius: CGFloat = 12

	// MARK: iPad layout
	static let sidebarButtonWidth: CGFloat = 78
	static let sidebarLeadingPad: CGFloat = 24
	static let sidebarTotalWidth: CGFloat =
		sidebarButtonWidth + sidebarLeadingPad

	// MARK: Responsive scaling
	/// Interpolates between `compact` (≤600pt height) and `regular` (≥850pt),
	/// scaling smoothly between them. Used for spacing, padding, and font sizes.
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
/// Sizes its font from available width so TC and FR always render at same point size.
struct HeroText: View {
	let text: String
	var color: Color = .white

	private let referenceChars: CGFloat = 12

	@Environment(\.horizontalSizeClass) private var sizeClass
	private var isPad: Bool { sizeClass == .regular }
	private var maxSize: CGFloat { isPad ? 70 : 44 }

	/// SF Mono glyph advance ≈ 0.6 × point size; 0.62 adds breathing room
	private let glyphRatio: CGFloat = 0.62

	@State private var measuredWidth: CGFloat = 350

	private var fontSize: CGFloat {
		min(measuredWidth / (referenceChars * glyphRatio), maxSize)
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
			// Width-driven font sizing.
			.onWidthChange { measuredWidth = $0 }
	}
}

// MARK: - WIDTH MEASUREMENT
extension View {
	/// Reports this view's width on change. Uses `onGeometryChange` on iOS 18 and later.
	/// Falls back to `GeometryReader` on iOS 17.
	func onWidthChange(_ action: @escaping (CGFloat) -> Void) -> some View {
		modifier(WidthChangeModifier(action: action))
	}
}

private struct WidthChangeModifier: ViewModifier {
	let action: (CGFloat) -> Void

	func body(content: Content) -> some View {
		if #available(iOS 18.0, *) {
			content.onGeometryChange(for: CGFloat.self) { proxy in
				proxy.size.width
			} action: { newWidth in
				action(newWidth)
			}
		} else {
			content.background(
				GeometryReader { proxy in
					Color.clear
						.onAppear { action(proxy.size.width) }
						.onChange(of: proxy.size.width) { _, newWidth in
							action(newWidth)
						}
				}
			)
		}
	}
}

// MARK: - AVAILABLE HEIGHT ENVIRONMENT KEY
/// Propagates the root GeometryReader's height down the view tree, so children
/// can scale spacing without each needing their own GeometryReader.
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
/// 'Head shake' triggered by an error just like the Tiger era.

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

// MARK: - CUSTOM TRANSITION
extension AnyTransition {
	static var slideAndFade: AnyTransition {
		.asymmetric(
			insertion: .move(edge: .trailing).combined(with: .opacity),
			removal: .scale(scale: 0.95).combined(with: .opacity)
		)
	}
}

// MARK: - KEYPAD BUTTON
/// Keypad button. `isActive` inverts the colours for a selected operator.
/// Plays an AudioToolbox click sound.
struct CalcButton: View {
	let label: String
	var systemImage: String?
	let color: Color
	var textColor: Color = .white
	var customWidth: CGFloat?
	var customHeight: CGFloat?
	var isActive: Bool = false
	let action: () -> Void

	@State private var feedbackTrigger = false

	// MARK: Sound selection
	///	1123: digits
	///	1155: delete
	///	1156: operators, AC, Ans, etc.
	private var soundID: SystemSoundID {
		if systemImage == "delete.left" {
			return 1155
		}
		if ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "00"].contains(
			label
		) {
			return 1123
		}
		return 1156
	}

	// MARK: VoiceOver label
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
		case "Update": return "Update segment"
		case "Target": return "Set target run time"
		default: return label
		}
	}

	// MARK: Body
	var body: some View {
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

				// MARK: Optical sizing
				// Different ratios at the same point size to look equally dense:
				//		SF Symbols:   0.42 × height, .medium weight
				//		Single chars: 0.45 × height, .regular weight  (digits)
				//		Multi chars:  0.36 × height, .medium weight   (AC, Ans, 00)
				let h = customHeight ?? 80

				if let systemImage = systemImage {
					// MARK: Optical centring for delete icon
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
				width: customWidth ?? 80,
				height: customHeight ?? 80
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

// MARK: - COPY FORMAT BUTTONS
/// Two context-menu buttons, "Copy as Timecode" and "Copy as Frames", with the
/// current display mode's button listed first.
struct CopyFormatButtons: View {
	let timecode: String
	let frames: String
	let framesModeFirst: Bool
	let onCopied: () -> Void

	var body: some View {
		let timecodeButton = Button {
			UIPasteboard.general.string = timecode
			onCopied()
		} label: {
			Label("Copy as Timecode", systemImage: "clock")
		}
		let framesButton = Button {
			UIPasteboard.general.string = frames
			onCopied()
		} label: {
			Label("Copy as Frames", systemImage: "film")
		}

		if framesModeFirst {
			framesButton
			timecodeButton
		} else {
			timecodeButton
			framesButton
		}
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

/// ShareLink wrapper for CSV export (see the note on `generateCSV()`).
struct CSVShareButton: View {
	let url: URL

	var body: some View {
		ShareLink(item: url) {
			Label("Save as CSV", systemImage: "tablecells")
		}
	}
}

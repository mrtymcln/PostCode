import SwiftUI

// MARK: - WELCOME VIEW
struct WelcomeView: View {
	var onContinue: () -> Void
	@State private var continueTrigger = false

	// MARK: - BODY
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 40) {

				// MARK: Header
				VStack(alignment: .leading, spacing: 4) {
					Text("Welcome to")
						.font(.system(size: 36, weight: .bold))
						.foregroundStyle(.primary)
					Text("PostCode")
						.font(.system(size: 36, weight: .heavy))
						.foregroundStyle(.orange)
				}
				.padding(.top, 64)
				.accessibilityElement(children: .combine)
				.accessibilityAddTraits(.isHeader)

				// MARK: List
				VStack(alignment: .leading, spacing: 20) {
					FeatureRow(
						icon: "",
						isCustomCalculator: true,
						color: .orange,
						title: "Calculator Mode",
						desc: "Add, subtract, multiply, and divide timecode."
					)
					FeatureRow(
						icon: "hand.tap",
						color: .orange,
						title: "Recall and Reuse",
						desc:
							"Tap any line on the calculator tape to drop it into the input."
					)
					FeatureRow(
						icon: "figure.run",
						color: .orange,
						title: "Run Mode",
						desc:
							"Enter In and Out points of multiple segments to calculate total run time."
					)
					FeatureRow(
						icon: "target",
						color: .orange,
						title: "Target Run Time",
						desc:
							"Set a goal duration to see how far over or under you are."
					)
					FeatureRow(
						icon: "square.and.pencil",
						color: .orange,
						title: "Edit Segments",
						desc:
							"Tap to adjust its In or Out point. Touch and hold to reorder or delete."
					)
					FeatureRow(
						icon: "arrow.up.arrow.down",
						color: .orange,
						title: "Converter Mode",
						desc:
							"Cross-convert a timecode between different frame rates."
					)
					FeatureRow(
						icon: "switch.2",
						color: .orange,
						title: "TC/FR",
						desc:
							"Toggle between timecode and frame count — perfect for VFX workflows."
					)
					FeatureRow(
						icon: "film.stack",
						color: .orange,
						title: "Frame Rates",
						desc:
							"Supports all SMPTE standards, and custom frame rates."
					)
					FeatureRow(
						icon: "doc.on.doc",
						color: .orange,
						title: "Copy and Paste",
						desc:
							"Touch and hold to copy and paste — formatting is applied automatically."
					)
					FeatureRow(
						icon: "arrow.uturn.backward",
						color: .orange,
						title: "Undo",
						desc:
							"Shake your iPhone, or press ⌘-Z to undo."
					)
					FeatureRow(
						icon: "square.and.arrow.up",
						color: .orange,
						title: "Export",
						desc:
							"Save as TXT or CSV to share with others, or use in other apps."
					)
				}
			}
			.padding(.horizontal, 32)
			.padding(.bottom, 40)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.scrollIndicators(.visible)

		// MARK: Button
		.safeAreaInset(edge: .bottom) {
			VStack {
				WelcomeContinueButton(
					onContinue: onContinue,
					continueTrigger: $continueTrigger
				)
			}
			.padding(.horizontal, 40)
			.padding(.top, 24)
			.padding(.bottom, 16)
		}
		.sensoryFeedback(.impact(weight: .medium), trigger: continueTrigger)
	}
}

// MARK: - CONTINUE BUTTON
private struct WelcomeContinueButton: View {
	let onContinue: () -> Void
	@Binding var continueTrigger: Bool

	var body: some View {
		let button = Button(action: {
			continueTrigger.toggle()
			onContinue()
		}) {
			Text("Continue").frame(maxWidth: 400)
		}
		.buttonStyle(.borderedProminent)
		.controlSize(.large)
		.tint(.orange)
		.fontWeight(.bold)

		if #available(iOS 26.0, *) {
			button.glassEffect(.regular.tint(.orange.opacity(0.8)).interactive())
		} else {
			button
		}
	}
}

// MARK: - FEATURE ROW
/// The icon column has a fixed 40pt width, so all text blocks align perfectly.
struct FeatureRow: View {
	let icon: String
	var isCustomCalculator: Bool = false
	let color: Color
	let title: String
	let desc: String

	var body: some View {
		HStack(alignment: .top, spacing: 16) {

			// MARK: Icon column
			Group {
				if isCustomCalculator {
					CalculatorIcon(color: color)
						.frame(width: 32, height: 32)
				} else {
					Image(systemName: icon)
						.font(.system(size: 32, weight: .regular))
						.foregroundStyle(color)
				}
			}
			.frame(width: 40, alignment: .center)

			// MARK: Text column
			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.headline)
					.foregroundStyle(.primary)
					.accessibilityAddTraits(.isHeader)

				Text(desc)
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
					.lineLimit(nil)
			}
			.padding(.top, 0)
		}
	}
}

#Preview {
	WelcomeView(onContinue: {})
}

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
						icon: "figure.run",
						color: .orange,
						title: "Run Mode",
						desc:
							"Enter In and Out points of multiple segments to calculate total run time."
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
							"Long-press to copy and paste. Correct formatting is automatically applied."
					)
					FeatureRow(
						icon: "arrow.uturn.backward",
						color: .orange,
						title: "Undo",
						desc:
							"Shake your iPhone or press ⌘-Z to undo any destructive action."
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
			.padding(.horizontal, 24)
			.padding(.top, 24)
			.padding(.bottom, 16)
			.background(.ultraThinMaterial)
		}
		.sensoryFeedback(.impact(weight: .medium), trigger: continueTrigger)
	}
}

// MARK: - CONTINUE BUTTON

private struct WelcomeContinueButton: View {
	let onContinue: () -> Void
	@Binding var continueTrigger: Bool

	var body: some View {
		let baseButton = Button(action: {
			continueTrigger.toggle()
			onContinue()
		}) {
			Text("Continue")
				.font(.body.weight(.bold))
				.frame(maxWidth: .infinity)
				.padding(.vertical, 14)
		}
		.buttonStyle(.borderedProminent)
		.tint(.orange)
		.clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

		if #available(iOS 26.0, *) {
			baseButton
				.glassEffect(.regular.tint(.orange.opacity(0.8)).interactive())
		} else {
			baseButton
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

			// MARK: Icon Column
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

			// MARK: Text Column
			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.headline)
					.foregroundStyle(.primary)

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

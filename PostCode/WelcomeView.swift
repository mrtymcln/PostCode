import SwiftUI

struct WelcomeView: View {
    var onContinue: () -> Void

// MARK: - MAIN VIEW
    private let appOrange = Color(red: 1.0, green: 0.584, blue: 0.0)

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 32) {
                        // Heading
                        VStack(spacing: 16) {
                            Image("AppImage")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .cornerRadius(22)

                            VStack(spacing: 8) {
                                Text("Welcome to PostCode")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)

                                // Keep the original header text if desired, or remove if redundant
                                Text(
                                    "Created by Marty McLean\nNew in version 1.1"
                                )
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 40)

                        // New features
                        VStack(alignment: .leading, spacing: 24) {

                            FeatureRow(
                                icon: "document.on.document",
                                color: .blue,
                                secondaryColor: .white,
                                title: "Copy and Paste",
                                desc:
                                    "Long-press to copy and paste. PostCode will format automatically."
                            )
                            FeatureRow(
                                icon: "square.and.arrow.up",
                                color: .white,
                                secondaryColor: .blue,
                                title: "Export",
                                desc:
                                    "Save your calculations as TXT or CSV files, for use in external apps."
                            )

                            // Standard features
                            Text("Plus these five standard features")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                            FeatureRow(
                                icon: "plus.circle",
                                color: .white,
                                secondaryColor: .blue,
                                title: "Calculator Mode",
                                desc:
                                    "Add, subtract, multiply, and divide timecodes with history."
                            )
                            FeatureRow(
                                icon: "figure.run.circle",
                                color: .white,
                                secondaryColor: .blue,
                                title: "Run Mode",
                                desc:
                                    "Enter In and Out points of multiple segments to calculate the total run time."
                            )
                            FeatureRow(
                                icon: "arrow.up.arrow.down.circle",
                                color: .white,
                                secondaryColor: .blue,
                                title: "Converter Mode",
                                desc:
                                    "Instantly cross-convert timecodes between different frame rates."
                            )
                            FeatureRow(
                                icon: "switch.2",
                                color: .blue,
                                secondaryColor: .white,
                                title: "TC / Fr",
                                desc:
                                    "Toggle between timecode and frame count — perfect for VFX workflows."
                            )
                            FeatureRow(
                                icon: "film.stack",
                                color: .blue,
                                secondaryColor: .white,
                                title: "Frame Rates",
                                desc:
                                    "Supports all SMPTE standard frame rates, as well as custom frame rates."
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }

                // Continue button
                VStack {
                    Divider().background(Color.gray.opacity(0.3))

                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(
                            style: .medium
                        )
                        generator.impactOccurred()
                        onContinue()
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.blue)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                .background(Color.black.opacity(0.20))
            }
        }
    }
}

// MARK: - SUBVIEWS

struct FeatureRow: View {
    let icon: String
    let color: Color
    var secondaryColor: Color? = nil  // 1. Add optional second color
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                // Palette if two colours allowed, otherwise Monochrome
                .symbolRenderingMode(
                    secondaryColor != nil ? .palette : .monochrome
                )
                // Apply the colours
                .foregroundStyle(color, secondaryColor ?? color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
            }
        }
    }
}

// MARK: - CANVAS

#Preview {
    WelcomeView(onContinue: {})
        .preferredColorScheme(.dark)
}

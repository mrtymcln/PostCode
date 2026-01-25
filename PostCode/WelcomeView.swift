import SwiftUI

struct WelcomeView: View {
    // This closure lets the parent AppViewModel know when the user is done.
    var onContinue: () -> Void

// MARK: - SHEET

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Image("AppImage")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .cornerRadius(25)
                        .shadow(radius: 5)

                    Text("Welcome to PostCode")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Created by Marty McLean")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 10) {
                        FeatureRow(
                            icon: "plus.circle",
                            title: "Calculator Mode",
                            desc:
                                "Add, subtract, multiply, and divide timecodes."
                        )
                        FeatureRow(
                            icon: "figure.run",
                            title: "Run Mode",
                            desc:
                                "Enter In and Out points of multiple segments to calculate the total run time."
                        )
                        FeatureRow(
                            icon: "arrow.up.arrow.down",
                            title: "Converter Mode",
                            desc:
                                "Cross-convert timecodes between different frame rates."
                        )
                        FeatureRow(
                            icon: "switch.2",
                            title: "TC / Fr",
                            desc:
                                "Toggle between timecode and frame count — perfect for VFX workflows."
                        )
                        FeatureRow(
                            icon: "film.stack",
                            title: "Frame Rates",
                            desc:
                                "Supports all SMPTE standard frame rates, as well as custom frame rates."
                        )
                        FeatureRow(
                            icon: "square.and.arrow.up",
                            title: "Share",
                            desc:
                                "Save all calculations in plain text for easy sharing."
                        )
                    }
                    .padding(.top, 10)
                    .padding(.horizontal)
                }
                .padding()
                .padding(.top, 40)
            }

            VStack {
                Divider()
                Button(action: {
                    // Trigger the save action when clicked
                    onContinue()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
        }
    }
}

// Helper stays in this file since it's only used here.
struct FeatureRow: View {
    let icon: String, title: String, desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
// MARK: - PREVIEW

#Preview {
    ContentView(vm: AppViewModel())
        .preferredColorScheme(.dark)
}

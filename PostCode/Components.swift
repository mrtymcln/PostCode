import AudioToolbox
import SwiftUI

// MARK: - COMPONENTS

struct CalcButton: View {
    let label: String
    var systemImage: String? = nil
    let color: Color
    var textColor: Color = .white
    var customSize: CGFloat? = nil
    var customWidth: CGFloat? = nil
    var isActive: Bool = false
    let action: () -> Void

    // Haptic State
    @State private var feedbackTrigger = false

    // Determine sound based on button type
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

    var body: some View {
        Button(action: {
            // Play sound as per button type
            AudioServicesPlaySystemSound(soundID)
            
            // Trigger button haptics
            feedbackTrigger.toggle()
            
            // Perform button action
            action()
            
        }) {
            ZStack {
                if isActive {
                    Color.white
                } else {
                    color
                }

                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 40, weight: .regular))
                        .foregroundColor(isActive ? color : textColor)
                } else {
                    Text(label)
                        .font(.system(size: 40, weight: .regular))
                        .foregroundColor(isActive ? color : textColor)
                }
            }
            .frame(
                width: customWidth ?? customSize ?? 80,
                height: customSize ?? 80
            )
            .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .sensoryFeedback(
            .impact(weight: .light, intensity: 1.0),
            trigger: feedbackTrigger
        )
    }
}

struct PillLabel: View {
    let text: String
    let icon: String
    var color: Color = Color(UIColor.systemGray5)

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text).fontWeight(.semibold)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color)
        .foregroundColor(.white)
        .cornerRadius(20)
    }
}

struct ShareLink<Label: View>: View {
    let item: String
    let label: () -> Label

    var body: some View {
        Button(action: shareAction) {
            label()
        }
    }

    func shareAction() {
        let av = UIActivityViewController(
            activityItems: [item],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first
            as? UIWindowScene,
            let rootVC = windowScene.windows.first?.rootViewController
        {

            // Fix for iPad Popover
            if let popover = av.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(
                    x: rootVC.view.bounds.midX,
                    y: rootVC.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
            rootVC.present(av, animated: true, completion: nil)
        }
    }
}

struct TRTInputField: View {
    let label: String
    let value: String
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).bold().foregroundColor(.white)
            Text(value.isEmpty ? "00:00:00:00" : value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(isActive ? .green : .white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(isActive ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isActive ? Color.green : Color.gray.opacity(0.3),
                    lineWidth: isActive ? 2 : 1
                )
        )
    }
}

struct WelcomeView: View {
    @Environment(\.dismiss) var dismiss

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

                    Text("Welcome to PostCode").font(.largeTitle).bold()
                        .multilineTextAlignment(.center)
                    Text("Created by Marty McLean").font(.subheadline).bold()
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
                                "Enter the In and Out points of multiple segments to calculate the total run time."
                        )
                        FeatureRow(
                            icon: "arrow.up.arrow.down",
                            title: "Converter Mode",
                            desc:
                                "Cross-convert a timecode between different frame rates."
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
                                "All calculations can be saved in plain text for easy sharing."
                        )
                    }
                    .padding(.top, 10)
                    .padding(.horizontal)
                }
                .padding()
            }

            VStack {
                Divider()
                Button(action: { dismiss() }) {
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

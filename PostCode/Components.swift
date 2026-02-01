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

    // Haptic state.
    @State private var feedbackTrigger = false

    // Determine sound as per button type.
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
            // Play sound as per button type.
            AudioServicesPlaySystemSound(soundID)

            // Trigger button haptics.
            feedbackTrigger.toggle()

            // Perform button action.
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

            // Fix for iPad popover.
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

struct RunInputField: View {
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

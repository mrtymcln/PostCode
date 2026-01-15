import SwiftUI

// MARK: - BUTTON STYLES
struct TactileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

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
    
    private var size: CGFloat {
        if let custom = customSize { return custom }
        let screenW = UIScreen.main.bounds.width
        return screenW > 0 ? (screenW - (5 * 16)) / 4 : 70
    }
    
    private var width: CGFloat { return customWidth ?? size }
    private var backgroundColor: Color { isActive ? .white : color }
    private var foregroundColor: Color { isActive ? color : textColor }
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            ZStack {
                if let _ = customWidth {
                    RoundedRectangle(cornerRadius: 40).fill(backgroundColor)
                } else {
                    Circle().fill(backgroundColor)
                }
                
                if let systemImage = systemImage {
                    Image(systemName: systemImage).font(.system(size: 35, weight: .semibold)).foregroundColor(foregroundColor)
                } else {
                    Text(label).font(.system(size: 40, weight: .medium, design: .rounded)).foregroundColor(foregroundColor)
                }
            }
            .frame(width: width, height: size)
        }
        .buttonStyle(TactileButtonStyle())
    }
}

struct PillLabel: View {
    let text: String
    let icon: String
    var color: Color = Color(UIColor.systemGray5)
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.body)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(color).foregroundColor(.white).clipShape(Capsule())
    }
}

struct TRTInputField: View {
    let label: String
    let value: String
    let isActive: Bool
    private let colorGreen = Color(red: 0.0, green: 0.8, blue: 0.4)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).fontWeight(.bold).foregroundColor(.gray)
            Text(value.isEmpty ? "--:--:--:--" : value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(isActive ? colorGreen : .white)
        }
        .padding(5).frame(maxWidth: .infinity, alignment: .leading)
        .background(isActive ? colorGreen.opacity(0.1) : Color.black.opacity(0.3))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isActive ? colorGreen : Color.clear, lineWidth: 1))
    }
}

struct WelcomeView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 30) {
                    Text("Welcome to PostCode").font(.largeTitle).bold().padding(.top, 40)
                    Text("Created by Marty McLean").font(.title3).bold().padding(.top, 0)
                    VStack(alignment: .leading, spacing: 20) {
                        featureRow(icon: "plus.circle", title: "Calculator Mode", desc: "Add, subtract, multiply, and divide timecodes.")
                        featureRow(icon: "figure.run", title: "Run Mode", desc: "Enter the In and Out points of multiple segments to calculate the total run time.")
                        featureRow(icon: "arrow.up.arrow.down", title: "Converter Mode", desc: "Cross-convert a timecode between different frame rates.")
                        featureRow(icon: "switch.2", title: "TC / Fr", desc: "Instantly toggle between timecode and frame count — perfect for VFX workflows.")
                        featureRow(icon: "film.stack", title: "Frame Rates", desc: "Supports all SMPTE standard frame rates, as well as custom frame rates.")
                        featureRow(icon: "square.and.arrow.up", title: "Share", desc: "All calculations and conversions can be saved as plain text.")
                    }.padding()
                }
            }
            Button(action: { dismiss() }) { Text("Continue").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.blue).cornerRadius(12) }.padding(20)
        }.preferredColorScheme(.dark)
    }
    func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon).font(.largeTitle).foregroundColor(.blue).frame(width: 50)
            VStack(alignment: .leading, spacing: 2) { Text(title).font(.headline); Text(desc).font(.subheadline).foregroundColor(.gray).fixedSize(horizontal: false, vertical: true) }
        }
    }
}

struct EasterEggView: View {
    @State private var scale = 0.1
    @State private var opacity = 1.0
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            Text("⚡️")
                .font(.system(size: 100))
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.5)) {
                        scale = 6.66; opacity = 0.0
                    }
                }
        }
    }
}

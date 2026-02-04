import SwiftUI

// MARK: - THEME CONSTANTS
private struct NavTheme {
    static let darkGrey = Color(white: 0.2)
    static let orange = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let buttonColor = Color(UIColor.systemGray5)
}

// MARK: - IPAD SIDEBAR

struct AppSidebar: View {
    @ObservedObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            sidebarButton(mode: .calc, icon: "plus.circle", label: "Calc")
            sidebarButton(mode: .run, icon: "figure.run", label: "Run")
            sidebarButton(
                mode: .conv,
                icon: "arrow.up.arrow.down",
                label: "Conv"
            )
            Spacer()
        }
        .frame(width: 80)
        .background(Color.black)
        .zIndex(20)
    }

    private func sidebarButton(mode: AppMode, icon: String, label: String)
        -> some View
    {
        Button(action: { withAnimation { vm.mode = mode } }) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 24))
                Text(label).font(.caption2).fontWeight(.bold)
            }
            .frame(width: 60, height: 60)
            .background(vm.mode == mode ? NavTheme.orange : NavTheme.darkGrey)
            .foregroundColor(vm.mode == mode ? .black : .white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - IPHONE HEADER

struct AppHeader: View {
    @ObservedObject var vm: AppViewModel
    let isPad: Bool

    var body: some View {
        HStack(spacing: 8) {
            // A. Mode button
            if !isPad {
                Button(action: { withAnimation { vm.toggleAppMode() } }) {
                    PillLabel(
                        text: vm.getModeLabel(),
                        icon: vm.getModeIcon(),
                        color: NavTheme.buttonColor
                    )
                }
            }

            // B. Frame Rate button
            if vm.mode != .conv {
                Menu {
                    ForEach(FrameRate.allCases) { rate in
                        Button(action: { vm.changeFrameRate(to: rate) }) {
                            if vm.activeFrameRate.id == rate.id {
                                Label(rate.id, systemImage: "checkmark")
                            } else {
                                Text(rate.id)
                            }
                        }
                    }
                    Button(action: { vm.showCustomFpsAlert = true }) {
                        Text("Custom...")
                        if !FrameRate.allCases.contains(where: {
                            $0.id == vm.activeFrameRate.id
                        }) {
                            Image(systemName: "checkmark")
                        }
                    }
                } label: {
                    PillLabel(
                        text: vm.activeFrameRate.id,
                        icon: "chevron.up.chevron.down"
                    )
                }
            }

            // C. Timecode/Frames button
            Button(action: { withAnimation { vm.toggleDisplayMode() } }) {
                PillLabel(
                    text: vm.isFramesMode ? "Fr" : "TC",
                    icon: vm.isFramesMode ? "film" : "clock",
                    color: NavTheme.buttonColor
                )
            }
            .opacity(vm.mode == .run ? 0 : 1).disabled(vm.mode == .run)

            Spacer()

            // D. Share/Delete buttons
            actionButtons
        }
        // Delete alert
        .alert(
            "Clear all? This cannot be undone.",
            isPresented: $vm.showClearAlert
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { vm.clearAll() }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            if vm.mode == .run {
                Menu {
                    TextShareButton(text: vm.exportText)
                    CSVShareButton(url: vm.generateCSV())
                } label: {
                    Image(systemName: "square.and.arrow.up").font(
                        .system(size: 20, weight: .semibold)
                    ).foregroundColor(.white)
                }
            } else {
                ShareLink(item: vm.exportText) {
                    Image(systemName: "square.and.arrow.up").font(
                        .system(size: 20, weight: .semibold)
                    ).foregroundColor(.white)
                }
            }
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                vm.showClearAlert = true
            }) {
                Image(systemName: "trash").font(
                    .system(size: 20, weight: .semibold)
                ).foregroundColor(.red).frame(width: 44, height: 44)
            }
        }
    }
}

import SwiftUI

struct ConverterView: View {
    @ObservedObject var vm: AppViewModel

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var mainDisplaySize: CGFloat { isPad ? 80 : 42 }
    private let colourDarkGrey = Color(white: 0.2)

    var body: some View {
        ScrollView {
            VStack(spacing: isPad ? 48 : 32) {

                // FROM BOX
                VStack {
                    HStack {
                        Menu {
                            ForEach(FrameRate.allCases) { rate in
                                Button(rate.id) { vm.convSourceRate = rate }
                            }
                            Button("Custom...") {
                                // Set target to Source (false)
                                vm.isEditingConverterDest = false
                                vm.showCustomFpsAlert = true
                            }
                        } label: {
                            PillLabel(
                                text: vm.convSourceRate.id,
                                icon: "chevron.up.chevron.down"
                            )
                        }
                        Spacer()
                        Text("FROM:").font(.headline).fontWeight(.bold)
                            .foregroundColor(.white)
                    }

                    Text(vm.getFormattedConvInput())
                        .font(
                            .system(
                                size: mainDisplaySize,
                                weight: .semibold,
                                design: .monospaced
                            )
                        )
                        .foregroundColor(.orange)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .frame(height: isPad ? 90 : 60)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        // Shake head if illegal operation
                        .shake(trigger: vm.errorShakeTrigger)
                        .animation(nil, value: vm.isFramesMode)
                        .contextMenu {
                            Button {
                                vm.pasteFromClipboard()
                            } label: {
                                Label("Paste", systemImage: "paintbrush")
                            }
                        }
                }
                .frame(maxWidth: .infinity).padding().background(colourDarkGrey)
                .cornerRadius(12)

                // TO BOX
                VStack {
                    HStack {
                        Menu {
                            ForEach(FrameRate.allCases) { rate in
                                Button(rate.id) { vm.convDestRate = rate }
                            }
                            Button("Custom...") {
                                // Set target to Dest (true)
                                vm.isEditingConverterDest = true
                                vm.showCustomFpsAlert = true
                            }
                        } label: {
                            PillLabel(
                                text: vm.convDestRate.id,
                                icon: "chevron.up.chevron.down"
                            )
                        }
                        Spacer()
                        Text("TO:").font(.headline).fontWeight(.bold)
                            .foregroundColor(.white)
                    }

                    Text(vm.convResultString)
                        .font(
                            .system(
                                size: mainDisplaySize,
                                weight: .semibold,
                                design: .monospaced
                            )
                        )
                        .foregroundColor(.green)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .frame(height: isPad ? 90 : 60)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        // Shake head if illegal operation
                        .shake(trigger: vm.errorShakeTrigger)
                        .animation(nil, value: vm.isFramesMode)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string =
                                    vm.convResultString
                            } label: {
                                Label(
                                    "Copy",
                                    systemImage: "document.on.document"
                                )
                            }
                        }
                }
                .frame(maxWidth: .infinity).padding().background(colourDarkGrey)
                .cornerRadius(12)

                Spacer()
            }
        }
    }
}

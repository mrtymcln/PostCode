import SwiftUI

struct CalculatorView: View {
    @ObservedObject var vm: AppViewModel
    
    // Local constants
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var mainDisplaySize: CGFloat { isPad ? 80 : 42 }
    private var tapeFontSize: CGFloat { isPad ? 32 : 24 }

    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .trailing, spacing: isPad ? 12 : 8) {
                    Spacer(minLength: 40)

                    // HISTORY LINES
                    ForEach(Array(vm.paperTape.enumerated()), id: \.offset) { index, line in
                        paperTapeRow(index: index, line: line)
                    }

                    // ACTIVE INPUT LINE
                    Text(vm.getFormattedActiveDisplay())
                        .font(.system(size: mainDisplaySize, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(height: isPad ? 100 : 70)
                        .id("bottom")
                        .animation(nil, value: vm.isFramesMode)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = vm.getFormattedActiveDisplay()
                            } label: {
                                Label("Copy", systemImage: "document.on.document")
                            }
                            Button {
                                vm.pasteFromClipboard()
                            } label: {
                                Label("Paste", systemImage: "paintbrush")
                            }
                        }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(20)
                .shake(trigger: vm.errorShakeTrigger)
                .onChange(of: vm.paperTape) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        .background(Color(white: 0.2)) // match colourDarkGrey
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

// MARK: - ROWS & PARSING

    @ViewBuilder
    private func paperTapeRow(index: Int, line: String) -> some View {
        if line.contains("----") {
            Rectangle()
                .fill(Color.primary.opacity(0.2))
                .frame(height: 1)
                .padding(.vertical, 4)
        } else {
            let (op, value, isResult) = parseTapeLine(line)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Spacer()
                
                // OPERATOR
                Text(op)
                    .font(.system(size: tapeFontSize, weight: isResult ? .bold : .regular, design: .monospaced))
                    .foregroundColor(isResult ? .green : .white)
                    .frame(width: 20, alignment: .trailing)
                    .padding(.trailing, 8)

                // VALUE
                Text(value)
                    .font(.system(size: tapeFontSize, weight: isResult ? .bold : .regular, design: .monospaced))
                    .foregroundColor(isResult ? .green : .white)
            }
            .contentShape(Rectangle())
            .contextMenu {
                Button {
                    UIPasteboard.general.string = value
                } label: {
                    Label("Copy", systemImage: "document.on.document")
                }
                Button(role: .destructive) {
                    vm.deleteTapeItem(at: index)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    private func parseTapeLine(_ line: String) -> (String, String, Bool) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.starts(with: "+") { return ("+", String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces), false) }
        else if trimmed.starts(with: "-") { return ("-", String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces), false) }
        else if trimmed.starts(with: "×") || trimmed.starts(with: "x") || trimmed.starts(with: "*") {
            return ("×", String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces), false)
        }
        else if trimmed.starts(with: "÷") || trimmed.starts(with: "/") {
            return ("÷", String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces), false)
        }
        else if trimmed.starts(with: "=") {
            return ("=", String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces), true)
        }
        return ("", trimmed, false)
    }
}

// MARK: - PREVIEW

#Preview {
    CalculatorView(vm: AppViewModel())
        .preferredColorScheme(.dark)
}

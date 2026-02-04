import SwiftUI

struct RunView: View {
    @ObservedObject var vm: AppViewModel
    @Binding var editMode: EditMode

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private let colourDarkGrey = Color(white: 0.2)

    var body: some View {
        VStack(spacing: 0) {
            runHeaderView

            // 1. Wrap List in ScrollViewReader to enable programmatic scrolling
            ScrollViewReader { proxy in
                List {
                    ForEach(vm.runList) { entry in
                        let index =
                            vm.runList.firstIndex(where: { $0.id == entry.id })
                            ?? 0
                        runListRow(index: index, entry: entry)
                            .id(entry.id)  // Assign UUID for the scroller to find
                    }
                    .onDelete(
                        perform: editMode == .active
                            ? nil
                            : { indexSet in
                                vm.runList.remove(atOffsets: indexSet)
                            }
                    )
                    .onMove { source, destination in
                        vm.moveRunSegment(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, $editMode)
                // Scroll to bottom when list grows
                .onChange(of: vm.runList.count) { old, new in
                    if new > old {  // Only scroll if adding
                        withAnimation {
                            proxy.scrollTo(vm.runList.last?.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

// MARK: - SUBVIEWS

    private var runHeaderView: some View {
        HStack {
            Text("TRT:").font(.headline).fontWeight(.bold).foregroundColor(
                .white
            )
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(vm.runTotalString)
                    .font(
                        .system(
                            size: isPad ? 48 : 32,
                            weight: .bold,
                            design: .monospaced
                        )
                    )
                    .foregroundColor(.green)
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = vm.runTotalString
                        } label: {
                            Label("Copy", systemImage: "document.on.document")
                        }
                    }

                if let realTime = vm.runRealTimeString {
                    Text(realTime)
                        .font(
                            .system(size: 14, weight: .medium, design: .rounded)
                        )
                        .foregroundColor(.gray)
                }
            }
            // Shake head if illegal operation
            .shake(trigger: vm.errorShakeTrigger)
        }
        .padding()
        .background(colourDarkGrey)
        .cornerRadius(12)
        .padding(.bottom, 5)
    }

    @ViewBuilder
    private func runListRow(index: Int, entry: Segment) -> some View {
        HStack {
            Text("#\(index + 1)").font(.caption).foregroundColor(.white)
                .frame(width: 30, alignment: .leading)
            VStack(alignment: .leading) {
                Text("IN:  \(entry.inPoint)")
                Text("OUT: \(entry.outPoint)")
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.white)
            Spacer()
            Text(entry.durationString)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.orange)
        }
        .listRowBackground(Color.black)
        .listRowSeparatorTint(.gray)
        .contextMenu {
            Button {
                UIPasteboard.general.string = entry.durationString
            } label: {
                Label("Copy Duration", systemImage: "document.on.document")
            }
            Button {
                let text =
                    "Segment: \(index + 1)\nIn: \(entry.inPoint)\nOut: \(entry.outPoint)\nDur: \(entry.durationString)"
                UIPasteboard.general.string = text
            } label: {
                Label("Copy Details", systemImage: "document.on.document.fill")
            }
            Divider()
            Button {
                withAnimation { editMode = .active }
            } label: {
                Label("Reorder Segment", systemImage: "arrow.up.arrow.down")
            }
            Divider()
            Button(role: .destructive) {
                if vm.runList.indices.contains(index) {
                    vm.runList.remove(at: index)
                }
            } label: {
                Label("Delete Segment", systemImage: "trash")
            }
        }
    }
}

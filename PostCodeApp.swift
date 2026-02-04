// PostCodeApp.swift
import SwiftUI

@main
struct PostCodeApp: App {
    @StateObject private var vm = AppViewModel()
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .background || newPhase == .inactive {
                        vm.saveImmediate()
                    }
                }
        }
    }
}

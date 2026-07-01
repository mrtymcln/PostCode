import SwiftUI

// MARK: - ENTRY POINT
@main
struct PostCodeApp: App {
	@State private var vm = AppViewModel()
	@Environment(\.scenePhase) var scenePhase

	// MARK: - SCENE
	var body: some Scene {
		WindowGroup {
			ContentView(vm: vm)
				.preferredColorScheme(.dark)

				// MARK: Initial load
				.onAppear {
					vm.loadData()
				}

				// MARK: Lifecycle persistence
				.onChange(of: scenePhase) { _, newPhase in
					if newPhase == .background || newPhase == .inactive {
						vm.saveImmediate()
					}
				}
		}

		// MARK: - MENU BAR
		.commands {
			AppCommands(vm: vm)
		}
	}
}

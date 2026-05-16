import SwiftUI

// MARK: - APP ENTRY POINT

@main
struct PostCodeApp: App {
	@State private var vm = AppViewModel()
	@Environment(\.scenePhase) var scenePhase

	// MARK: - SCENE

	var body: some Scene {
		WindowGroup {
			ContentView(vm: vm)
				.preferredColorScheme(.dark)

				// MARK: Initial Load
				.onAppear {
					vm.loadData()
				}

				// MARK: Lifecycle Persistence
				// .background — Standard dismissal
				// .inactive   — Ensure no data loss if never reach .background
				.onChange(of: scenePhase) { oldPhase, newPhase in
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

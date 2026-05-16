import SwiftUI
import UIKit

// MARK: - SHAKE DETECTOR
//
// Detects device shake by overriding `UIWindow.motionEnded(_:with:)` via
// a Swift extension.
//
// The Swift Language Book classifies extension-based overrides of
// open methods as undefined behaviour. We accept this trade-off because:
//
//   1. The documented 'proper' alternative —  a custom `UIWindow` subclass
//		via a `UIWindowSceneDelegate` from a `UIApplicationDelegateAdaptor` —
//		was verified to not work. SwiftUI's `WindowGroup` ignores the scene
// 		delegate's window and creates its own, which never receives motion events.
//
//   2. Switching to manual `UIHostingController` + scene delegate
//      window setup (abandoning `WindowGroup`) would also abandon
//      `.commands` for the menu bar, `@Environment(\.scenePhase)`
//      integration, and multi-window support on iPad. Too much loss
//      for one gesture.
//
//   3. This pattern has been the 'community' approach for SwiftUI shake detection
//		since iOS 13. Apple-published sample code and Paul Hudson's books use it.
//
// The day SwiftUI exposes a first-class shake gesture, this whole file
// goes away. Until then, this is the trade-off.

extension Notification.Name {
	static let postCodeDidShake = Notification.Name("PostCodeDidShake")
}

extension UIWindow {
	open override func motionEnded(
		_ motion: UIEvent.EventSubtype,
		with event: UIEvent?
	) {
		if motion == .motionShake {
			NotificationCenter.default.post(
				name: .postCodeDidShake,
				object: nil
			)
		}
		super.motionEnded(motion, with: event)
	}
}

// MARK: - View Modifier

extension View {
	/// Calls `action` whenever the device shake gesture is detected.
	func onShake(perform action: @escaping () -> Void) -> some View {
		onReceive(
			NotificationCenter.default.publisher(for: .postCodeDidShake)
		) { _ in
			action()
		}
	}
}

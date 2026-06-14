import SwiftUI
import UIKit

// MARK: - SHAKE DETECTOR
// Detects a device shake by overriding `UIWindow.motionEnded` in an extension.
// This is undefined behaviour but the alternatives are worse.

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

// MARK: - VIEW MODIFIER
extension View {
	func onShake(perform action: @escaping () -> Void) -> some View {
		onReceive(
			NotificationCenter.default.publisher(for: .postCodeDidShake)
		) { _ in
			action()
		}
	}
}

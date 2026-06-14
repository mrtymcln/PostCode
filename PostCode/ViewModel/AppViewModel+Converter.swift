import Foundation

extension AppViewModel {

	// MARK: - CONVERSION RESULT
	/// Destination frame count, or nil when the rates give an undefined result
	/// (zero divisor, NaN, infinite). Exposed so the copy menu can offer the raw
	/// count alongside the timecode.
	var convResultFrames: Int? {

		// Same rate in, same rate out. No conversion needed.
		if convSourceRate == convDestRate {
			return framesFromInput(convInputString, fps: convSourceRate)
		}

		let srcFrames = Double(
			framesFromInput(convInputString, fps: convSourceRate)
		)

		let srcBase = Double(convSourceRate.baseFPS)
		let srcMult = convSourceRate.rateMultiplier
		let dstBase = Double(convDestRate.baseFPS)
		let dstMult = convDestRate.rateMultiplier

		// srcBase and dstMult are divisors; a zero in any term gives a wrong result.
		guard srcBase != 0, dstMult != 0, srcMult != 0, dstBase != 0 else {
			return nil
		}

		// destFrames = srcFrames × (srcMult / srcBase) × (dstBase / dstMult)
		// i.e. real seconds per source frame × destination frames per real second.
		let exactFrames = srcFrames * (srcMult / srcBase) * (dstBase / dstMult)
		guard !exactFrames.isNaN, !exactFrames.isInfinite else { return nil }

		// Round to nearest integer — fractional frames don't exist in practice.
		return Int(exactFrames.rounded())
	}

	/// Formatted result (timecode or frame count), or "Error" when undefined.
	var convResultString: String {
		guard let frames = convResultFrames else { return "Error" }
		return displayString(forFrames: frames, fps: convDestRate)
	}
}

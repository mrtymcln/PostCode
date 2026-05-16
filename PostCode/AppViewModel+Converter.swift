import Foundation

extension AppViewModel {

	// MARK: - CONVERSION RESULT

	var convResultString: String {

		// MARK: Identity Short-Circuit
		// Same rate in, same rate out. No conversion needed.
		if convSourceRate == convDestRate { return getFormattedConvInput() }

		// MARK: Parse Source Frames
		let srcFrames: Double
		if isFramesMode {
			srcFrames = Double(Int(convInputString) ?? 0)
		} else {
			srcFrames = Double(
				TimecodeCalculator.inputToFrames(
					input: convInputString,
					fps: convSourceRate
				)
			)
		}

		// MARK: Build Conversion Terms
		let srcBase = Double(convSourceRate.baseFPS)
		let srcMult = convSourceRate.rateMultiplier
		let dstBase = Double(convDestRate.baseFPS)
		let dstMult = convDestRate.rateMultiplier

		// Guard all terms — srcBase and dstMult are divisors,
		// and zero srcMult/dstBase would produce silent wrong results.
		if srcBase == 0 || dstMult == 0 || srcMult == 0 || dstBase == 0 {
			return "Error"
		}

		// MARK: Apply Formula
		// destFrames = srcFrames × (srcMult / srcBase) × (dstBase / dstMult)
		//            = srcFrames × (real seconds per src frame) × (dst frames per real second)
		let exactFrames = srcFrames * (srcMult / srcBase) * (dstBase / dstMult)
		if exactFrames.isNaN || exactFrames.isInfinite { return "Error" }

		// Round to nearest integer — fractional frames don't exist in practice.
		let finalFrames = Int(round(exactFrames))

		// MARK: Format Output
		return isFramesMode
			? "\(finalFrames)"
			: TimecodeCalculator.framesToString(
				totalFrames: finalFrames,
				fps: convDestRate
			)
	}
}

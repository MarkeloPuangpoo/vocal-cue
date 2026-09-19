import Foundation
import Accelerate
import Combine

// MARK: - SpectrumAnalyzer
/// Real-time FFT spectrum analyzer with logarithmic frequency band grouping and smooth peak decay.
public class SpectrumAnalyzer: ObservableObject {
    public static let numberOfBands = 32

    @Published public var magnitudes: [Float] = Array(repeating: 0.0, count: numberOfBands)

    private let fftSize = 1024
    private let log2n: vDSP_Length = 10
    private var fftSetup: FFTSetup?
    private var window: [Float]
    private var sampleBuffer: [Float] = []
    private var bandIndices: [(start: Int, end: Int)] = []
    private var lastUpdateTime: TimeInterval = 0

    // Stored decayed magnitudes for smooth animation
    private var smoothedMagnitudes: [Float] = Array(repeating: 0.0, count: numberOfBands)

    public init() {
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        setupLogarithmicBands(sampleRate: 48000.0)
    }

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    /// Precalculate logarithmic frequency bin ranges (20Hz - 20kHz)
    private func setupLogarithmicBands(sampleRate: Double) {
        bandIndices.removeAll()
        let halfSize = fftSize / 2
        let minFreq: Double = 25.0
        let maxFreq: Double = min(sampleRate / 2.0, 20000.0)

        for band in 0..<SpectrumAnalyzer.numberOfBands {
            let lowRatio = Double(band) / Double(SpectrumAnalyzer.numberOfBands)
            let highRatio = Double(band + 1) / Double(SpectrumAnalyzer.numberOfBands)

            let fLow = minFreq * pow(maxFreq / minFreq, lowRatio)
            let fHigh = minFreq * pow(maxFreq / minFreq, highRatio)

            var binStart = Int(fLow * Double(fftSize) / sampleRate)
            var binEnd = Int(fHigh * Double(fftSize) / sampleRate)

            binStart = max(1, min(binStart, halfSize - 1))
            binEnd = max(binStart + 1, min(binEnd, halfSize))

            bandIndices.append((start: binStart, end: binEnd))
        }
    }

    /// Feed incoming audio samples from tap
    public func process(samples: UnsafePointer<Float>, count: Int, sampleRate: Double) {
        sampleBuffer.append(contentsOf: UnsafeBufferPointer(start: samples, count: count))

        guard sampleBuffer.count >= fftSize else { return }

        let now = ProcessInfo.processInfo.systemUptime
        // Update at ~40 FPS for super smooth graphics with low CPU usage
        guard now - lastUpdateTime >= 0.025 else {
            if sampleBuffer.count > fftSize * 2 {
                sampleBuffer.removeFirst(sampleBuffer.count - fftSize)
            }
            return
        }
        lastUpdateTime = now

        let windowSlice = Array(sampleBuffer.prefix(fftSize))
        sampleBuffer.removeFirst(min(count, sampleBuffer.count))

        computeFFT(samples: windowSlice, sampleRate: sampleRate)
    }

    private func computeFFT(samples: [Float], sampleRate: Double) {
        guard let fftSetup = self.fftSetup, samples.count >= fftSize else { return }

        // 1. Multiply by Hanning window
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // 2. Prepare split complex format
        let halfSize = fftSize / 2
        var realp = [Float](repeating: 0, count: halfSize)
        var imagp = [Float](repeating: 0, count: halfSize)
        var magnitudesSquare = [Float](repeating: 0, count: halfSize)

        realp.withUnsafeMutableBufferPointer { realBP in
            imagp.withUnsafeMutableBufferPointer { imagBP in
                guard let realPtr = realBP.baseAddress, let imagPtr = imagBP.baseAddress else { return }
                var splitComplex = DSPSplitComplex(realp: realPtr, imagp: imagPtr)

                windowed.withUnsafeBytes { rawBuffer in
                    if let floatPtr = rawBuffer.bindMemory(to: DSPComplex.self).baseAddress {
                        vDSP_ctoz(floatPtr, 2, &splitComplex, 1, vDSP_Length(halfSize))
                    }
                }

                // 3. Perform forward in-place real FFT
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                // 4. Calculate squared magnitudes
                vDSP_zvmags(&splitComplex, 1, &magnitudesSquare, 1, vDSP_Length(halfSize))
            }
        }

        // Scale by 1/(4*N)
        var scale = 1.0 / Float(4 * fftSize)
        vDSP_vsmul(magnitudesSquare, 1, &scale, &magnitudesSquare, 1, vDSP_Length(halfSize))

        // 5. Group into logarithmic frequency bands
        var newMagnitudes = [Float](repeating: 0.0, count: SpectrumAnalyzer.numberOfBands)

        for i in 0..<SpectrumAnalyzer.numberOfBands {
            let (startBin, endBin) = bandIndices[i]
            var sum: Float = 0
            let binCount = max(1, endBin - startBin)

            for b in startBin..<endBin {
                sum += magnitudesSquare[b]
            }

            let avgPower = sum / Float(binCount)
            // Convert to dBFS (reference floor -80 dB)
            let db = 10.0 * log10(max(avgPower, 1e-8))
            // Normalize -80 dB ... 0 dB to 0.0 ... 1.0
            let normalized = max(0.0, min(1.0, (db + 75.0) / 75.0))
            newMagnitudes[i] = normalized
        }

        // 6. Smooth falloff decay
        for i in 0..<SpectrumAnalyzer.numberOfBands {
            if newMagnitudes[i] >= smoothedMagnitudes[i] {
                // Instant attack
                smoothedMagnitudes[i] = newMagnitudes[i]
            } else {
                // Smooth exponential release decay
                smoothedMagnitudes[i] = smoothedMagnitudes[i] * 0.78 + newMagnitudes[i] * 0.22
            }
        }

        let result = smoothedMagnitudes
        DispatchQueue.main.async {
            self.magnitudes = result
        }
    }

    public func reset() {
        smoothedMagnitudes = Array(repeating: 0.0, count: SpectrumAnalyzer.numberOfBands)
        DispatchQueue.main.async {
            self.magnitudes = self.smoothedMagnitudes
        }
        sampleBuffer.removeAll()
    }
}

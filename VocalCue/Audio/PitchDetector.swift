import Foundation
import Accelerate
import Combine

// MARK: - PitchDetector
/// Real-time vocal pitch estimation using optimized Accelerate (vDSP) autocorrelation.
/// Operates strictly as an observer/tap on vocal audio without adding audio processing latency.
public class PitchDetector: ObservableObject {
    @Published public var detectedNote: String = "--"
    @Published public var detectedFrequency: Float = 0.0
    @Published public var centsDeviation: Float = 0.0
    @Published public var clarity: Float = 0.0
    @Published public var isVoiced: Bool = false

    private static let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    // Processing buffer parameters
    private let sampleWindowSize = 2048
    private var sampleBuffer: [Float] = []
    private var window: [Float]
    private var lastUpdateTime: TimeInterval = 0

    public init() {
        self.window = [Float](repeating: 0, count: sampleWindowSize)
        vDSP_hann_window(&window, vDSP_Length(sampleWindowSize), Int32(vDSP_HANN_NORM))
    }

    /// Process a stream of incoming audio samples from mic tap
    public func process(samples: UnsafePointer<Float>, count: Int, sampleRate: Double) {
        // Accumulate samples
        sampleBuffer.append(contentsOf: UnsafeBufferPointer(start: samples, count: count))

        // Keep buffer trimmed
        guard sampleBuffer.count >= sampleWindowSize else { return }

        // Throttle UI updates to ~25-30fps to avoid main thread saturation
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastUpdateTime >= 0.035 else {
            if sampleBuffer.count > sampleWindowSize * 2 {
                sampleBuffer.removeFirst(sampleBuffer.count - sampleWindowSize)
            }
            return
        }
        lastUpdateTime = now

        let windowSlice = Array(sampleBuffer.prefix(sampleWindowSize))
        sampleBuffer.removeFirst(min(count, sampleBuffer.count))

        // Analyze pitch in background/audio thread
        analyzePitch(samples: windowSlice, sampleRate: Float(sampleRate))
    }

    private func analyzePitch(samples: [Float], sampleRate: Float) {
        guard samples.count >= sampleWindowSize else { return }

        // 1. Calculate RMS to reject silence and low ambient background noise
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(sampleWindowSize))
        guard rms > 0.008 else { // Roughly -42 dBFS threshold
            DispatchQueue.main.async {
                self.isVoiced = false
                self.detectedNote = "--"
                self.detectedFrequency = 0
                self.centsDeviation = 0
                self.clarity = 0
            }
            return
        }

        // 2. Apply Hanning window to prevent edge discontinuities
        var windowed = [Float](repeating: 0, count: sampleWindowSize)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(sampleWindowSize))

        // 3. Autocorrelation via vDSP_conv
        // Vocal search range: 65 Hz (C2) to 1100 Hz (C6)
        let minPeriod = Int(sampleRate / 1100.0) // ~43 samples @ 48kHz
        let maxPeriod = Int(sampleRate / 65.0)   // ~738 samples @ 48kHz
        guard maxPeriod < sampleWindowSize / 2 else { return }

        var autocorr = [Float](repeating: 0, count: maxPeriod + 2)
        vDSP_conv(windowed, 1, windowed, 1, &autocorr, 1, vDSP_Length(maxPeriod + 2), vDSP_Length(sampleWindowSize - maxPeriod - 2))

        let r0 = autocorr[0]
        guard r0 > 1e-6 else { return }

        // 4. Normalized autocorrelation peak finding
        var bestPeriod: Float = 0
        var maxPeak: Float = 0
        var bestIndex = -1

        // Find the first major peak after minPeriod
        for i in minPeriod..<maxPeriod {
            let val = autocorr[i]
            if val > autocorr[i - 1] && val > autocorr[i + 1] {
                let normalizedVal = val / r0
                if normalizedVal > 0.45 && normalizedVal > maxPeak {
                    maxPeak = normalizedVal
                    bestIndex = i
                }
            }
        }

        guard bestIndex > 0, maxPeak >= 0.50 else {
            DispatchQueue.main.async {
                self.isVoiced = false
                self.clarity = maxPeak
            }
            return
        }

        // 5. Parabolic interpolation for sub-sample period accuracy
        let y1 = autocorr[bestIndex - 1]
        let y2 = autocorr[bestIndex]
        let y3 = autocorr[bestIndex + 1]
        let denominator = 2.0 * (2.0 * y2 - y1 - y3)
        let delta = denominator != 0 ? (y3 - y1) / denominator : 0.0
        bestPeriod = Float(bestIndex) + delta

        guard bestPeriod > 0 else { return }
        let frequency = sampleRate / bestPeriod

        // Filter reasonable vocal fundamental frequency
        guard frequency >= 60.0 && frequency <= 1200.0 else { return }

        // 6. Convert Frequency to Musical Note & Cents
        // Formula: MIDI note number n = 12 * log2(f / 440) + 69
        let midiNote = 12.0 * log2(frequency / 440.0) + 69.0
        let nearestMidi = Int(round(midiNote))
        let cents = (midiNote - Float(nearestMidi)) * 100.0

        let noteIndex = (nearestMidi % 12 + 12) % 12
        let octave = (nearestMidi / 12) - 1
        let noteString = "\(PitchDetector.noteNames[noteIndex])\(octave)"

        DispatchQueue.main.async {
            self.isVoiced = true
            self.detectedNote = noteString
            self.detectedFrequency = frequency
            // Smooth cents movement slightly
            self.centsDeviation = self.centsDeviation * 0.4 + cents * 0.6
            self.clarity = maxPeak
        }
    }

    public func reset() {
        DispatchQueue.main.async {
            self.detectedNote = "--"
            self.detectedFrequency = 0
            self.centsDeviation = 0
            self.clarity = 0
            self.isVoiced = false
        }
        sampleBuffer.removeAll()
    }
}

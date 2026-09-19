import Foundation
import AVFoundation
import Combine

// MARK: - Delay Sync Subdivision Mode
public enum DelaySyncSubdivision: String, CaseIterable, Identifiable {
    case off = "Off"
    case quarter = "1/4"
    case eighth = "1/8"
    case dottedEighth = "Dotted 1/8"
    case sixteenth = "1/16"

    public var id: String { rawValue }

    public func multiplier() -> Double? {
        switch self {
        case .off: return nil
        case .quarter: return 1.0
        case .eighth: return 0.5
        case .dottedEighth: return 0.75
        case .sixteenth: return 0.25
        }
    }
}

// MARK: - MetronomeManager
/// Procedural in-ear metronome with Tap Tempo and automatic BPM delay sync.
/// Routed exclusively to headphones monitor output to prevent microphone feedback or bleed.
public class MetronomeManager: ObservableObject {
    // MARK: - Audio Nodes
    public let playerNode = AVAudioPlayerNode()
    public let mixerNode = AVAudioMixerNode()

    // MARK: - Published State
    @Published public var isPlaying: Bool = false
    @Published public var bpm: Int = 120 {
        didSet {
            let clamped = max(30, min(bpm, 300))
            if bpm != clamped { bpm = clamped }
            restartTimerIfPlaying()
            notifyDelaySync()
        }
    }

    @Published public var beatsPerMeasure: Int = 4 // 4/4, 3/4, etc.
    @Published public var currentBeat: Int = 1
    @Published public var isAccentBeat: Bool = false
    @Published public var clickVolume: Float = 0.6 {
        didSet {
            mixerNode.outputVolume = clickVolume
        }
    }

    // Delay BPM Synchronization
    @Published public var delaySyncMode: DelaySyncSubdivision = .eighth {
        didSet {
            notifyDelaySync()
        }
    }

    // Callback to update AudioEngineManager delay time
    public var onDelayTimeChanged: ((TimeInterval) -> Void)?

    // MARK: - Synthesized Click Buffers
    private var highClickBuffer: AVAudioPCMBuffer?
    private var lowClickBuffer: AVAudioPCMBuffer?
    private var currentFormat: AVAudioFormat?

    // Timing
    private var metronomeTimer: DispatchSourceTimer?
    private let metronomeQueue = DispatchQueue(label: "com.vocalcue.metronomeQueue", qos: .userInteractive)

    // Tap Tempo Tracker
    private var tapTimestamps: [TimeInterval] = []

    public init() {
        mixerNode.outputVolume = clickVolume
    }

    deinit {
        stop()
    }

    // MARK: - Attach & Connect
    public func attachNodes(to engine: AVAudioEngine) {
        if playerNode.engine == nil { engine.attach(playerNode) }
        if mixerNode.engine == nil { engine.attach(mixerNode) }
    }

    public func connectNodes(in engine: AVAudioEngine, format: AVAudioFormat) {
        currentFormat = format
        generateClickBuffers(format: format)

        engine.disconnectNodeOutput(playerNode)
        engine.disconnectNodeOutput(mixerNode)

        engine.connect(playerNode, to: mixerNode, format: format)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: format)
    }

    // MARK: - Procedural Click Generator
    /// Synthesizes high (accent) and low (normal) crisp clicks in PCM buffer
    private func generateClickBuffers(format: AVAudioFormat) {
        let sampleRate = format.sampleRate > 0 ? format.sampleRate : 48000.0
        let channels = format.channelCount > 0 ? format.channelCount : 2
        let duration = 0.025 // 25ms percussive ping
        let frameCount = AVAudioFrameCount(duration * sampleRate)

        guard let highBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let lowBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

        highBuffer.frameLength = frameCount
        lowBuffer.frameLength = frameCount

        // Generate Sine with Exponential Decay
        func fillBuffer(_ buffer: AVAudioPCMBuffer, frequency: Float, decayRate: Float) {
            for ch in 0..<Int(channels) {
                guard let channelData = buffer.floatChannelData?[ch] else { continue }
                for frame in 0..<Int(frameCount) {
                    let t = Float(frame) / Float(sampleRate)
                    let amplitude = expf(-decayRate * t)
                    let sample = sinf(2.0 * .pi * frequency * t) * amplitude * 0.9
                    channelData[frame] = sample
                }
            }
        }

        // Beat 1: 1800 Hz woodblock ping
        fillBuffer(highBuffer, frequency: 1800.0, decayRate: 140.0)
        // Beats 2-N: 900 Hz normal click
        fillBuffer(lowBuffer, frequency: 900.0, decayRate: 180.0)

        self.highClickBuffer = highBuffer
        self.lowClickBuffer = lowBuffer
    }

    // MARK: - Playback Control
    public func start() {
        guard !isPlaying else { return }
        if !playerNode.isPlaying {
            playerNode.play()
        }
        currentBeat = 1
        isPlaying = true
        startTimer()
    }

    public func stop() {
        guard isPlaying else { return }
        metronomeTimer?.cancel()
        metronomeTimer = nil
        playerNode.stop()
        isPlaying = false
        DispatchQueue.main.async {
            self.currentBeat = 1
            self.isAccentBeat = false
        }
    }

    public func toggle() {
        isPlaying ? stop() : start()
    }

    private func restartTimerIfPlaying() {
        if isPlaying {
            startTimer()
        }
    }

    private func startTimer() {
        metronomeTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: metronomeQueue)
        let interval = 60.0 / Double(bpm)
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(1))

        var beatCounter = 0

        timer.setEventHandler { [weak self] in
            guard let self else { return }

            let beat = (beatCounter % self.beatsPerMeasure) + 1
            let isAccent = (beat == 1)
            beatCounter += 1

            // Trigger audio click buffer
            let bufferToPlay = isAccent ? self.highClickBuffer : self.lowClickBuffer
            if let buf = bufferToPlay {
                self.playerNode.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
            }

            DispatchQueue.main.async {
                self.currentBeat = beat
                self.isAccentBeat = isAccent
            }
        }

        timer.resume()
        self.metronomeTimer = timer
    }

    // MARK: - Tap Tempo
    public func tapTempo() {
        let now = ProcessInfo.processInfo.systemUptime

        // Reset if inactive for over 2 seconds
        if let last = tapTimestamps.last, now - last > 2.0 {
            tapTimestamps.removeAll()
        }

        tapTimestamps.append(now)

        // Keep last 6 taps
        if tapTimestamps.count > 6 {
            tapTimestamps.removeFirst()
        }

        guard tapTimestamps.count >= 2 else { return }

        // Compute average interval
        var intervals: [TimeInterval] = []
        for i in 1..<tapTimestamps.count {
            intervals.append(tapTimestamps[i] - tapTimestamps[i - 1])
        }

        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        guard avgInterval > 0 else { return }

        let calculatedBPM = Int(round(60.0 / avgInterval))
        let clampedBPM = max(30, min(calculatedBPM, 300))

        DispatchQueue.main.async {
            self.bpm = clampedBPM
        }
    }

    // MARK: - Delay Synchronization
    private func notifyDelaySync() {
        guard let mult = delaySyncMode.multiplier() else { return }
        // Delay time = (60.0 / bpm) * multiplier
        let quarterNoteSec = 60.0 / Double(bpm)
        let delaySec = quarterNoteSec * mult
        // Clamp to AVAudioUnitDelay maximum range (~2.0s)
        let clampedDelay = max(0.01, min(delaySec, 2.0))
        onDelayTimeChanged?(clampedDelay)
    }

    public func syncDelayNow() {
        notifyDelaySync()
    }
}

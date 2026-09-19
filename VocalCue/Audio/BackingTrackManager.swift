import Foundation
import AVFoundation
import Combine

// MARK: - BackingTrackManager
/// Manages loading, playback, time-pitch scaling, volume fader, and A-B looping for backing rehearsal tracks.
public class BackingTrackManager: ObservableObject {
    // MARK: - Audio Nodes
    public let playerNode = AVAudioPlayerNode()
    public let timePitchNode = AVAudioUnitTimePitch()
    public let mixerNode = AVAudioMixerNode()

    // MARK: - Published State
    @Published public var isFileLoaded: Bool = false
    @Published public var trackTitle: String = "No Track Loaded"
    @Published public var trackDuration: TimeInterval = 0.0
    @Published public var currentTime: TimeInterval = 0.0
    @Published public var isPlaying: Bool = false

    // Key & Tempo controls
    @Published public var pitchShiftSemitones: Int = 0 {
        didSet {
            // 1 semitone = 100 cents
            timePitchNode.pitch = Float(pitchShiftSemitones * 100)
        }
    }

    @Published public var tempoRate: Float = 1.0 {
        didSet {
            timePitchNode.rate = max(0.5, min(tempoRate, 2.0))
        }
    }

    // Volume Fader
    @Published public var backingVolume: Float = 0.7 {
        didSet {
            mixerNode.outputVolume = backingVolume
        }
    }

    // A-B Rehearsal Loop
    @Published public var isLooping: Bool = false
    @Published public var loopStart: TimeInterval? = nil
    @Published public var loopEnd: TimeInterval? = nil

    // Private properties
    private var audioFile: AVAudioFile?
    private var fileFormat: AVAudioFormat?
    private var playbackTimer: Timer?
    private var seekFrameOffset: AVAudioFramePosition = 0
    private var lastSampleRate: Double = 48000.0

    public init() {
        mixerNode.outputVolume = backingVolume
        timePitchNode.pitch = 0
        timePitchNode.rate = 1.0
    }

    // MARK: - Attach & Connect
    public func attachNodes(to engine: AVAudioEngine) {
        if playerNode.engine == nil { engine.attach(playerNode) }
        if timePitchNode.engine == nil { engine.attach(timePitchNode) }
        if mixerNode.engine == nil { engine.attach(mixerNode) }
    }

    public func connectNodes(in engine: AVAudioEngine, format: AVAudioFormat) {
        lastSampleRate = format.sampleRate > 0 ? format.sampleRate : 48000.0

        // Disconnect previous connections if any
        engine.disconnectNodeOutput(playerNode)
        engine.disconnectNodeOutput(timePitchNode)
        engine.disconnectNodeOutput(mixerNode)

        // Player -> TimePitch -> MixerNode -> MainMixerNode
        engine.connect(playerNode, to: timePitchNode, format: format)
        engine.connect(timePitchNode, to: mixerNode, format: format)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: format)
    }

    // MARK: - File Loading
    public func loadFile(url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            self.audioFile = file
            self.fileFormat = file.processingFormat
            let length = Double(file.length) / file.processingFormat.sampleRate

            DispatchQueue.main.async {
                self.stop()
                self.trackTitle = url.deletingPathExtension().lastPathComponent
                self.trackDuration = length
                self.currentTime = 0
                self.seekFrameOffset = 0
                self.loopStart = nil
                self.loopEnd = nil
                self.isLooping = false
                self.isFileLoaded = true
            }
            print("[BackingTrack] Successfully loaded: \(url.lastPathComponent) (\(length)s)")
        } catch {
            print("[BackingTrack] Failed to load audio file: \(error.localizedDescription)")
        }
    }

    // MARK: - Playback Control
    public func play() {
        guard audioFile != nil, isFileLoaded else { return }

        if !playerNode.isPlaying {
            schedulePlayback(from: currentTime)
            playerNode.play()
            startPlaybackTimer()
            DispatchQueue.main.async {
                self.isPlaying = true
            }
        }
    }

    public func pause() {
        guard isPlaying else { return }
        playerNode.pause()
        stopPlaybackTimer()
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func stop() {
        playerNode.stop()
        stopPlaybackTimer()
        seekFrameOffset = 0
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
        }
    }

    public func seek(to time: TimeInterval) {
        let clampedTime = max(0, min(time, trackDuration))
        let wasPlaying = isPlaying

        playerNode.stop()
        seekFrameOffset = AVAudioFramePosition(clampedTime * (audioFile?.processingFormat.sampleRate ?? lastSampleRate))
        currentTime = clampedTime

        if wasPlaying {
            schedulePlayback(from: clampedTime)
            playerNode.play()
        }
    }

    private func schedulePlayback(from time: TimeInterval) {
        guard let file = audioFile else { return }
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        let totalFrames = file.length

        guard startFrame < totalFrames else {
            stop()
            return
        }

        let frameCount = AVAudioFrameCount(totalFrames - startFrame)
        seekFrameOffset = startFrame

        playerNode.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil
        ) { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.isPlaying && !self.isLooping {
                    self.stop()
                }
            }
        }
    }

    // MARK: - A-B Loop Controls
    public func setPointA() {
        loopStart = currentTime
        if let end = loopEnd, let start = loopStart, start >= end {
            loopEnd = min(trackDuration, start + 2.0)
        }
        isLooping = true
    }

    public func setPointB() {
        if let start = loopStart, currentTime > start {
            loopEnd = currentTime
        } else {
            loopStart = max(0, currentTime - 2.0)
            loopEnd = currentTime
        }
        isLooping = true
    }

    public func clearLoop() {
        loopStart = nil
        loopEnd = nil
        isLooping = false
    }

    public func toggleLoop() {
        if loopStart != nil && loopEnd != nil {
            isLooping.toggle()
        } else if loopStart != nil {
            loopEnd = trackDuration
            isLooping = true
        }
    }

    // MARK: - Playback Timer & Position Tracking
    private func startPlaybackTimer() {
        stopPlaybackTimer()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying else { return }
            self.updateCurrentTime()
        }
        RunLoop.main.add(playbackTimer!, forMode: .common)
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func updateCurrentTime() {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
              let file = audioFile else { return }

        let sampleRate = file.processingFormat.sampleRate
        let elapsedSec = Double(playerTime.sampleTime) / sampleRate
        let currentPos = Double(seekFrameOffset) / sampleRate + elapsedSec

        // Handle A-B loop boundary
        if isLooping, let start = loopStart, let end = loopEnd, end > start {
            if currentPos >= end {
                seek(to: start)
                return
            }
        }

        if currentPos >= trackDuration {
            if isLooping, let start = loopStart {
                seek(to: start)
            } else {
                stop()
            }
        } else {
            self.currentTime = currentPos
        }
    }
}

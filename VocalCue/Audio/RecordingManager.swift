import Foundation
import AVFoundation
import AppKit
import Combine

// MARK: - Vocal Take Model
public struct VocalTake: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public let createdAt: Date
    public var duration: TimeInterval
    public let wetFileName: String
    public let dryFileName: String

    public init(id: UUID = UUID(), name: String, createdAt: Date = Date(), duration: TimeInterval = 0, wetFileName: String, dryFileName: String) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.duration = duration
        self.wetFileName = wetFileName
        self.dryFileName = dryFileName
    }
}

public enum TakeAudioSource: String, CaseIterable, Identifiable {
    case wet = "Wet (Master FX)"
    case dry = "Dry (Raw Vocal)"

    public var id: String { rawValue }
}

// MARK: - RecordingManager
/// Manages dual-stream (Dry + Wet) audio recording, multi-take library, inline A/B preview, and M4A export.
public class RecordingManager: ObservableObject {
    // MARK: - Published State
    @Published public var isRecording: Bool = false
    @Published public var recordingDuration: TimeInterval = 0.0
    @Published public var takes: [VocalTake] = []
    @Published public var selectedTake: VocalTake?

    // Preview Player State
    @Published public var previewSource: TakeAudioSource = .wet
    @Published public var isPreviewPlaying: Bool = false
    @Published public var previewProgress: Double = 0.0 // 0.0 to 1.0
    @Published public var previewCurrentTime: TimeInterval = 0.0
    @Published public var isExporting: Bool = false
    @Published public var exportMessage: String?

    // MARK: - Internal Recording Files
    private var wetAudioFile: AVAudioFile?
    private var dryAudioFile: AVAudioFile?
    private var currentTake: VocalTake?
    private var recordingTimer: Timer?
    private var recordingStartDate: Date?

    private let recordingQueue = DispatchQueue(label: "com.vocalcue.dualRecordingQueue", qos: .userInitiated)

    // Preview Player
    private var audioPlayer: AVAudioPlayer?
    private var previewTimer: Timer?

    // Target Directory: ~/Music/VocalCue Recordings/
    public let recordingsDirectory: URL = {
        let musicDir = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Music")
        let dir = musicDir.appendingPathComponent("VocalCue Recordings")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private let takesIndexURL: URL

    public init() {
        self.takesIndexURL = recordingsDirectory.appendingPathComponent("takes_index.json")
        loadTakesIndex()
    }

    // MARK: - Dual Recording Control
    public func startRecording(sampleRate: Double) {
        guard !isRecording else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let takeIndex = takes.count + 1
        let takeName = "Take \(takeIndex)"

        let wetFileName = "Take_\(timestamp)_Wet.wav"
        let dryFileName = "Take_\(timestamp)_Dry.wav"

        let wetURL = recordingsDirectory.appendingPathComponent(wetFileName)
        let dryURL = recordingsDirectory.appendingPathComponent(dryFileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate > 0 ? sampleRate : 48000.0,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 24,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        do {
            wetAudioFile = try AVAudioFile(forWriting: wetURL, settings: settings)
            dryAudioFile = try AVAudioFile(forWriting: dryURL, settings: settings)

            let take = VocalTake(
                name: takeName,
                createdAt: Date(),
                duration: 0,
                wetFileName: wetFileName,
                dryFileName: dryFileName
            )
            self.currentTake = take
            self.isRecording = true
            self.recordingDuration = 0
            self.recordingStartDate = Date()

            // Live stopwatch timer
            DispatchQueue.main.async {
                self.stopPreview()
                self.recordingTimer?.invalidate()
                self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self, let start = self.recordingStartDate else { return }
                    self.recordingDuration = Date().timeIntervalSince(start)
                }
                RunLoop.main.add(self.recordingTimer!, forMode: .common)
            }

            print("[RecordingManager] 🎙️ Dual Dry+Wet Recording Started: \(takeName)")
        } catch {
            print("[RecordingManager] ❌ Failed to start recording: \(error.localizedDescription)")
        }
    }

    public func stopRecording() {
        guard isRecording else { return }
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false

        let finalDuration = recordingDuration
        let finishedTake = currentTake

        recordingQueue.async { [weak self] in
            guard let self else { return }
            self.wetAudioFile = nil
            self.dryAudioFile = nil

            if var take = finishedTake {
                take.duration = finalDuration
                DispatchQueue.main.async {
                    self.takes.insert(take, at: 0)
                    self.selectedTake = take
                    self.saveTakesIndex()
                    print("[RecordingManager] ⏹ Take Saved: \(take.name) (\(String(format: "%.1f", finalDuration))s)")
                }
            }
            self.currentTake = nil
        }
    }

    // MARK: - Audio Buffer Feed
    public func writeWetBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRecording, let file = wetAudioFile else { return }
        writeBuffer(buffer, to: file)
    }

    public func writeDryBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRecording, let file = dryAudioFile else { return }
        writeBuffer(buffer, to: file)
    }

    private func writeBuffer(_ buffer: AVAudioPCMBuffer, to file: AVAudioFile) {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return }
        copy.frameLength = buffer.frameLength
        for ch in 0..<Int(buffer.format.channelCount) {
            if let src = buffer.floatChannelData?[ch], let dst = copy.floatChannelData?[ch] {
                memcpy(dst, src, Int(buffer.frameLength) * MemoryLayout<Float>.size)
            }
        }

        recordingQueue.async {
            do {
                try file.write(from: copy)
            } catch {
                print("[RecordingManager] Buffer write error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Take Preview Player
    public func playTake(_ take: VocalTake, source: TakeAudioSource) {
        selectedTake = take
        previewSource = source

        let fileName = (source == .wet) ? take.wetFileName : take.dryFileName
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPreviewPlaying = true
            startPreviewTimer()
        } catch {
            print("[RecordingManager] Failed to preview take: \(error.localizedDescription)")
        }
    }

    public func togglePreview() {
        if isPreviewPlaying {
            pausePreview()
        } else if let take = selectedTake {
            playTake(take, source: previewSource)
        } else if let firstTake = takes.first {
            playTake(firstTake, source: previewSource)
        }
    }

    public func pausePreview() {
        audioPlayer?.pause()
        isPreviewPlaying = false
        stopPreviewTimer()
    }

    public func stopPreview() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPreviewPlaying = false
        previewProgress = 0
        previewCurrentTime = 0
        stopPreviewTimer()
    }

    public func seekPreview(to progress: Double) {
        guard let player = audioPlayer else { return }
        let time = progress * player.duration
        player.currentTime = time
        previewCurrentTime = time
        previewProgress = progress
    }

    private func startPreviewTimer() {
        stopPreviewTimer()
        previewTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let player = self.audioPlayer else { return }
            if player.isPlaying {
                self.previewCurrentTime = player.currentTime
                self.previewProgress = player.duration > 0 ? (player.currentTime / player.duration) : 0
            } else if !player.isPlaying && self.isPreviewPlaying {
                // Finished playing
                self.stopPreview()
            }
        }
        RunLoop.main.add(previewTimer!, forMode: .common)
    }

    private func stopPreviewTimer() {
        previewTimer?.invalidate()
        previewTimer = nil
    }

    // MARK: - M4A Export
    public func exportTakeToM4A(take: VocalTake, source: TakeAudioSource, completion: @escaping (Result<URL, Error>) -> Void) {
        let inputFileName = (source == .wet) ? take.wetFileName : take.dryFileName
        let inputURL = recordingsDirectory.appendingPathComponent(inputFileName)

        let baseName = inputFileName.replacingOccurrences(of: ".wav", with: "")
        let outputFileName = "\(baseName).m4a"
        let outputURL = recordingsDirectory.appendingPathComponent(outputFileName)

        // Remove previous exported file if exists
        try? FileManager.default.removeItem(at: outputURL)

        isExporting = true
        exportMessage = "Exporting \(source.rawValue)..."

        let asset = AVAsset(url: inputURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            isExporting = false
            exportMessage = "Export failed"
            completion(.failure(NSError(domain: "VocalCue", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])))
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        exportSession.exportAsynchronously { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isExporting = false
                switch exportSession.status {
                case .completed:
                    self.exportMessage = "Exported: \(outputFileName)"
                    completion(.success(outputURL))
                case .failed, .cancelled:
                    let err = exportSession.error ?? NSError(domain: "VocalCue", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
                    self.exportMessage = "Error: \(err.localizedDescription)"
                    completion(.failure(err))
                default:
                    break
                }
            }
        }
    }

    // MARK: - Delete & Manage Takes
    public func deleteTake(_ take: VocalTake) {
        if selectedTake == take {
            stopPreview()
            selectedTake = nil
        }

        let wetURL = recordingsDirectory.appendingPathComponent(take.wetFileName)
        let dryURL = recordingsDirectory.appendingPathComponent(take.dryFileName)
        try? FileManager.default.removeItem(at: wetURL)
        try? FileManager.default.removeItem(at: dryURL)

        // Delete any exported m4a versions as well
        let wetM4A = wetURL.deletingPathExtension().appendingPathExtension("m4a")
        let dryM4A = dryURL.deletingPathExtension().appendingPathExtension("m4a")
        try? FileManager.default.removeItem(at: wetM4A)
        try? FileManager.default.removeItem(at: dryM4A)

        takes.removeAll { $0.id == take.id }
        saveTakesIndex()
    }

    public func revealTakeInFinder(_ take: VocalTake) {
        let wetURL = recordingsDirectory.appendingPathComponent(take.wetFileName)
        if FileManager.default.fileExists(atPath: wetURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([wetURL])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([recordingsDirectory])
        }
    }

    // MARK: - Persistence
    private func saveTakesIndex() {
        do {
            let data = try JSONEncoder().encode(takes)
            try data.write(to: takesIndexURL, options: .atomic)
        } catch {
            print("[RecordingManager] Failed to save takes index: \(error.localizedDescription)")
        }
    }

    private func loadTakesIndex() {
        guard FileManager.default.fileExists(atPath: takesIndexURL.path) else { return }
        do {
            let data = try Data(contentsOf: takesIndexURL)
            let loaded = try JSONDecoder().decode([VocalTake].self, from: data)
            self.takes = loaded
            self.selectedTake = loaded.first
        } catch {
            print("[RecordingManager] Failed to load takes index: \(error.localizedDescription)")
        }
    }
}

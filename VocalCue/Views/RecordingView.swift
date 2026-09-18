import SwiftUI
import AVFoundation
import AppKit

// MARK: - RecordingView — Live Vocal & Effects Recording

struct RecordingView: View {
    @ObservedObject var engine: AudioEngineManager

    @State private var isPulseActive = false
    @State private var previewPlayer: AVAudioPlayer? = nil
    @State private var isPreviewPlaying = false
    @State private var previewProgress: Double = 0
    @State private var previewTimer: Timer? = nil

    private let accentRed = Color(red: 1.0, green: 0.25, blue: 0.25)
    private let accentCyan = Color(red: 0, green: 0.83, blue: 1.0)

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(engine.isRecording ? accentRed : accentRed.opacity(0.7))
                Text("LIVE RECORDING")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)

                Spacer()

                // Audio Quality Badge
                Text("24-BIT 48kHz WAV")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.04)))
            }

            // Main Recording Controls
            if engine.isRecording {
                activeRecordingView
            } else {
                idleRecordingView
            }

            // Last Recorded Take Card (Preview & Finder)
            if let fileURL = engine.lastRecordedFileURL {
                lastTakeCard(fileURL: fileURL)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.10).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            engine.isRecording ? accentRed.opacity(0.4) : Color(white: 0.16),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: engine.isRecording ? accentRed.opacity(0.2) : .black.opacity(0.2),
                    radius: engine.isRecording ? 12 : 8,
                    y: 4
                )
        )
        .animation(.easeInOut(duration: 0.25), value: engine.isRecording)
    }

    // MARK: - Active Recording State

    private var activeRecordingView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Pulsing Record Indicator
                ZStack {
                    Circle()
                        .stroke(accentRed.opacity(isPulseActive ? 0.5 : 0.1), lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .scaleEffect(isPulseActive ? 1.2 : 0.9)
                    Circle()
                        .fill(accentRed)
                        .frame(width: 12, height: 12)
                        .shadow(color: accentRed.opacity(isPulseActive ? 0.9 : 0.4), radius: 6)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulseActive = true
                    }
                }
                .onDisappear {
                    isPulseActive = false
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("RECORDING")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundColor(accentRed)
                        Text("• Post-Effects Master")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    // Live Stopwatch Duration
                    Text(formatDuration(engine.recordingDuration))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                Spacer()

                // Stop & Save Button
                Button(action: {
                    engine.stopRecording()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 11))
                        Text("Stop & Save")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(accentRed.opacity(0.85))
                            .shadow(color: accentRed.opacity(0.4), radius: 6)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(accentRed.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accentRed.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Idle State

    private var idleRecordingView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Record Voice Take")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Text("Captures vocal with active EQ, Reverb, Delay & Limiter")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            Button(action: {
                // Stop any playing preview before recording new take
                stopPreview()
                engine.startRecording()
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(accentRed)
                        .frame(width: 8, height: 8)
                        .shadow(color: accentRed.opacity(0.7), radius: 4)
                    Text("Record")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            Capsule()
                                .stroke(accentRed.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Last Recorded Take Card

    private func lastTakeCard(fileURL: URL) -> some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.white.opacity(0.06))

            HStack(spacing: 10) {
                // Audio wave icon
                Image(systemName: "waveform")
                    .font(.system(size: 14))
                    .foregroundColor(accentCyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text(fileURL.lastPathComponent)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(getFileSize(url: fileURL))
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.35))
                }

                Spacer()

                // Quick Play/Pause Preview Button
                Button(action: {
                    togglePreview(url: fileURL)
                }) {
                    Image(systemName: isPreviewPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.black)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(accentCyan)
                                .shadow(color: accentCyan.opacity(0.4), radius: 4)
                        )
                }
                .buttonStyle(.plain)
                .help(isPreviewPlaying ? "Pause Preview" : "Listen to Take")

                // Show in Finder Button
                Button(action: {
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                .help("Show file in Finder")
            }

            // Preview Playback Progress Bar (when playing)
            if isPreviewPlaying || previewProgress > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 3)
                        Capsule()
                            .fill(accentCyan)
                            .frame(width: max(0, geo.size.width * CGFloat(previewProgress)), height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Preview Audio Player Helpers

    private func togglePreview(url: URL) {
        if isPreviewPlaying {
            previewPlayer?.pause()
            isPreviewPlaying = false
            previewTimer?.invalidate()
        } else {
            if previewPlayer == nil || previewPlayer?.url != url {
                do {
                    previewPlayer = try AVAudioPlayer(contentsOf: url)
                    previewPlayer?.prepareToPlay()
                } catch {
                    print("[VocalCue] Preview error: \(error)")
                    return
                }
            }

            previewPlayer?.play()
            isPreviewPlaying = true

            previewTimer?.invalidate()
            previewTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                guard let player = previewPlayer, player.duration > 0 else { return }
                previewProgress = player.currentTime / player.duration
                if !player.isPlaying {
                    isPreviewPlaying = false
                    previewProgress = 0
                    previewTimer?.invalidate()
                }
            }
        }
    }

    private func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        isPreviewPlaying = false
        previewProgress = 0
        previewTimer?.invalidate()
    }

    // MARK: - Formatting Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", mins, secs, tenths)
    }

    private func getFileSize(url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return "WAV Audio"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

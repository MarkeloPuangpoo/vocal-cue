import SwiftUI
import AVFoundation
import AppKit

// MARK: - RecordingView — Live Dual (Dry + Wet) Vocal Recording
struct RecordingView: View {
    @ObservedObject var engine: AudioEngineManager
    @ObservedObject var recordingManager: RecordingManager

    @State private var isPulseActive = false

    private let accentRed = Color(red: 1.0, green: 0.25, blue: 0.25)
    private let accentCyan = Color(red: 0, green: 0.83, blue: 1.0)
    private let accentGreen = Color(red: 0, green: 0.9, blue: 0.5)

    init(engine: AudioEngineManager) {
        self.engine = engine
        self.recordingManager = engine.recordingManager
    }

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(recordingManager.isRecording ? accentRed : accentRed.opacity(0.7))
                Text("DUAL TRACK RECORDING")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)

                Spacer()

                // Audio Quality Badge
                Text("DRY + WET 24-BIT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.04)))
            }

            // Main Recording Controls
            if recordingManager.isRecording {
                activeRecordingView
            } else {
                idleRecordingView
            }

            // Takes Library & Selected Take Card
            if !recordingManager.takes.isEmpty {
                takesLibrarySection
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.10).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            recordingManager.isRecording ? accentRed.opacity(0.4) : Color(white: 0.16),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: recordingManager.isRecording ? accentRed.opacity(0.2) : .black.opacity(0.2),
                    radius: recordingManager.isRecording ? 12 : 8,
                    y: 4
                )
        )
        .animation(.easeInOut(duration: 0.25), value: recordingManager.isRecording)
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
                        Text("RECORDING DUAL")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundColor(accentRed)
                        Text("• Capturing Dry & Wet")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    // Live Stopwatch Duration
                    Text(formatDuration(recordingManager.recordingDuration))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                Spacer()

                // Stop & Save Button
                Button(action: {
                    recordingManager.stopRecording()
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
                Text("Record Dry + Wet Take")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Text("Saves both raw vocal & studio FX master simultaneously")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            Button(action: {
                recordingManager.stopPreview()
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

    // MARK: - Takes Library Section
    private var takesLibrarySection: some View {
        VStack(spacing: 10) {
            Divider()
                .background(Color.white.opacity(0.08))

            // Take Selector Menu
            HStack {
                Text("TAKES LIBRARY (\(recordingManager.takes.count))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1)

                Spacer()

                if let current = recordingManager.selectedTake {
                    Picker("", selection: Binding(
                        get: { current.id },
                        set: { newID in
                            if let found = recordingManager.takes.first(where: { $0.id == newID }) {
                                recordingManager.selectedTake = found
                                recordingManager.stopPreview()
                            }
                        }
                    )) {
                        ForEach(recordingManager.takes) { take in
                            Text("\(take.name) (\(formatDuration(take.duration)))").tag(take.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                    .tint(.white.opacity(0.7))
                }
            }

            // Selected Take Detail Card
            if let take = recordingManager.selectedTake {
                VStack(spacing: 10) {
                    // Preview A/B Source Picker
                    HStack {
                        Picker("Source", selection: $recordingManager.previewSource) {
                            ForEach(TakeAudioSource.allCases) { src in
                                Text(src.rawValue).tag(src)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: recordingManager.previewSource) { _, newSource in
                            if recordingManager.isPreviewPlaying {
                                recordingManager.playTake(take, source: newSource)
                            }
                        }
                    }

                    // Scrubber & Transport
                    HStack(spacing: 10) {
                        // Play / Pause Preview Button
                        Button(action: {
                            recordingManager.togglePreview()
                        }) {
                            Image(systemName: recordingManager.isPreviewPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.black)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(accentCyan)
                                        .shadow(color: accentCyan.opacity(0.4), radius: 4)
                                )
                        }
                        .buttonStyle(.plain)

                        // Seek progress bar
                        Slider(
                            value: Binding(
                                get: { recordingManager.previewProgress },
                                set: { recordingManager.seekPreview(to: $0) }
                            ),
                            in: 0...1.0
                        )
                        .tint(accentCyan)

                        Text("\(formatDuration(recordingManager.previewCurrentTime)) / \(formatDuration(take.duration))")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 68, alignment: .trailing)
                    }

                    // Actions: Export M4A, Show in Finder, Delete Take
                    HStack(spacing: 8) {
                        // Export to M4A Button
                        Button(action: {
                            recordingManager.exportTakeToM4A(take: take, source: recordingManager.previewSource) { result in
                                switch result {
                                case .success(let url):
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                case .failure:
                                    break
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 10))
                                Text(recordingManager.isExporting ? "Exporting..." : "Export M4A")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(accentGreen.opacity(0.25))
                                    .overlay(Capsule().stroke(accentGreen.opacity(0.5), lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(recordingManager.isExporting)

                        Spacer()

                        // Reveal in Finder Button
                        Button(action: {
                            recordingManager.revealTakeInFinder(take)
                        }) {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .help("Show files in Finder")

                        // Delete Take Button
                        Button(action: {
                            recordingManager.deleteTake(take)
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.red.opacity(0.7))
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .help("Delete Take")
                    }

                    if let msg = recordingManager.exportMessage {
                        Text(msg)
                            .font(.system(size: 9.5))
                            .foregroundColor(accentGreen)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.03))
                )
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let tenths = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", mins, secs, tenths)
    }
}

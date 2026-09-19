import SwiftUI
import AppKit

// MARK: - BackingTrackView
/// Rehearsal backing track player with dual Vocal/Music faders, TimePitch Key & Tempo adjustment, and A-B looping.
struct BackingTrackView: View {
    @ObservedObject var backingManager: BackingTrackManager
    @ObservedObject var engine: AudioEngineManager

    private let accentCyan = Color(red: 0, green: 0.83, blue: 1.0)
    private let accentPurple = Color(red: 0.5, green: 0.4, blue: 1.0)
    private let accentGreen = Color(red: 0, green: 0.9, blue: 0.5)

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 11))
                    .foregroundColor(accentPurple.opacity(0.8))
                Text("BACKING TRACK & REHEARSAL")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)

                Spacer()

                // Load File Button
                Button(action: openFileDialog) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 10))
                        Text(backingManager.isFileLoaded ? "Change Song" : "Load Track")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(accentPurple.opacity(0.35))
                            .overlay(Capsule().stroke(accentPurple.opacity(0.6), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }

            // Track Player Card
            if backingManager.isFileLoaded {
                trackControlCard
            } else {
                emptyTrackCard
            }

            // Dual Faders: Vocal vs Music Balance
            vocalAndMusicFaders

            // Key (Pitch) & Tempo (Speed) Controls
            keyAndTempoCard

            // A-B Rehearsal Looper
            if backingManager.isFileLoaded {
                abLoopCard
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.10).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(white: 0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
    }

    // MARK: - Empty State
    private var emptyTrackCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.2))

            Text("No Backing Track Loaded")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            Text("Supports MP3, WAV, M4A, AAC & FLAC backing tracks")
                .font(.system(size: 9.5))
                .foregroundColor(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundColor(Color.white.opacity(0.1))
                )
        )
    }

    // MARK: - Track Control Card
    private var trackControlCard: some View {
        VStack(spacing: 10) {
            // Title & Duration
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(backingManager.trackTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(formatTime(backingManager.currentTime)) / \(formatTime(backingManager.trackDuration))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                // Play / Pause / Stop Transport Buttons
                HStack(spacing: 8) {
                    Button(action: { backingManager.stop() }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if !engine.isRunning {
                            engine.start()
                        }
                        backingManager.togglePlayPause()
                    }) {
                        Image(systemName: backingManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.black)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(accentPurple)
                                    .shadow(color: accentPurple.opacity(0.5), radius: 6)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Scrubber Slider
            Slider(
                value: Binding(
                    get: { backingManager.currentTime },
                    set: { backingManager.seek(to: $0) }
                ),
                in: 0...max(1.0, backingManager.trackDuration)
            )
            .tint(accentPurple)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.07), lineWidth: 1))
        )
    }

    // MARK: - Dual Faders (Vocal vs Backing Music)
    private var vocalAndMusicFaders: some View {
        VStack(spacing: 8) {
            HStack {
                Text("MIX BALANCE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(1)
                Spacer()
            }

            HStack(spacing: 16) {
                // Vocal Fader
                faderRow(
                    icon: "mic.fill",
                    label: "Vocal",
                    color: accentCyan,
                    value: Binding(
                        get: { Double(engine.vocalVolume) },
                        set: { engine.vocalVolume = Float($0) }
                    ),
                    display: "\(Int(engine.vocalVolume * 100))%"
                )

                Divider()
                    .frame(height: 28)
                    .background(Color.white.opacity(0.1))

                // Music Backing Fader
                faderRow(
                    icon: "music.note",
                    label: "Music",
                    color: accentPurple,
                    value: Binding(
                        get: { Double(backingManager.backingVolume) },
                        set: { backingManager.backingVolume = Float($0) }
                    ),
                    display: "\(Int(backingManager.backingVolume * 100))%"
                )
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.03))
            )
        }
    }

    private func faderRow(icon: String, label: String, color: Color, value: Binding<Double>, display: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 36, alignment: .leading)

            Slider(value: value, in: 0...1.0)
                .tint(color)

            Text(display)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 34, alignment: .trailing)
        }
    }

    // MARK: - Key & Tempo Controls
    private var keyAndTempoCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("KEY & TEMPO SHIFT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(1)
                Spacer()
            }

            HStack(spacing: 12) {
                // Key (Pitch Shift in Semitones)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Key:")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))

                        Text(keyText(backingManager.pitchShiftSemitones))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(backingManager.pitchShiftSemitones == 0 ? .white.opacity(0.6) : accentPurple)

                        Spacer()

                        if backingManager.pitchShiftSemitones != 0 {
                            Button("0") {
                                backingManager.pitchShiftSemitones = 0
                            }
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        }
                    }

                    HStack(spacing: 6) {
                        Button(action: {
                            if backingManager.pitchShiftSemitones > -12 {
                                backingManager.pitchShiftSemitones -= 1
                            }
                        }) {
                            Text("-1 ♭")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            if backingManager.pitchShiftSemitones < 12 {
                                backingManager.pitchShiftSemitones += 1
                            }
                        }) {
                            Text("+1 ♯")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))

                // Tempo (Speed Rate)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Speed:")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))

                        Text(String(format: "%.0f%%", backingManager.tempoRate * 100))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(backingManager.tempoRate == 1.0 ? .white.opacity(0.6) : accentCyan)

                        Spacer()

                        if backingManager.tempoRate != 1.0 {
                            Button("1x") {
                                backingManager.tempoRate = 1.0
                            }
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        }
                    }

                    Slider(
                        value: Binding(
                            get: { Double(backingManager.tempoRate) },
                            set: { backingManager.tempoRate = Float($0) }
                        ),
                        in: 0.5...1.5
                    )
                    .tint(accentCyan)
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
            }
        }
    }

    // MARK: - A-B Rehearsal Looper Card
    private var abLoopCard: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "repeat.1")
                        .font(.system(size: 11))
                        .foregroundColor(backingManager.isLooping ? accentGreen : .white.opacity(0.35))
                    Text("A-B REHEARSAL LOOP")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.35))
                        .tracking(1)
                }

                Spacer()

                if backingManager.isLooping {
                    Text("LOOPING")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundColor(accentGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(accentGreen.opacity(0.15)))
                }
            }

            HStack(spacing: 8) {
                // Set A Button
                Button(action: { backingManager.setPointA() }) {
                    VStack(spacing: 2) {
                        Text("Set A")
                            .font(.system(size: 10, weight: .bold))
                        Text(backingManager.loopStart != nil ? formatTime(backingManager.loopStart!) : "--:--")
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundColor(backingManager.loopStart != nil ? accentGreen : .white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(backingManager.loopStart != nil ? accentGreen.opacity(0.12) : Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)

                // Set B Button
                Button(action: { backingManager.setPointB() }) {
                    VStack(spacing: 2) {
                        Text("Set B")
                            .font(.system(size: 10, weight: .bold))
                        Text(backingManager.loopEnd != nil ? formatTime(backingManager.loopEnd!) : "--:--")
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundColor(backingManager.loopEnd != nil ? accentGreen : .white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(backingManager.loopEnd != nil ? accentGreen.opacity(0.12) : Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)

                // Toggle Loop Active
                Button(action: { backingManager.toggleLoop() }) {
                    Image(systemName: backingManager.isLooping ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath.circle")
                        .font(.system(size: 16))
                        .foregroundColor(backingManager.isLooping ? accentGreen : .white.opacity(0.5))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .help("Toggle Loop On/Off")

                // Clear Loop
                if backingManager.loopStart != nil || backingManager.loopEnd != nil {
                    Button(action: { backingManager.clearLoop() }) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .help("Clear Loop Points")
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Helpers
    private func openFileDialog() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .mp3, .wav]

        if panel.runModal() == .OK, let url = panel.url {
            backingManager.loadFile(url: url)
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func keyText(_ semitones: Int) -> String {
        if semitones == 0 { return "Original" }
        return String(format: "%+d st", semitones)
    }
}

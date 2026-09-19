import SwiftUI

// MARK: - MetronomeView
/// In-Ear Metronome with animated visual beat indicator, Tap Tempo, and Delay Sync.
struct MetronomeView: View {
    @ObservedObject var metronome: MetronomeManager
    @ObservedObject var engine: AudioEngineManager

    @State private var isTapPressed = false

    private let accentCyan = Color(red: 0, green: 0.83, blue: 1.0)
    private let accentGreen = Color(red: 0, green: 0.9, blue: 0.5)
    private let accentPurple = Color(red: 0.5, green: 0.4, blue: 1.0)

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "metronome.fill")
                    .font(.system(size: 11))
                    .foregroundColor(accentCyan.opacity(0.8))
                Text("METRONOME & BPM DELAY SYNC")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)

                Spacer()

                // Headphones Only Badge
                Text("IN-EAR ONLY")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundColor(accentCyan.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(accentCyan.opacity(0.12)))
            }

            // Main Metronome Control Card
            HStack(spacing: 14) {
                // Play / Stop Click Button
                Button(action: {
                    if !engine.isRunning {
                        engine.start()
                    }
                    metronome.toggle()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: metronome.isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 16))
                        Text(metronome.isPlaying ? "STOP" : "CLICK")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    }
                    .foregroundColor(metronome.isPlaying ? .black : .white)
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(metronome.isPlaying ? accentGreen : Color.white.opacity(0.08))
                            .shadow(color: metronome.isPlaying ? accentGreen.opacity(0.4) : .clear, radius: 8)
                    )
                }
                .buttonStyle(.plain)

                // Beat Indicator & BPM Counter
                VStack(alignment: .leading, spacing: 6) {
                    // Beat circles
                    HStack(spacing: 6) {
                        ForEach(1...metronome.beatsPerMeasure, id: \.self) { beat in
                            let isCurrent = metronome.isPlaying && (metronome.currentBeat == beat)
                            let isAccent = beat == 1

                            Circle()
                                .fill(
                                    isCurrent
                                        ? (isAccent ? accentGreen : accentCyan)
                                        : Color.white.opacity(0.12)
                                )
                                .frame(width: isAccent ? 12 : 9, height: isAccent ? 12 : 9)
                                .shadow(
                                    color: isCurrent
                                        ? (isAccent ? accentGreen.opacity(0.9) : accentCyan.opacity(0.7))
                                        : .clear,
                                    radius: 6
                                )
                                .animation(.easeOut(duration: 0.1), value: metronome.currentBeat)
                        }

                        Spacer()

                        // Time signature picker
                        Picker("", selection: $metronome.beatsPerMeasure) {
                            Text("4/4").tag(4)
                            Text("3/4").tag(3)
                            Text("2/4").tag(2)
                            Text("6/8").tag(6)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 64)
                        .tint(.white.opacity(0.6))
                    }

                    // BPM Display & Nudge Buttons
                    HStack(spacing: 8) {
                        Text("\(metronome.bpm)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("BPM")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.top, 8)

                        Spacer()

                        // BPM Steppers (-5, -1, +1, +5)
                        HStack(spacing: 4) {
                            bpmButton("-5", delta: -5)
                            bpmButton("-1", delta: -1)
                            bpmButton("+1", delta: 1)
                            bpmButton("+5", delta: 5)
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.04))
            )

            // BPM Slider & Click Volume
            HStack(spacing: 16) {
                // BPM Slider
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tempo Slider")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.4))

                    Slider(
                        value: Binding(
                            get: { Double(metronome.bpm) },
                            set: { metronome.bpm = Int($0) }
                        ),
                        in: 40...240,
                        step: 1
                    )
                    .tint(accentCyan)
                }

                // Click Volume
                VStack(alignment: .leading, spacing: 2) {
                    Text("Click Vol (\(Int(metronome.clickVolume * 100))%)")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.4))

                    Slider(
                        value: Binding(
                            get: { Double(metronome.clickVolume) },
                            set: { metronome.clickVolume = Float($0) }
                        ),
                        in: 0...1.0
                    )
                    .tint(accentGreen)
                }
            }

            // TAP TEMPO Button & DELAY SYNC Row
            HStack(spacing: 12) {
                // Tap Tempo Button
                Button(action: {
                    metronome.tapTempo()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 13))
                        Text("TAP TEMPO")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(accentCyan.opacity(0.25))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(accentCyan.opacity(0.6), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)

                // Delay BPM Sync Selector
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 10))
                        .foregroundColor(metronome.delaySyncMode != .off ? accentPurple : .white.opacity(0.3))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Echo Sync:")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))

                        Picker("", selection: $metronome.delaySyncMode) {
                            ForEach(DelaySyncSubdivision.allCases) { sub in
                                Text(sub.rawValue).tag(sub)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(metronome.delaySyncMode != .off ? accentPurple : .white.opacity(0.6))
                        .frame(width: 95)
                    }

                    if metronome.delaySyncMode != .off {
                        Text("\(Int(engine.delayTime * 1000))ms")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(accentPurple)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.03))
                )
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

    private func bpmButton(_ label: String, delta: Int) -> some View {
        Button(action: {
            metronome.bpm += delta
        }) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI
import AVFoundation

// MARK: - EffectsView — Reverb & Delay Controls

struct EffectsView: View {
    @ObservedObject var engine: AudioEngineManager

    var body: some View {
        VStack(spacing: 16) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0, green: 0.83, blue: 1.0).opacity(0.7))
                Text("EFFECTS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
                Spacer()
            }

            // Reverb Section
            reverbSection

            Divider()
                .background(Color.white.opacity(0.08))

            // Delay Section
            delaySection
        }
        .padding(20)
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

    // MARK: - Reverb

    private var reverbSection: some View {
        VStack(spacing: 12) {
            // Header with toggle
            HStack {
                Toggle(isOn: $engine.reverbEnabled) {
                    HStack(spacing: 6) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 11))
                            .foregroundColor(engine.reverbEnabled ? .cyan : .white.opacity(0.3))
                        Text("Reverb")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(engine.reverbEnabled ? .white : .white.opacity(0.4))
                    }
                }
                .toggleStyle(.switch)
                .tint(Color(red: 0, green: 0.83, blue: 1.0))
            }

            if engine.reverbEnabled {
                VStack(spacing: 10) {
                    // Preset picker
                    HStack {
                        Text("Preset")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Picker("", selection: $engine.reverbPreset) {
                            ForEach(reverbPresets) { preset in
                                Text(preset.name).tag(preset.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                        .tint(.white.opacity(0.8))
                    }

                    // Mix slider
                    effectSlider(
                        label: "Mix",
                        value: Binding(
                            get: { Double(engine.reverbWetDryMix) },
                            set: { engine.reverbWetDryMix = Float($0) }
                        ),
                        range: 0...100,
                        displayValue: "\(Int(engine.reverbWetDryMix))%",
                        color: .cyan
                    )
                }
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: engine.reverbEnabled)
    }

    // MARK: - Delay

    private var delaySection: some View {
        VStack(spacing: 12) {
            // Header with toggle
            HStack {
                Toggle(isOn: $engine.delayEnabled) {
                    HStack(spacing: 6) {
                        Image(systemName: "repeat")
                            .font(.system(size: 11))
                            .foregroundColor(engine.delayEnabled ? Color(red: 0.5, green: 0.4, blue: 1) : .white.opacity(0.3))
                        Text("Delay / Echo")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(engine.delayEnabled ? .white : .white.opacity(0.4))
                    }
                }
                .toggleStyle(.switch)
                .tint(Color(red: 0.5, green: 0.4, blue: 1))
            }

            if engine.delayEnabled {
                VStack(spacing: 10) {
                    // Delay time
                    effectSlider(
                        label: "Time",
                        value: Binding(
                            get: { engine.delayTime * 1000 },
                            set: { engine.delayTime = $0 / 1000 }
                        ),
                        range: 10...500,
                        displayValue: "\(Int(engine.delayTime * 1000))ms",
                        color: Color(red: 0.5, green: 0.4, blue: 1)
                    )

                    // Feedback
                    effectSlider(
                        label: "Feedback",
                        value: Binding(
                            get: { Double(engine.delayFeedback) },
                            set: { engine.delayFeedback = Float($0) }
                        ),
                        range: 0...80,
                        displayValue: "\(Int(engine.delayFeedback))%",
                        color: Color(red: 0.5, green: 0.4, blue: 1)
                    )

                    // Mix
                    effectSlider(
                        label: "Mix",
                        value: Binding(
                            get: { Double(engine.delayWetDryMix) },
                            set: { engine.delayWetDryMix = Float($0) }
                        ),
                        range: 0...100,
                        displayValue: "\(Int(engine.delayWetDryMix))%",
                        color: Color(red: 0.5, green: 0.4, blue: 1)
                    )
                }
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: engine.delayEnabled)
    }

    // MARK: - Reusable Slider

    private func effectSlider(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        displayValue: String,
        color: Color
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 56, alignment: .leading)

            Slider(value: value, in: range)
                .tint(color)

            Text(displayValue)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 44, alignment: .trailing)
        }
    }
}



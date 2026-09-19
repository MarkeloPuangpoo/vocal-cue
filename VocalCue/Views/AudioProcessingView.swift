import SwiftUI

// MARK: - AudioProcessingView — Vocal & In-Ear DSP Controls

struct AudioProcessingView: View {
    @ObservedObject var engine: AudioEngineManager

    private let accentCyan = Color(red: 0, green: 0.83, blue: 1.0)
    private let accentGreen = Color(red: 0, green: 0.9, blue: 0.5)
    private let accentPurple = Color(red: 0.5, green: 0.4, blue: 1.0)
    private let accentOrange = Color.orange

    var body: some View {
        VStack(spacing: 16) {
            // Section Header
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 10))
                    .foregroundColor(accentCyan.opacity(0.7))
                Text("AUDIO PROCESSING")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
                Spacer()
            }

            // 1. Noise Gate Section
            noiseGateSection

            Divider()
                .background(Color.white.opacity(0.08))

            // 2. EQ & Low-Cut Section
            equalizerSection

            Divider()
                .background(Color.white.opacity(0.08))

            // 3. Ear Safe Limiter Section
            limiterSection
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

    // MARK: - 1. Noise Gate Section

    private var noiseGateSection: some View {
        VStack(spacing: 12) {
            HStack {
                Toggle(isOn: $engine.noiseGateEnabled) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.badge.minus")
                            .font(.system(size: 12))
                            .foregroundColor(engine.noiseGateEnabled ? accentGreen : .white.opacity(0.3))
                        Text("Noise Gate")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(engine.noiseGateEnabled ? .white : .white.opacity(0.4))
                    }
                }
                .toggleStyle(.switch)
                .tint(accentGreen)

                Spacer()

                // Real-time Gate Status Pill
                if engine.noiseGateEnabled && engine.isRunning {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(engine.isGateOpen ? accentGreen : Color.white.opacity(0.2))
                            .frame(width: 6, height: 6)
                            .shadow(color: engine.isGateOpen ? accentGreen.opacity(0.8) : .clear, radius: 4)
                        Text(engine.isGateOpen ? "OPEN" : "MUTED")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundColor(engine.isGateOpen ? accentGreen : .white.opacity(0.3))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(engine.isGateOpen ? accentGreen.opacity(0.12) : Color.white.opacity(0.04))
                    )
                    .animation(.easeOut(duration: 0.1), value: engine.isGateOpen)
                }
            }

            if engine.noiseGateEnabled {
                VStack(spacing: 8) {
                    sliderRow(
                        label: "Threshold",
                        value: Binding(
                            get: { Double(engine.noiseGateThreshold) },
                            set: { engine.noiseGateThreshold = Float($0) }
                        ),
                        range: -60...(-20),
                        displayValue: "\(Int(engine.noiseGateThreshold)) dB",
                        color: accentGreen
                    )

                    Text("Suppresses room noise, air conditioners & fan hum when silent")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.35))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: engine.noiseGateEnabled)
    }

    // MARK: - 2. EQ & Low-Cut Section

    private var equalizerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Toggle(isOn: $engine.eqEnabled) {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.vertical.3")
                            .font(.system(size: 12))
                            .foregroundColor(engine.eqEnabled ? accentCyan : .white.opacity(0.3))
                        Text("3-Band EQ")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(engine.eqEnabled ? .white : .white.opacity(0.4))
                    }
                }
                .toggleStyle(.switch)
                .tint(accentCyan)

                Spacer()

                // Low-Cut (HPF 80Hz) Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        engine.lowCutEnabled.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.slash")
                            .font(.system(size: 9))
                        Text("Low-Cut 80Hz")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(engine.lowCutEnabled ? .black : .white.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(engine.lowCutEnabled ? accentCyan : Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .help("Filters sub-80Hz handling rumble & mic pops")
            }

            // Real-time Spectrum Analyzer & Graphical EQ Curve
            SpectrumEQView(
                spectrumAnalyzer: engine.spectrumAnalyzer,
                lowCutEnabled: engine.lowCutEnabled,
                eqEnabled: engine.eqEnabled,
                eqLowGain: engine.eqLowGain,
                eqMidGain: engine.eqMidGain,
                eqHighGain: engine.eqHighGain
            )

            if engine.eqEnabled {
                VStack(spacing: 10) {
                    // Low band (150Hz)
                    eqSliderRow(
                        label: "Bass",
                        sublabel: "150 Hz",
                        value: Binding(
                            get: { Double(engine.eqLowGain) },
                            set: { engine.eqLowGain = Float($0) }
                        ),
                        color: accentCyan
                    )

                    // Mid band (2.5kHz)
                    eqSliderRow(
                        label: "Mid",
                        sublabel: "2.5 kHz",
                        value: Binding(
                            get: { Double(engine.eqMidGain) },
                            set: { engine.eqMidGain = Float($0) }
                        ),
                        color: accentCyan
                    )

                    // High band (8kHz)
                    eqSliderRow(
                        label: "Treble",
                        sublabel: "8.0 kHz",
                        value: Binding(
                            get: { Double(engine.eqHighGain) },
                            set: { engine.eqHighGain = Float($0) }
                        ),
                        color: accentCyan
                    )

                    // Reset Flat Button
                    if engine.eqLowGain != 0 || engine.eqMidGain != 0 || engine.eqHighGain != 0 {
                        Button("Reset Flat (0 dB)") {
                            withAnimation(.easeOut(duration: 0.15)) {
                                engine.eqLowGain = 0
                                engine.eqMidGain = 0
                                engine.eqHighGain = 0
                            }
                        }
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 2)
                    }
                }
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: engine.eqEnabled)
    }

    // MARK: - 3. Ear Safe Limiter Section

    private var limiterSection: some View {
        VStack(spacing: 10) {
            HStack {
                Toggle(isOn: $engine.limiterEnabled) {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 12))
                            .foregroundColor(engine.limiterEnabled ? accentOrange : .white.opacity(0.3))
                        Text("Ear Safe Limiter")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(engine.limiterEnabled ? .white : .white.opacity(0.4))
                    }
                }
                .toggleStyle(.switch)
                .tint(accentOrange)

                Spacer()

                // Real-time Protection / Limiting Badge
                if engine.limiterEnabled {
                    HStack(spacing: 4) {
                        if engine.isLimiterActive {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .shadow(color: .red.opacity(0.9), radius: 4)
                            Text("LIMITING")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .foregroundColor(.red)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 8))
                                .foregroundColor(accentOrange.opacity(0.8))
                            Text("0 dBFS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(accentOrange.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(engine.isLimiterActive ? Color.red.opacity(0.15) : accentOrange.opacity(0.1))
                    )
                    .animation(.easeOut(duration: 0.1), value: engine.isLimiterActive)
                }
            }

            Text("Brickwall peak limiter prevents loud screeching, mic drops & screams from damaging your hearing")
                .font(.system(size: 9.5))
                .foregroundColor(.white.opacity(0.35))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
        }
    }

    // MARK: - Reusable UI Components

    private func eqSliderRow(
        label: String,
        sublabel: String,
        value: Binding<Double>,
        color: Color
    ) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Text(sublabel)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.3))
            }
            .frame(width: 58, alignment: .leading)

            Slider(value: value, in: -12...12)
                .tint(color)

            let v = value.wrappedValue
            Text(v > 0.05 ? String(format: "+%.1f dB", v) : (abs(v) <= 0.05 ? "0.0 dB" : String(format: "%.1f dB", v)))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(v != 0 ? color : .white.opacity(0.5))
                .frame(width: 58, alignment: .trailing)
        }
    }

    private func sliderRow(
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
                .frame(width: 58, alignment: .leading)

            Slider(value: value, in: range)
                .tint(color)

            Text(displayValue)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 54, alignment: .trailing)
        }
    }
}

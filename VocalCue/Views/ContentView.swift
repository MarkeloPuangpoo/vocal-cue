import SwiftUI
import CoreAudio

// MARK: - ContentView — Main Application UI

struct ContentView: View {
    @EnvironmentObject var engine: AudioEngineManager
    @State private var isPowerHovered = false
    @State private var powerPulse = false

    // Theme colors
    private let bgColor = Color(red: 0.06, green: 0.06, blue: 0.09)
    private let cardColor = Color(white: 0.10)
    private let cardBorder = Color(white: 0.16)
    private let accentCyan = Color(red: 0, green: 0.83, blue: 1.0)
    private let accentPurple = Color(red: 0.5, green: 0.4, blue: 1.0)
    private let accentGreen = Color(red: 0, green: 0.9, blue: 0.5)

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.07, blue: 0.12),
                    Color(red: 0.04, green: 0.04, blue: 0.06),
                    Color(red: 0.05, green: 0.04, blue: 0.08),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Warnings
                        warningsSection

                        // Power + Device Card
                        powerAndDeviceCard

                        // Mixer Card (Meters + Knobs)
                        mixerCard

                        // Audio Processing DSP (Noise Gate, EQ, Limiter)
                        AudioProcessingView(engine: engine)

                        // Effects Card (Reverb & Delay)
                        EffectsView(engine: engine)

                        // Live Audio Recording (Master Post-Effects WAV)
                        RecordingView(engine: engine)

                        // Status
                        statusBar
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(minWidth: 420, idealWidth: 440, maxWidth: 500)
        .frame(minHeight: 640, idealHeight: 720, maxHeight: 850)
        .onAppear {
            // Start pulse animation loop
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                powerPulse = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [accentCyan.opacity(0.3), accentPurple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: "headphones")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("VocalCue")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text("Virtual IEM & Vocal Studio")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(1.5)
            }

            Spacer()

            // Status pill
            statusPill
        }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(engine.isRunning ? accentGreen : Color.red.opacity(0.5))
                .frame(width: 7, height: 7)
                .shadow(color: engine.isRunning ? accentGreen.opacity(powerPulse ? 0.7 : 0.3) : .clear, radius: engine.isRunning ? 6 : 0)
            Text(engine.isRunning ? "LIVE" : "OFF")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundColor(engine.isRunning ? accentGreen : .white.opacity(0.35))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(engine.isRunning ? accentGreen.opacity(0.1) : Color.white.opacity(0.04))
                .overlay(
                    Capsule()
                        .stroke(engine.isRunning ? accentGreen.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.3), value: engine.isRunning)
    }

    // MARK: - Warnings

    @ViewBuilder
    private var warningsSection: some View {
        if engine.showSpeakerWarning {
            warningBanner(
                icon: "exclamationmark.triangle.fill",
                title: "ใช้หูฟังเท่านั้น!",
                subtitle: "ลำโพงจะทำให้เกิด Audio Feedback (เสียงหวีด)",
                color: .orange
            )
        }
        if engine.showClockWarning {
            warningBanner(
                icon: "clock.badge.exclamationmark",
                title: "Input/Output ใช้ clock คนละตัว",
                subtitle: "อาจเกิดเสียงกระตุก — แนะนำ built-in mic + หูฟังสาย",
                color: .yellow
            )
        }
    }

    private func warningBanner(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(color.opacity(0.7))
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Power + Device Card

    private var powerAndDeviceCard: some View {
        VStack(spacing: 20) {
            // Power button
            powerButton

            // Device selectors
            deviceSelectors
        }
        .padding(20)
        .background(cardBackground)
    }

    private var powerButton: some View {
        Button(action: { engine.toggle() }) {
            ZStack {
                // Outer glow ring (animated)
                Circle()
                    .stroke(
                        engine.isRunning ? accentCyan.opacity(powerPulse ? 0.4 : 0.15) : Color.white.opacity(0.04),
                        lineWidth: 2
                    )
                    .frame(width: 110, height: 110)
                    .shadow(color: engine.isRunning ? accentCyan.opacity(powerPulse ? 0.35 : 0.1) : .clear, radius: 16)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: powerPulse)

                // Inner body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: engine.isRunning
                                ? [accentCyan.opacity(0.2), accentCyan.opacity(0.05)]
                                : [Color.white.opacity(0.07), Color.white.opacity(0.02)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 48
                        )
                    )
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle()
                            .stroke(
                                engine.isRunning ? accentCyan.opacity(0.45) : Color.white.opacity(0.1),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

                // Power icon
                Image(systemName: "power")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(engine.isRunning ? accentCyan : .white.opacity(0.4))
                    .shadow(color: engine.isRunning ? accentCyan.opacity(0.6) : .clear, radius: 10)
            }
            .scaleEffect(isPowerHovered ? 1.04 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPowerHovered)
            .animation(.easeInOut(duration: 0.35), value: engine.isRunning)
        }
        .buttonStyle(.plain)
        .onHover { isPowerHovered = $0 }
    }

    // MARK: - Device Selectors

    private var deviceSelectors: some View {
        VStack(spacing: 10) {
            deviceRow(
                icon: "mic.fill",
                label: "Input",
                iconColor: accentCyan,
                selection: Binding(
                    get: { engine.deviceManager.selectedInputDeviceID ?? 0 },
                    set: { engine.deviceManager.selectedInputDeviceID = $0 }
                ),
                devices: engine.deviceManager.inputDevices
            )

            Divider()
                .background(Color.white.opacity(0.06))

            deviceRow(
                icon: "headphones",
                label: "Output",
                iconColor: accentPurple,
                selection: Binding(
                    get: { engine.deviceManager.selectedOutputDeviceID ?? 0 },
                    set: { engine.deviceManager.selectedOutputDeviceID = $0 }
                ),
                devices: engine.deviceManager.outputDevices
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    private func deviceRow(
        icon: String,
        label: String,
        iconColor: Color,
        selection: Binding<AudioDeviceID>,
        devices: [AudioDevice]
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 18)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 44, alignment: .leading)

            Picker("", selection: selection) {
                ForEach(devices) { device in
                    Text(device.name).tag(device.id)
                }
            }
            .pickerStyle(.menu)
            .tint(.white.opacity(0.7))
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Mixer Card (Meters + Knobs)

    private var mixerCard: some View {
        VStack(spacing: 16) {
            // Section label
            sectionHeader(icon: "slider.vertical.3", title: "MIXER")

            HStack(spacing: 0) {
                // Left meter
                StereoLevelMeterView(
                    leftLevel: engine.inputLevelLeft,
                    rightLevel: engine.inputLevelRight,
                    peak: engine.peakLevel
                )
                .frame(height: 160)
                .padding(.trailing, 12)

                Spacer()

                // Volume knob
                KnobView(
                    value: Binding(
                        get: { Double(engine.monitorVolume) },
                        set: { engine.monitorVolume = Float($0) }
                    ),
                    label: "Monitor",
                    displayText: "\(Int(engine.monitorVolume * 100))%",
                    accentColor: accentCyan,
                    size: 84,
                    defaultValue: 0.7
                )

                Spacer()

                // Gain knob
                KnobView(
                    value: Binding(
                        get: { Double(engine.micGain) / 2.0 },
                        set: { engine.micGain = Float($0) * 2.0 }
                    ),
                    label: "Mic Gain",
                    displayText: String(format: "%.1fx", engine.micGain),
                    accentColor: .orange,
                    size: 84,
                    defaultValue: 0.5
                )

                Spacer()

                // Right meter
                StereoLevelMeterView(
                    leftLevel: engine.inputLevelLeft,
                    rightLevel: engine.inputLevelRight,
                    peak: engine.peakLevel
                )
                .frame(height: 160)
                .padding(.leading, 12)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    // MARK: - Reusable Components

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(accentCyan.opacity(0.7))
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(2)
            Spacer()
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(cardColor.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Text("v1.2.0")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.15))

            Spacer()

            if engine.isRunning {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8))
                    Text("Latency ~10-20ms")
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(accentCyan.opacity(0.4))
            }

            Spacer()

            Text("⌘Q to quit")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.15))
        }
        .padding(.top, 8)
    }
}

import SwiftUI
import CoreAudio

// MARK: - Studio Rack Tab
enum StudioRackTab: String, CaseIterable, Identifiable {
    case dsp = "DSP & EQ"
    case effects = "FX & Tempo"
    case backing = "Backing Track"
    case recording = "Takes"
    case all = "All"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dsp: return "cpu"
        case .effects: return "metronome.fill"
        case .backing: return "music.note.list"
        case .recording: return "record.circle"
        case .all: return "square.grid.2x2"
        }
    }
}

// MARK: - ContentView — Main Application UI

struct ContentView: View {
    @EnvironmentObject var engine: AudioEngineManager
    @State private var isPowerHovered = false
    @State private var powerPulse = false
    @State private var selectedTab: StudioRackTab = .dsp

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
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Warnings
                        warningsSection

                        // Power + Device Card
                        powerAndDeviceCard

                        // Real-Time Vocal Pitch Meter Card
                        PitchMeterView(pitchDetector: engine.pitchDetector)

                        // Mixer Card (Meters + Knobs)
                        mixerCard

                        // Studio Rack Tab Bar
                        rackTabBar

                        // Dynamic Rack Content based on Selected Tab
                        if selectedTab == .dsp || selectedTab == .all {
                            AudioProcessingView(engine: engine)
                        }

                        if selectedTab == .effects || selectedTab == .all {
                            EffectsView(engine: engine)
                            MetronomeView(metronome: engine.metronomeManager, engine: engine)
                        }

                        if selectedTab == .backing || selectedTab == .all {
                            BackingTrackView(backingManager: engine.backingManager, engine: engine)
                        }

                        if selectedTab == .recording || selectedTab == .all {
                            RecordingView(engine: engine)
                        }

                        // Status
                        statusBar
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(minWidth: 440, idealWidth: 480, maxWidth: 540)
        .frame(minHeight: 680, idealHeight: 760, maxHeight: 920)
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
                    .frame(width: 34, height: 34)
                Image(systemName: "headphones")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("VocalCue")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text("Virtual IEM & Vocal Studio")
                    .font(.system(size: 9.5, weight: .medium))
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

    // MARK: - Rack Tab Bar

    private var rackTabBar: some View {
        HStack(spacing: 4) {
            ForEach(StudioRackTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 9))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    }
                    .foregroundColor(isSelected ? .white : .white.opacity(0.45))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? accentCyan.opacity(0.2) : Color.white.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? accentCyan.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.08).opacity(0.6))
        )
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
        VStack(spacing: 16) {
            powerButton
            deviceSelectors
        }
        .padding(18)
        .background(cardBackground)
    }

    private var powerButton: some View {
        Button(action: { engine.toggle() }) {
            ZStack {
                Circle()
                    .stroke(
                        engine.isRunning ? accentCyan.opacity(powerPulse ? 0.4 : 0.15) : Color.white.opacity(0.04),
                        lineWidth: 2
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: engine.isRunning ? accentCyan.opacity(powerPulse ? 0.35 : 0.1) : .clear, radius: 14)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: powerPulse)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: engine.isRunning
                                ? [accentCyan.opacity(0.2), accentCyan.opacity(0.05)]
                                : [Color.white.opacity(0.07), Color.white.opacity(0.02)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 42
                        )
                    )
                    .frame(width: 84, height: 84)
                    .overlay(
                        Circle()
                            .stroke(
                                engine.isRunning ? accentCyan.opacity(0.45) : Color.white.opacity(0.1),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 3)

                Image(systemName: "power")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(engine.isRunning ? accentCyan : .white.opacity(0.4))
                    .shadow(color: engine.isRunning ? accentCyan.opacity(0.6) : .clear, radius: 8)
            }
            .scaleEffect(isPowerHovered ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPowerHovered)
            .animation(.easeInOut(duration: 0.35), value: engine.isRunning)
        }
        .buttonStyle(.plain)
        .onHover { isPowerHovered = $0 }
    }

    // MARK: - Device Selectors

    private var deviceSelectors: some View {
        VStack(spacing: 8) {
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
        .padding(12)
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
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 16)

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
        VStack(spacing: 14) {
            sectionHeader(icon: "slider.vertical.3", title: "MASTER MONITOR & PREAMP")

            HStack(spacing: 0) {
                // Left meter
                StereoLevelMeterView(
                    leftLevel: engine.inputLevelLeft,
                    rightLevel: engine.inputLevelRight,
                    peak: engine.peakLevel
                )
                .frame(height: 145)
                .padding(.trailing, 10)

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
                    size: 80,
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
                    size: 80,
                    defaultValue: 0.5
                )

                Spacer()

                // Right meter
                StereoLevelMeterView(
                    leftLevel: engine.inputLevelLeft,
                    rightLevel: engine.inputLevelRight,
                    peak: engine.peakLevel
                )
                .frame(height: 145)
                .padding(.leading, 10)
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    // MARK: - Reusable Components

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(accentCyan.opacity(0.7))
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)
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
            Text("v1.3.0 Studio")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.2))

            Spacer()

            if engine.isRunning {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8))
                    Text("Low Latency ~10-20ms")
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(accentCyan.opacity(0.5))
            }

            Spacer()

            Text("⌘Q to quit")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.2))
        }
        .padding(.top, 6)
    }
}

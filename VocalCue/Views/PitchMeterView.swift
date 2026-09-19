import SwiftUI

// MARK: - PitchMeterView
/// Real-time vocal pitch tuner displaying Note name, frequency in Hz, and needle cents deviation (-50 to +50).
struct PitchMeterView: View {
    @ObservedObject var pitchDetector: PitchDetector

    private let accentCyan = Color(red: 0, green: 0.83, blue: 1.0)
    private let accentGreen = Color(red: 0, green: 0.9, blue: 0.5)
    private let accentOrange = Color.orange

    private var isInTune: Bool {
        pitchDetector.isVoiced && abs(pitchDetector.centsDeviation) <= 10.0
    }

    private var statusColor: Color {
        if !pitchDetector.isVoiced {
            return .white.opacity(0.3)
        }
        return isInTune ? accentGreen : accentCyan
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header Row: Section title & frequency
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "tuningfork")
                        .font(.system(size: 10))
                        .foregroundColor(accentCyan.opacity(0.8))
                    Text("PITCH METER")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(1.5)
                }

                Spacer()

                if pitchDetector.isVoiced {
                    Text(String(format: "%.1f Hz", pitchDetector.detectedFrequency))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .transition(.opacity)
                } else {
                    Text("Sing to detect")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.25))
                }
            }

            // Center: Large Note Readout & In-Tune Badge
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                // Large Note
                Text(pitchDetector.detectedNote)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(statusColor)
                    .shadow(color: pitchDetector.isVoiced ? statusColor.opacity(isInTune ? 0.7 : 0.3) : .clear, radius: 8)
                    .frame(minWidth: 70, alignment: .leading)
                    .animation(.easeOut(duration: 0.15), value: pitchDetector.detectedNote)

                Spacer()

                // Cents / Tuning Status Pill
                if pitchDetector.isVoiced {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                            .shadow(color: statusColor.opacity(0.8), radius: 4)

                        Text(isInTune ? "IN TUNE" : String(format: "%+.0f¢", pitchDetector.centsDeviation))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(statusColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.12))
                            .overlay(Capsule().stroke(statusColor.opacity(0.3), lineWidth: 1))
                    )
                }
            }

            // Bottom: Cents Deviation Meter (-50c to +50c)
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height

                ZStack(alignment: .leading) {
                    // Meter Track Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: height)

                    // In-Tune Sweet Zone (-10 to +10 cents)
                    let center = width / 2
                    let sweetZoneWidth = width * 0.2 // 20% of width centered
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accentGreen.opacity(0.18))
                        .frame(width: sweetZoneWidth, height: height)
                        .position(x: center, y: height / 2)

                    // Center Tick (0 cents)
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 1.5, height: height)
                        .position(x: center, y: height / 2)

                    // -50c and +50c Edge Ticks
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: height * 0.6)
                        .position(x: 4, y: height / 2)

                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: height * 0.6)
                        .position(x: width - 4, y: height / 2)

                    // Needle Indicator
                    if pitchDetector.isVoiced {
                        // Clamp cents between -50 and +50
                        let clampedCents = max(-50.0, min(Double(pitchDetector.centsDeviation), 50.0))
                        let needleX = center + (CGFloat(clampedCents) / 50.0) * (width / 2 - 6)

                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: statusColor.opacity(0.8), radius: 5)
                            .position(x: needleX, y: height / 2)
                            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.7), value: pitchDetector.centsDeviation)
                    }
                }
            }
            .frame(height: 12)

            // Scale Labels (-50 ♭ | 0 | +50 ♯)
            HStack {
                Text("-50 ♭")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
                Spacer()
                Text("0¢")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                Spacer()
                Text("+50 ♯")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.10).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(pitchDetector.isVoiced ? statusColor.opacity(0.25) : Color(white: 0.16), lineWidth: 1)
                )
        )
    }
}

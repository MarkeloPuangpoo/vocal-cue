import SwiftUI

// MARK: - SpectrumEQView
/// Interactive real-time Spectrum Analyzer & Graphical EQ Curve display.
struct SpectrumEQView: View {
    @ObservedObject var spectrumAnalyzer: SpectrumAnalyzer
    var lowCutEnabled: Bool
    var eqEnabled: Bool
    var eqLowGain: Float
    var eqMidGain: Float
    var eqHighGain: Float

    private let accentCyan = Color(red: 0, green: 0.83, blue: 1.0)
    private let accentPurple = Color(red: 0.5, green: 0.4, blue: 1.0)

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height

                ZStack {
                    // Background grid lines
                    gridOverlay(width: width, height: height)

                    // 1. Real-time Spectrum Analyzer Bars (Underneath)
                    spectrumBars(width: width, height: height)

                    // 2. Calculated EQ Transfer Function Curve (Foreground)
                    eqCurvePath(width: width, height: height)
                        .stroke(
                            LinearGradient(
                                colors: [accentCyan, accentPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                        .shadow(color: accentCyan.opacity(0.6), radius: 4)

                    // 3. Curve fill glow
                    eqCurveArea(width: width, height: height)
                        .fill(
                            LinearGradient(
                                colors: [accentCyan.opacity(0.12), accentPurple.opacity(0.04), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .frame(height: 100)
            .background(Color(white: 0.05).opacity(0.8))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            // Frequency scale markings
            HStack {
                Text("20Hz")
                Spacer()
                Text("100Hz")
                Spacer()
                Text("1kHz")
                Spacer()
                Text("10kHz")
                Spacer()
                Text("20kHz")
            }
            .font(.system(size: 8, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.3))
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Grid Overlay
    private func gridOverlay(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Horizontal Center line (0 dB)
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
                .position(x: width / 2, y: height / 2)

            // Horizontal +6dB / -6dB lines
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
                .position(x: width / 2, y: height * 0.25)

            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
                .position(x: width / 2, y: height * 0.75)

            // Vertical Frequency guide lines (100Hz, 1kHz, 10kHz)
            // Log map: x = log10(f / 20) / log10(20000 / 20)
            let logRange = log10(20000.0 / 20.0)
            let x100 = CGFloat(log10(100.0 / 20.0) / logRange) * width
            let x1k = CGFloat(log10(1000.0 / 20.0) / logRange) * width
            let x10k = CGFloat(log10(10000.0 / 20.0) / logRange) * width

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1, height: height)
                .position(x: x100, y: height / 2)

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1, height: height)
                .position(x: x1k, y: height / 2)

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1, height: height)
                .position(x: x10k, y: height / 2)
        }
    }

    // MARK: - Spectrum Analyzer Bars
    private func spectrumBars(width: CGFloat, height: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<SpectrumAnalyzer.numberOfBands, id: \.self) { i in
                let mag = CGFloat(i < spectrumAnalyzer.magnitudes.count ? spectrumAnalyzer.magnitudes[i] : 0.0)
                let barHeight = max(2, mag * (height * 0.9))

                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [accentCyan.opacity(0.55), accentPurple.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: barHeight)
                    .animation(.easeOut(duration: 0.08), value: mag)
            }
        }
        .frame(width: width, height: height, alignment: .bottom)
    }

    // MARK: - Mathematical EQ Response Curve
    /// Calculates the sum of Low-Cut, Bass Shelf, Mid Peak, and Treble Shelf across 60 points
    private func eqCurvePath(width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        let steps = 60
        let midY = height / 2
        let dbScale = (height * 0.42) / 12.0 // +/- 12 dB mapped to 42% height

        for step in 0...steps {
            let ratio = Double(step) / Double(steps)
            let freq = 20.0 * pow(1000.0, ratio) // 20 Hz to 20 kHz
            let x = CGFloat(ratio) * width

            var totalGainDB: Double = 0.0

            // 1. Low-Cut High-Pass (80Hz Butterworth 2nd order approximation)
            if lowCutEnabled {
                let fRatio = freq / 80.0
                let hpfMag = (fRatio * fRatio) / sqrt(1.0 + pow(fRatio, 4.0))
                let hpfDB = 20.0 * log10(max(hpfMag, 0.01))
                totalGainDB += max(hpfDB, -24.0)
            }

            // 2. 3-Band Parametric EQ
            if eqEnabled {
                // Bass Shelf (150Hz)
                let bassRatio = freq / 150.0
                let bassWeight = 1.0 / (1.0 + pow(bassRatio, 2.0))
                totalGainDB += Double(eqLowGain) * bassWeight

                // Mid Parametric (2.5kHz, Q=1.0)
                let midRatio = log2(freq / 2500.0)
                let midBell = exp(-0.5 * pow(midRatio / 0.7, 2.0))
                totalGainDB += Double(eqMidGain) * midBell

                // Treble Shelf (8kHz)
                let trebleRatio = freq / 8000.0
                let trebleWeight = pow(trebleRatio, 2.0) / (1.0 + pow(trebleRatio, 2.0))
                totalGainDB += Double(eqHighGain) * trebleWeight
            }

            // Invert Y because SwiftUI coordinates (0 is top)
            let y = midY - CGFloat(totalGainDB) * dbScale
            let clampedY = max(2, min(y, height - 2))

            if step == 0 {
                path.move(to: CGPoint(x: x, y: clampedY))
            } else {
                path.addLine(to: CGPoint(x: x, y: clampedY))
            }
        }

        return path
    }

    private func eqCurveArea(width: CGFloat, height: CGFloat) -> Path {
        var path = eqCurvePath(width: width, height: height)
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}

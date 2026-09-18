import SwiftUI

// MARK: - LevelMeterView — Vertical VU Meter Bar

struct LevelMeterView: View {
    var level: Float       // in dB, typically -60 to 0
    var peak: Float        // in dB
    var label: String = "L"
    var barWidth: CGFloat = 14

    // dB range
    private let minDB: Float = -60
    private let maxDB: Float = 0

    private var normalizedLevel: CGFloat {
        CGFloat((level - minDB) / (maxDB - minDB)).clamped(to: 0...1)
    }

    private var normalizedPeak: CGFloat {
        CGFloat((peak - minDB) / (maxDB - minDB)).clamped(to: 0...1)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Clip indicator
            Circle()
                .fill(peak > -3 ? Color.red : Color(white: 0.15))
                .frame(width: 8, height: 8)
                .shadow(color: peak > -3 ? .red.opacity(0.6) : .clear, radius: 4)

            // Meter bar
            GeometryReader { geo in
                let height = geo.size.height

                ZStack(alignment: .bottom) {
                    // Background track with subtle segments
                    VStack(spacing: 1) {
                        ForEach(0..<30, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white.opacity(0.04))
                                .frame(height: max(1, (height / 30) - 1))
                        }
                    }
                    .frame(width: barWidth)

                    // Level fill — segmented bars with gradient
                    VStack(spacing: 1) {
                        let segmentCount = 30
                        let activeSegments = Int(normalizedLevel * CGFloat(segmentCount))

                        ForEach(0..<segmentCount, id: \.self) { i in
                            let reversedIndex = segmentCount - 1 - i
                            let isActive = reversedIndex < activeSegments
                            let segmentColor = colorForSegment(position: CGFloat(reversedIndex) / CGFloat(segmentCount))

                            RoundedRectangle(cornerRadius: 1)
                                .fill(isActive ? segmentColor : Color.clear)
                                .frame(height: max(1, (height / CGFloat(segmentCount)) - 1))
                        }
                    }
                    .frame(width: barWidth)
                    .animation(.linear(duration: 0.06), value: normalizedLevel)

                    // Peak hold indicator
                    if normalizedPeak > 0.02 {
                        let peakColor = normalizedPeak > 0.95 ? Color.red :
                                        normalizedPeak > 0.75 ? Color.yellow : Color(red: 0, green: 1, blue: 0.53)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(peakColor)
                            .frame(width: barWidth + 2, height: 2)
                            .offset(y: -(height * normalizedPeak - 1))
                            .shadow(color: peakColor.opacity(0.4), radius: 2)
                            .animation(.linear(duration: 0.06), value: normalizedPeak)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Channel label
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(width: barWidth + 8)
    }

    /// Segmented color: green at bottom, yellow in upper third, red at top
    private func colorForSegment(position: CGFloat) -> Color {
        if position > 0.9 {
            return Color(red: 1.0, green: 0.2, blue: 0.3)     // Red
        } else if position > 0.75 {
            return Color(red: 1.0, green: 0.7, blue: 0.0)     // Yellow/Orange
        } else if position > 0.6 {
            return Color(red: 0.6, green: 0.9, blue: 0.0)     // Yellow-Green
        } else {
            return Color(red: 0.0, green: 0.85, blue: 0.45)   // Green
        }
    }
}

// MARK: - Stereo Level Meter

struct StereoLevelMeterView: View {
    var leftLevel: Float
    var rightLevel: Float
    var peak: Float

    var body: some View {
        HStack(spacing: 3) {
            LevelMeterView(level: leftLevel, peak: peak, label: "L")
            LevelMeterView(level: rightLevel, peak: peak, label: "R")
        }
    }
}

// MARK: - Comparable Clamped Extension

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

import SwiftUI
import AppKit

// MARK: - KnobArcShape

struct KnobArcShape: Shape {
    var fraction: Double
    let startAngle: Double = 135
    let totalSweep: Double = 270

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(startAngle + totalSweep * max(0.001, fraction)),
            clockwise: false
        )
        return path
    }
}

// MARK: - KnobView — Custom Rotary Control

struct KnobView: View {
    @Binding var value: Double  // 0.0 ... 1.0
    var label: String
    var displayText: String
    var accentColor: Color = Color(red: 0, green: 0.83, blue: 1.0)
    var size: CGFloat = 80
    var defaultValue: Double? = nil

    @State private var isHovered = false
    @State private var dragStartValue: Double? = nil
    @State private var lastClickTime: Date = .distantPast

    // Arc parameters: 270° sweep from 135° to 405° (bottom-left to bottom-right through top)
    private let startAngle: Double = 135
    private let totalSweep: Double = 270
    private let trackWidth: CGFloat = 5

    // Concentric sizing
    private var arcSize: CGFloat {
        size - trackWidth
    }

    private var knobSize: CGFloat {
        size - trackWidth * 2 - 10
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // Outer subtle ambient glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColor.opacity(isHovered ? 0.08 : 0.02),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: knobSize / 2,
                            endRadius: size / 2 + 12
                        )
                    )
                    .frame(width: size + 24, height: size + 24)

                // Knob body
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.17),
                                Color(white: 0.09)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 3)
                    .overlay(
                        Circle()
                            .stroke(
                                isHovered ? accentColor.opacity(0.35) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                            .frame(width: knobSize, height: knobSize)
                    )

                // Inactive arc track (background ring)
                KnobArcShape(fraction: 1.0)
                    .stroke(
                        Color.white.opacity(0.08),
                        style: StrokeStyle(lineWidth: trackWidth, lineCap: .round)
                    )
                    .frame(width: arcSize, height: arcSize)

                // Active arc track
                if value > 0.002 {
                    KnobArcShape(fraction: value)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [accentColor.opacity(0.55), accentColor]),
                                center: .center,
                                startAngle: .degrees(startAngle),
                                endAngle: .degrees(startAngle + totalSweep * max(0.01, value))
                            ),
                            style: StrokeStyle(lineWidth: trackWidth, lineCap: .round)
                        )
                        .frame(width: arcSize, height: arcSize)
                        .shadow(
                            color: accentColor.opacity(isHovered ? 0.6 : 0.25),
                            radius: isHovered ? 8 : 4
                        )
                }

                // Notch indicator on knob body perimeter (pointing toward active arc)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(accentColor)
                    .frame(width: 3, height: 9)
                    .offset(y: -(knobSize / 2 - 5.5))
                    .rotationEffect(.degrees(-135 + totalSweep * value))
                    .shadow(color: accentColor.opacity(0.7), radius: 3)

                // Center value display
                Text(displayText)
                    .font(.system(size: knobSize * 0.22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .allowsHitTesting(false)
            }
            .frame(width: size + 24, height: size + 24)
            .contentShape(Circle())
            .gesture(dragGesture)
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovered)

            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(isHovered ? 0.65 : 0.4))
                .textCase(.uppercase)
                .tracking(1.5)
                .animation(.easeOut(duration: 0.15), value: isHovered)
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let baseValue = dragStartValue ?? value
                if dragStartValue == nil {
                    dragStartValue = baseValue
                }

                let isShift = NSEvent.modifierFlags.contains(.shift)
                let sensitivity: CGFloat = isShift ? 350.0 : 120.0

                // Linear translation: drag UP or RIGHT to increase, DOWN or LEFT to decrease
                let dy = gesture.translation.height
                let dx = gesture.translation.width
                let linearDelta = Double((-dy + dx) / sensitivity)

                // Rotary translation: relative angle around center
                let boxSize = size + 24
                let center = CGPoint(x: boxSize / 2, y: boxSize / 2)
                let v0 = CGPoint(x: gesture.startLocation.x - center.x, y: gesture.startLocation.y - center.y)
                let v1 = CGPoint(x: gesture.location.x - center.x, y: gesture.location.y - center.y)
                let r0 = hypot(v0.x, v0.y)

                var delta = linearDelta

                // If user dragged from knob body or outer ring, check for rotational motion
                if r0 > 10 {
                    let a0 = atan2(v0.y, v0.x)
                    let a1 = atan2(v1.y, v1.x)
                    var diff = a1 - a0
                    while diff > .pi { diff -= 2 * .pi }
                    while diff < -.pi { diff += 2 * .pi }

                    let sweepRad = totalSweep * .pi / 180.0
                    let rotaryDelta = Double(diff / sweepRad) * (isShift ? 0.25 : 1.0)

                    if abs(rotaryDelta) > abs(linearDelta) * 0.6 {
                        delta = rotaryDelta
                    }
                }

                value = min(max(baseValue + delta, 0.0), 1.0)
            }
            .onEnded { gesture in
                dragStartValue = nil

                // Double click to reset to default
                let now = Date()
                if hypot(gesture.translation.width, gesture.translation.height) < 4 {
                    if now.timeIntervalSince(lastClickTime) < 0.35 {
                        if let def = defaultValue {
                            withAnimation(.easeOut(duration: 0.15)) {
                                value = def
                            }
                        }
                    }
                    lastClickTime = now
                }
            }
    }
}

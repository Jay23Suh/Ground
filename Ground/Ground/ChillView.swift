import SwiftUI
import AppKit

// MARK: - Ripple (thin expanding ring)

private struct Ripple: Identifiable {
    let id = UUID()
    let color: Color
}

private struct RippleRing: View {
    let color: Color
    let onComplete: () -> Void
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 0.55

    var body: some View {
        Circle()
            .stroke(color.opacity(opacity), lineWidth: 1.5)
            .frame(width: 100, height: 100)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeOut(duration: 2.2)) {
                    scale = 5.5
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { onComplete() }
            }
    }
}

// MARK: - Click Orb (spawns at tap position, floats up and fades)

private struct ClickOrb: Identifiable {
    let id = UUID()
    let position: CGPoint
    let color: Color
}

private struct ClickOrbView: View {
    let color: Color
    let onComplete: () -> Void
    @State private var offset: CGFloat = 0
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0.8

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [color.opacity(opacity), color.opacity(opacity * 0.3), .clear],
                    center: .center, startRadius: 0, endRadius: 28
                ))
                .frame(width: 56, height: 56)
            Circle()
                .fill(color.opacity(opacity * 0.15))
                .frame(width: 56, height: 56)
                .blur(radius: 8)
        }
        .scaleEffect(scale)
        .offset(y: offset)
        .onAppear {
            withAnimation(.easeOut(duration: 2.5)) {
                offset  = -140
                scale   = 1.6
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { onComplete() }
        }
    }
}

// MARK: - Drawn Path (smooth continuous stroke that fades after drag ends)

private struct DrawnPath: Identifiable {
    let id = UUID()
    let points: [CGPoint]
    let color: Color
}

private struct SmoothPath: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard points.count >= 2 else { return p }
        p.move(to: points[0])
        for i in 0..<points.count - 1 {
            let mid = CGPoint(x: (points[i].x + points[i + 1].x) / 2,
                              y: (points[i].y + points[i + 1].y) / 2)
            p.addQuadCurve(to: mid, control: points[i])
        }
        p.addLine(to: points[points.count - 1])
        return p
    }
}

private struct DrawnPathView: View {
    let path: DrawnPath
    let onComplete: () -> Void
    @State private var opacity: Double = 0.5

    var body: some View {
        SmoothPath(points: path.points)
            .stroke(
                path.color.opacity(opacity),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
            .blur(radius: 2.5)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 4.0).delay(0.2)) { opacity = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) { onComplete() }
            }
    }
}

// MARK: - Pulse Flash (full-screen bloom on keypress)

private struct PulseFlash: Identifiable {
    let id = UUID()
    let color: Color
}

private struct PulseFlashView: View {
    let color: Color
    let onComplete: () -> Void
    @State private var opacity: Double = 0.18

    var body: some View {
        RadialGradient(
            colors: [color.opacity(opacity), color.opacity(opacity * 0.3), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 500
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            // Hold briefly then fade
            withAnimation(.easeOut(duration: 0.08)) { opacity = 0.22 }
            withAnimation(.easeOut(duration: 0.6).delay(0.08)) { opacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { onComplete() }
        }
    }
}

// MARK: - AppKit mouse handler (reliable in full screen)

private class MouseTrackingView: NSView {
    var onMove: ((CGPoint) -> Void)?
    var onUp:   ((CGPoint, Bool) -> Void)?  // isTap

    private var downPoint: NSPoint = .zero
    private var dragging  = false

    override var acceptsFirstResponder: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { self }

    override func mouseDown(with event: NSEvent) {
        downPoint = convert(event.locationInWindow, from: nil)
        dragging  = false
    }

    override func mouseDragged(with event: NSEvent) {
        let p    = convert(event.locationInWindow, from: nil)
        let dist = hypot(p.x - downPoint.x, p.y - downPoint.y)
        guard dist > 4 else { return }
        dragging = true
        onMove?(flip(p))
    }

    override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        onUp?(flip(p), !dragging)
        dragging = false
    }

    // NSView Y is bottom-up; flip to SwiftUI top-down
    private func flip(_ p: NSPoint) -> CGPoint {
        CGPoint(x: p.x, y: bounds.height - p.y)
    }
}

private struct MouseHandler: NSViewRepresentable {
    let onMove: (CGPoint) -> Void
    let onUp:   (CGPoint, Bool) -> Void

    func makeNSView(context: Context) -> MouseTrackingView {
        let v = MouseTrackingView()
        v.onMove = onMove
        v.onUp   = onUp
        return v
    }

    func updateNSView(_ v: MouseTrackingView, context: Context) {
        v.onMove = onMove
        v.onUp   = onUp
    }
}

// MARK: - ChillView

struct ChillView: View {
    @StateObject private var audio = ChillAudio()

    // Ambient orb drift phases
    @State private var p1 = false
    @State private var p2 = false
    @State private var p3 = false
    @State private var p4 = false
    @State private var p5 = false

    // Central orb rotation
    @State private var orbAngle: Double  = 0
    @State private var orbAngle2: Double = 0

    // Breath — animates the whole scene
    @State private var orbBreath: CGFloat = 1.0

    // Interaction
    @State private var mousePos: CGPoint = .zero
    @State private var mouseVisible = false
    @State private var ripples: [Ripple] = []
    @State private var pulseFlashes: [PulseFlash] = []
    @State private var clickOrbs: [ClickOrb] = []
    @State private var finishedPaths: [DrawnPath] = []
    @State private var activePoints: [CGPoint] = []
    @State private var activeColor: Color = .rPink
    @State private var keyMonitor: Any?

    private let rippleColors: [Color] = [.rPink, .rMint, .rLavender]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {

                // ── Breathing layer: mist + orb scale together ───────────
                ZStack {
                    mistLayer(w: w, h: h)
                    centralOrb
                }
                .scaleEffect(orbBreath)

                // ── Mouse glow (doesn't breathe) ─────────────────────────
                if mouseVisible {
                    RadialGradient(
                        colors: [Color.white.opacity(0.07), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 110
                    )
                    .frame(width: 220, height: 220)
                    .position(mousePos)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }

                // ── Pulse flashes (full-screen bloom) ────────────────────
                ForEach(pulseFlashes) { f in
                    PulseFlashView(color: f.color) {
                        pulseFlashes.removeAll { $0.id == f.id }
                    }
                }

                // ── Completed strokes (fading) ───────────────────────────
                ForEach(finishedPaths) { p in
                    DrawnPathView(path: p) {
                        finishedPaths.removeAll { $0.id == p.id }
                    }
                }

                // ── Active stroke (live, being drawn) ────────────────────
                if activePoints.count >= 2 {
                    SmoothPath(points: activePoints)
                        .stroke(
                            activeColor.opacity(0.5),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                        .blur(radius: 2.5)
                        .allowsHitTesting(false)
                }

                // ── Click orbs (float up from tap position) ──────────────
                ForEach(clickOrbs) { o in
                    ClickOrbView(color: o.color) {
                        clickOrbs.removeAll { $0.id == o.id }
                    }
                    .position(o.position)
                }

                // ── Ripple rings (centered) ──────────────────────────────
                ForEach(ripples) { r in
                    RippleRing(color: r.color) {
                        ripples.removeAll { $0.id == r.id }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                MouseHandler(
                    onMove: { pos in
                        if activePoints.isEmpty {
                            activeColor = rippleColors.randomElement()!
                            activePoints.append(pos)
                            audio.setDragging(true)
                        } else {
                            let last = activePoints.last!
                            guard hypot(pos.x - last.x, pos.y - last.y) >= 5 else { return }
                            activePoints.append(pos)
                        }
                    },
                    onUp: { pos, isTap in
                        audio.setDragging(false)
                        if !isTap && activePoints.count >= 2 {
                            finishedPaths.append(DrawnPath(points: activePoints, color: activeColor))
                        } else if isTap {
                            clickOrbs.append(ClickOrb(position: pos, color: rippleColors.randomElement()!))
                            audio.onTap()
                        }
                        activePoints = []
                    }
                )
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let loc):
                    mousePos = loc
                    audio.updateMousePosition(x: loc.x, y: loc.y, width: w, height: h)
                    withAnimation(.easeIn(duration: 0.15)) { mouseVisible = true }
                case .ended:
                    withAnimation(.easeOut(duration: 0.6)) { mouseVisible = false }
                }
            }
            .onAppear { startAnimations(); audio.start() }
            .onDisappear {
                if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
                audio.stop()
            }
            // Stop when app loses focus (switch to another app or window)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                audio.stop()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                audio.start()
            }
        }
    }

    // MARK: - Mist Layer

    private func mistLayer(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.rPink.opacity(0.38), .clear],
                                     center: .center, startRadius: 0, endRadius: 200))
                .frame(width: 420, height: 420)
                .blur(radius: 60)
                .offset(x: p1 ? -w * 0.22 : -w * 0.10, y: p1 ? -h * 0.20 : h * 0.07)

            Circle()
                .fill(RadialGradient(colors: [Color.rMint.opacity(0.32), .clear],
                                     center: .center, startRadius: 0, endRadius: 185))
                .frame(width: 370, height: 370)
                .blur(radius: 55)
                .offset(x: p2 ? w * 0.28 : w * 0.16, y: p2 ? h * 0.22 : h * 0.10)

            Circle()
                .fill(RadialGradient(colors: [Color.rLavender.opacity(0.28), .clear],
                                     center: .center, startRadius: 0, endRadius: 165))
                .frame(width: 330, height: 330)
                .blur(radius: 48)
                .offset(x: p3 ? w * 0.12 : -w * 0.06, y: p3 ? -h * 0.08 : h * 0.06)

            Circle()
                .fill(RadialGradient(colors: [Color(hex: "#4A7FD4").opacity(0.22), .clear],
                                     center: .center, startRadius: 0, endRadius: 150))
                .frame(width: 300, height: 300)
                .blur(radius: 45)
                .offset(x: p4 ? -w * 0.20 : -w * 0.08, y: p4 ? h * 0.18 : h * 0.06)

            Circle()
                .fill(RadialGradient(colors: [Color.rOrange.opacity(0.12), .clear],
                                     center: .center, startRadius: 0, endRadius: 130))
                .frame(width: 260, height: 260)
                .blur(radius: 42)
                .offset(x: p5 ? w * 0.24 : w * 0.12, y: p5 ? -h * 0.20 : -h * 0.08)
        }
    }

    // MARK: - Central Orb

    private var centralOrb: some View {
        ZStack {
            // ── Base: rotating color gradients ──────────────────────────
            ZStack {
                Circle()
                    .fill(AngularGradient(
                        colors: [
                            Color.rPink.opacity(0.9),
                            Color.rLavender.opacity(0.75),
                            Color.rMint.opacity(0.80),
                            Color.rPink.opacity(0.45),
                            Color.rLavender.opacity(0.90),
                            Color.rPink.opacity(0.9)
                        ],
                        center: .center
                    ))
                    .rotationEffect(.degrees(orbAngle))

                Circle()
                    .fill(AngularGradient(
                        colors: [
                            Color.rMint.opacity(0.65),
                            Color(hex: "#4A7FD4").opacity(0.40),
                            Color.rLavender.opacity(0.70),
                            Color.rPink.opacity(0.50),
                            Color.rMint.opacity(0.65)
                        ],
                        center: .center
                    ))
                    .rotationEffect(.degrees(-orbAngle2))
                    .blendMode(.plusLighter)
            }
            .blur(radius: 22)

            // ── Frosted glass body ───────────────────────────────────────
            Circle()
                .fill(Color.white.opacity(0.05))

            // ── Top specular highlight (light hitting the glass surface) ─
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.12), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 190, height: 85)
                .blur(radius: 7)
                .offset(x: -12, y: -118)

            // ── Bottom inner shadow (glass depth) ───────────────────────
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.clear, Color.black.opacity(0.18)],
                        center: UnitPoint(x: 0.5, y: 0.75),
                        startRadius: 90, endRadius: 180
                    )
                )

            // ── Rim light (bright top-left, fades to nothing) ───────────
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.50),
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
        .frame(width: 360, height: 360)
        .clipShape(Circle())
        .mask(
            RadialGradient(
                colors: [.white, .white, .white.opacity(0.65), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 180
            )
        )
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true))  { p1 = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 15).repeatForever(autoreverses: true)) { p2 = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) { p3 = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) { p4 = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) { p5 = true }
        }

        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) { orbAngle  = 360 }
        withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { orbAngle2 = 360 }

        // Whole-scene breath: slow 4s inhale / 4s exhale
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { orbBreath = 1.06 }

        // Keypress: full-screen bloom + ring + audio swell
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            DispatchQueue.main.async {
                let color = rippleColors.randomElement()!
                pulseFlashes.append(PulseFlash(color: color))
                ripples.append(Ripple(color: color))
                audio.onKeyPress()
            }
            // Let system shortcuts (Cmd, Ctrl) through; consume others to silence macOS funk sound
            let isSystemShortcut = event.modifierFlags.contains(.command)
                                || event.modifierFlags.contains(.control)
            return isSystemShortcut ? event : nil
        }
    }
}

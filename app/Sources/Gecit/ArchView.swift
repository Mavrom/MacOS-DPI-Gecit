import AppKit
import SwiftUI

/// Uygulamanın kalbi: bir kemer (geçit). Açıkken içinden paketler akar ve kemer parlar;
/// kapanınca söner, önüne bir sürgü iner ve paketler sürgünün altında kalır.
struct ArchView: View {
    enum Mode: Equatable { case open, warning, closed }

    var mode: Mode
    var particles: Int = 46
    var drawsBackground = false

    @State private var from: Double = 1
    @State private var to: Double = 1
    @State private var changedAt = Date.distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size, date: reduceMotion ? Date() : timeline.date)
            }
        }
        .onAppear {
            let v = Self.target(mode)
            from = v
            to = v
        }
        .onChange(of: mode) { newMode in
            from = openness(at: Date())
            to = Self.target(newMode)
            // Hareket azaltıldığında zaman çizelgesi durur; geçiş beklenmeden yeni hâle geçilir.
            changedAt = reduceMotion ? .distantPast : Date()
        }
        .accessibilityElement()
        .accessibilityLabel(mode == .closed ? "Geçit kapalı" : "Geçit açık")
    }

    private static func target(_ m: Mode) -> Double { m == .closed ? 0 : 1 }

    /// 0 (kapalı) ile 1 (açık) arası, 0,9 saniyelik yumuşak geçişle.
    private func openness(at date: Date) -> Double {
        let p =min(1, max(0, date.timeIntervalSince(changedAt) / 0.9))
        let eased = p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
        return from + (to - from) * eased
    }

    private func draw(in ctx: inout GraphicsContext, size: CGSize, date: Date) {
        let W = size.width, H = size.height
        let s = min(W, H) / 200
        let open = openness(at: date)
        let tint = mode == .warning ? Palette.amber : Palette.glow
        let cx = W / 2
        let base = H * 0.82
        let barY = H * 0.58

        if drawsBackground {
            ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 22 * s, style: .continuous),
                     with: .color(Palette.night))
        }

        func arch(_ inset: CGFloat) -> Path {
            var p = Path()
            let w = (59 - inset) * s
            let top = H * 0.2 + inset * s
            p.move(to: CGPoint(x: cx - w, y: base))
            p.addLine(to: CGPoint(x: cx - w, y: top + w))
            p.addArc(center: CGPoint(x: cx, y: top + w), radius: w,
                     startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            p.addLine(to: CGPoint(x: cx + w, y: base))
            return p
        }

        // İçerideki ışık ve akan paketler
        let t = date.timeIntervalSinceReferenceDate
        ctx.drawLayer { layer in
            var inner = arch(5)
            inner.closeSubpath()
            layer.clip(to: inner)
            layer.fill(Path(CGRect(origin: .zero, size: size)),
                       with: .radialGradient(Gradient(colors: [tint.opacity(0.55 * open), tint.opacity(0)]),
                                             center: CGPoint(x: cx, y: H * 0.6),
                                             startRadius: 2 * s, endRadius: 88 * s))
            let travel = base - H * 0.12
            for i in 0..<particles {
                let speed = 0.10 + Self.rand(i, 2) * 0.22
                let progress = (Self.rand(i, 3) + t * speed).truncatingRemainder(dividingBy: 1)
                let y = base - progress * travel
                let x = cx + (Self.rand(i, 1) - 0.5) * 64 * s
                let fade = min(1, progress * 6) * min(1, (1 - progress) * 4)
                // Sürgünün üstüne yalnızca geçit açıkken çıkabilirler.
                let gate = y < barY ? open : 1
                let alpha = (0.3 + 0.7 * open) * fade * gate
                guard alpha > 0.01 else { continue }
                let r = (0.5 + Self.rand(i, 4) * 0.9) * s
                layer.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                           with: .color(tint.opacity(alpha)))
            }
        }

        let stroke = StrokeStyle(lineWidth: 4.5 * s, lineCap: .round, lineJoin: .round)
        // Parıltı
        if open > 0.02 {
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 9 * s))
                layer.stroke(arch(0), with: .color(tint.opacity(0.85 * open)), style: stroke)
            }
        }
        // Kemerin kendisi: kapalıyken kül rengi
        ctx.stroke(arch(0), with: .color(Palette.ash.opacity(0.6 * (1 - open))), style: stroke)
        ctx.stroke(arch(0),
                   with: .linearGradient(Gradient(colors: [tint.opacity(0.35 + 0.65 * open), tint.opacity(0.08 + 0.25 * open)]),
                                         startPoint: CGPoint(x: cx, y: H * 0.2), endPoint: CGPoint(x: cx, y: base)),
                   style: StrokeStyle(lineWidth: 4.5 * s * open, lineCap: .round, lineJoin: .round))
        // Sürgü
        if open < 0.98 {
            var bar = Path()
            bar.move(to: CGPoint(x: cx - 46 * s, y: barY))
            bar.addLine(to: CGPoint(x: cx + 46 * s, y: barY))
            ctx.stroke(bar, with: .color(Color(hex: 0x96A5A0).opacity(1 - open)),
                       style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))
        }
        // Zemin
        var ground = Path()
        ground.move(to: CGPoint(x: W * 0.12, y: base))
        ground.addLine(to: CGPoint(x: W * 0.88, y: base))
        ctx.stroke(ground, with: .color(tint.opacity(0.18)), lineWidth: 1 * s)
    }

    /// Her parçacık için sabit, tekrarlanabilir rastgele sayı (0..<1).
    private static func rand(_ i: Int, _ k: Int) -> Double {
        var x = UInt64(truncatingIfNeeded: i) &* 0x9E37_79B9_7F4A_7C15 &+ UInt64(truncatingIfNeeded: k) &* 0xD1B5_4A32_D192_ED03
        x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
        x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
        x ^= x >> 31
        return Double(x % 10_000) / 10_000
    }
}

/// Menü çubuğu simgesi: kemer. Açıkken içi dolu, kapalıyken önünde sürgü.
enum MenuBarIcon {
    static func image(open: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()
            let arch = NSBezierPath()
            arch.lineWidth = 1.7
            arch.lineCapStyle = .round
            arch.lineJoinStyle = .round
            arch.move(to: NSPoint(x: 4, y: 3))
            arch.line(to: NSPoint(x: 4, y: 9.5))
            arch.appendArc(withCenter: NSPoint(x: 9, y: 9.5), radius: 5, startAngle: 180, endAngle: 0, clockwise: true)
            arch.line(to: NSPoint(x: 14, y: 3))
            arch.stroke()

            let ground = NSBezierPath()
            ground.lineWidth = 1.5
            ground.lineCapStyle = .round
            ground.move(to: NSPoint(x: 1.8, y: 2.2))
            ground.line(to: NSPoint(x: 16.2, y: 2.2))
            ground.stroke()

            if open {
                NSBezierPath(roundedRect: NSRect(x: 6.6, y: 2.2, width: 4.8, height: 8.2), xRadius: 2.4, yRadius: 2.4).fill()
            } else {
                let bar = NSBezierPath()
                bar.lineWidth = 1.5
                bar.lineCapStyle = .round
                bar.move(to: NSPoint(x: 6, y: 7))
                bar.line(to: NSPoint(x: 12, y: 7))
                bar.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

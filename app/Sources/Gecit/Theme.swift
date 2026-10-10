import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// Açık ve koyu temada ayrı değer alan renk.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let h = isDark ? dark : light
            return NSColor(srgbRed: CGFloat((h >> 16) & 0xFF) / 255,
                           green: CGFloat((h >> 8) & 0xFF) / 255,
                           blue: CGFloat(h & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

/// Tasarım önizlemesindeki renk sistemi (mockup/gecit.html ile aynı değerler).
enum Palette {
    static let window = Color.dynamic(light: 0xF7F9F8, dark: 0x111917)
    static let card = Color.dynamic(light: 0xFFFFFF, dark: 0x18221F)
    static let line = Color.dynamic(light: 0xDFE6E3, dark: 0x25322E)
    static let chip = Color.dynamic(light: 0xEEF3F1, dark: 0x1F2B28)
    static let fg = Color.dynamic(light: 0x16201D, dark: 0xE7F1ED)
    static let muted = Color.dynamic(light: 0x5F6D68, dark: 0x8FA29B)
    static let pass = Color.dynamic(light: 0x0FA77B, dark: 0x3DDCAB)
    static let passSoft = Color.dynamic(light: 0xD9F3EA, dark: 0x12352B)
    static let warn = Color.dynamic(light: 0xC98512, dark: 0xF0B443)
    static let warnSoft = Color.dynamic(light: 0xF8ECD3, dark: 0x3A2C10)
    static let stop = Color.dynamic(light: 0xD2453B, dark: 0xFF7A6E)
    static let stopSoft = Color.dynamic(light: 0xF8DFDC, dark: 0x3B1A17)
    static let accent = Color.dynamic(light: 0x0D8F6B, dark: 0x3DDCAB)
    static let onAccent = Color.dynamic(light: 0xFFFFFF, dark: 0x062019)

    // Kemerin durduğu "gece": her iki temada da koyu.
    static let night = Color(hex: 0x0B1513)
    static let night2 = Color(hex: 0x12211D)
    static let nightFg = Color(hex: 0xEAF5F1)
    static let nightMuted = Color(hex: 0x93AAA2)
    static let glow = Color(hex: 0x36E0AD)
    static let amber = Color(hex: 0xF0B443)
    static let ash = Color(hex: 0x7D8C87)
}

enum Typo {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static let body = Font.system(size: 13)
    static let small = Font.system(size: 12)
    static let mono = Font.system(size: 11.5, design: .monospaced)
}

// MARK: - Düğme stilleri

struct AccentButtonStyle: ButtonStyle {
    var big = false
    func makeBody(configuration: Configuration) -> some View {
        AccentButton(configuration: configuration, big: big)
    }

    private struct AccentButton: View {
        let configuration: ButtonStyleConfiguration
        let big: Bool
        @Environment(\.isEnabled) private var isEnabled
        var body: some View {
            configuration.label
                .font(.system(size: big ? 14 : 12.5, weight: .semibold))
                .foregroundStyle(Palette.onAccent)
                .padding(.horizontal, big ? 22 : 12)
                .frame(height: big ? 40 : 30)
                .background(RoundedRectangle(cornerRadius: big ? 11 : 8, style: .continuous).fill(Palette.accent))
                .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
                .contentShape(Rectangle())
        }
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        QuietButton(configuration: configuration)
    }

    private struct QuietButton: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled
        var body: some View {
            configuration.label
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Palette.fg)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? Palette.chip : Palette.card))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.line))
                .opacity(isEnabled ? 1 : 0.5)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Ortak parçalar

/// Başlıklı kart. Kenarlık ve dolgu yalnızca bu kartlarda kullanılır.
struct Card<Accessory: View, Content: View>: View {
    let title: String
    var subtitle: String?
    let accessory: () -> Accessory
    let content: () -> Content

    init(title: String, subtitle: String? = nil,
         @ViewBuilder accessory: @escaping () -> Accessory,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.fg)
                Spacer(minLength: 8)
                if let subtitle {
                    Text(subtitle).font(Typo.small).foregroundStyle(Palette.muted).lineLimit(1)
                }
                accessory()
            }
            content()
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line))
    }
}

extension Card where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, subtitle: subtitle, accessory: { EmptyView() }, content: content)
    }
}

enum PillKind { case ok, warn, idle, bad }

struct Pill: View {
    let text: String
    let kind: PillKind
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(fg)
            .background(Capsule().fill(bg))
    }
    private var fg: Color {
        switch kind { case .ok: return Palette.pass; case .warn: return Palette.warn; case .idle: return Palette.muted; case .bad: return Palette.stop }
    }
    private var bg: Color {
        switch kind { case .ok: return Palette.passSoft; case .warn: return Palette.warnSoft; case .idle: return Palette.chip; case .bad: return Palette.stopSoft }
    }
}

/// Satır satır sarılan yerleşim (alan adı çipleri için).
struct FlowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

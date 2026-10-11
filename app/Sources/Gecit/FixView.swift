import GecitCore
import SwiftUI

/// "Bir site açılmıyor mu?" penceresi: siteyi sorar, yöntemleri sırayla dener,
/// ilerlemeyi üç ışıklı bir merdivenle gösterir.
struct FixPanel: View {
    @EnvironmentObject private var model: AppModel
    @State private var site = ""
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Typo.display(compact ? 15 : 18))
                Text(subtitle)
                    .font(Typo.small).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if case .idle = model.fix {
                TextField("Hangi site? Örnek: discord.com (boş bırakabilirsin)", text: $site)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.window))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.line))
                    .onSubmit(start)
            }

            LadderView(current: model.status.profile, phase: model.fix, attempts: model.fixAttempts)
                .frame(height: compact ? 64 : 78)

            HStack(spacing: 8) {
                switch model.fix {
                case .idle:
                    Button("Düzelt", action: start)
                        .buttonStyle(AccentButtonStyle())
                        .disabled(model.busy != nil)
                case .adding, .trying:
                    ProgressView().controlSize(.small)
                    Text("Deneniyor, bir dakika sürebilir…").font(Typo.small).foregroundStyle(Palette.muted)
                case .works:
                    Button("Hâlâ açılmıyor, sonrakini dene") { model.fixNotWorking(site: lastSite) }
                        .buttonStyle(QuietButtonStyle())
                    Button("Tamam", action: model.resetFix)
                        .buttonStyle(AccentButtonStyle())
                case .notBlocked(let host):
                    Button("\(host) listeden çıkar") {
                        model.remove(host)
                        model.resetFix()
                    }
                    .buttonStyle(QuietButtonStyle())
                    Button("Tamam", action: model.resetFix)
                        .buttonStyle(AccentButtonStyle())
                case .exhausted:
                    Button("Tamam", action: model.resetFix)
                        .buttonStyle(AccentButtonStyle())
                }
            }
        }
        .padding(compact ? 0 : 18)
        .frame(width: compact ? nil : 380, alignment: .leading)
        .animation(.easeInOut(duration: 0.25), value: model.fix)
    }

    private var lastSite: String? {
        switch model.fix {
        case .works(_, let h), .trying(_, let h): return site.isEmpty ? nil : h
        default: return site.isEmpty ? nil : site
        }
    }

    private func start() { model.fixNotWorking(site: site) }

    private var title: String {
        switch model.fix {
        case .idle: return "Bir site açılmıyor mu?"
        case .adding(let h): return "\(h) listeye ekleniyor"
        case .trying(let p, _): return "\(p.title) yöntem deneniyor"
        case .works(_, let h): return "\(h) şimdi açılıyor"
        case .notBlocked(let h): return "\(h) bu ağda engelli değil"
        case .exhausted(let h): return "\(h) açılamadı"
        }
    }

    private var subtitle: String {
        switch model.fix {
        case .idle:
            return "Siteyi yaz ya da boş bırak. Listede yoksa eklerim, sonra yöntemleri sırayla deneyip açılanda dururum."
        case .adding:
            return "Bu siteyi Geçit'ten geçirmeye başlıyorum."
        case .trying(_, let h):
            return "Yöntemi değiştirip \(h) adresini gerçekten açmayı deniyorum."
        case .works(let p, _):
            return "\(p.title) yöntemle açıldı ve öyle kalacak. Tarayıcıda sekmeyi yenile; hâlâ açılmıyorsa sonrakine geçerim."
        case .notBlocked:
            return "Doğrudan bağlantıyla açılıyor, Geçit'e gerek yok. Listeden çıkarırsan her zamanki gibi açılır."
        case .exhausted:
            return "Dört yöntem de işe yaramadı ve site doğrudan da açılmıyor. Ya şu an kapalı ya da adresinden (IP) engellenmiş; bu durumda yalnızca VPN çözer."
        }
    }
}

/// Işıklı merdiven: Hafif → Orta → Güçlü → Çok güçlü.
struct LadderView: View {
    let current: Profile
    let phase: AppModel.FixPhase
    let attempts: [Profile: Bool]

    var body: some View {
        GeometryReader { geo in
            let profiles = Profile.allCases
            let step = geo.size.width / CGFloat(profiles.count)
            ZStack(alignment: .topLeading) {
                // Bağlantı çizgisi
                Path { p in
                    p.move(to: CGPoint(x: step / 2, y: 18))
                    p.addLine(to: CGPoint(x: geo.size.width - step / 2, y: 18))
                }
                .stroke(Palette.line, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 4]))

                ForEach(Array(profiles.enumerated()), id: \.element) { index, p in
                    VStack(spacing: 6) {
                        node(for: p)
                        Text(p.title)
                            .font(.system(size: 11.5, weight: isFocus(p) ? .semibold : .regular))
                            .foregroundStyle(isFocus(p) ? Palette.fg : Palette.muted)
                    }
                    .frame(width: step)
                    .offset(x: CGFloat(index) * step)
                }
            }
        }
    }

    private func isFocus(_ p: Profile) -> Bool {
        switch phase {
        case .trying(let t, _), .works(let t, _): return t == p
        case .idle: return p == current
        default: return false
        }
    }

    @ViewBuilder
    private func node(for p: Profile) -> some View {
        let trying: Bool = { if case .trying(let t, _) = phase { return t == p }; return false }()
        ZStack {
            if trying {
                PulseRing()
            }
            if attempts[p] == true {
                Circle().fill(Palette.pass)
                    .shadow(color: Palette.glow.opacity(0.8), radius: 8)
                Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
            } else if attempts[p] == false {
                Circle().fill(Palette.stopSoft)
                Image(systemName: "xmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(Palette.stop)
            } else if trying {
                Circle().fill(Palette.night)
                Circle().fill(Palette.glow).frame(width: 10, height: 10)
                    .shadow(color: Palette.glow, radius: 6)
            } else if case .idle = phase, p == current {
                Circle().fill(Palette.passSoft)
                Circle().strokeBorder(Palette.accent, lineWidth: 2)
                Circle().fill(Palette.accent).frame(width: 8, height: 8)
            } else {
                Circle().fill(Palette.card)
                Circle().strokeBorder(Palette.line, lineWidth: 2)
            }
        }
        .frame(width: 26, height: 26)
        .frame(height: 36)
        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: attempts[p])
    }
}

/// Denenen yöntemin çevresinde dışa yayılan halka. Kendi durumunu tutar ki her
/// göründüğünde animasyon baştan başlasın (paylaşılan bir bayrak ikinci kez tetiklenmez).
private struct PulseRing: View {
    @State private var on = false

    var body: some View {
        Circle()
            .stroke(Palette.glow.opacity(0.6), lineWidth: 2)
            .frame(width: 36, height: 36)
            .scaleEffect(on ? 1.25 : 0.9)
            .opacity(on ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) { on = true }
            }
    }
}

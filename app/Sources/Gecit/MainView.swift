import GecitCore
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.window.ignoresSafeArea()
            if model.loaded && !model.status.installed {
                WelcomeView()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        HeroView()
                        HStack(alignment: .top, spacing: 12) {
                            SitesCard()
                                .frame(maxWidth: .infinity)
                            VStack(spacing: 12) {
                                NetworksCard()
                                MethodCard()
                            }
                            .frame(width: 340)
                        }
                        TestCard()
                        SettingsCard()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 34) // saydam başlık çubuğunun altı
                    .padding(.bottom, 14)
                }
            }
            ToastView()
        }
        .foregroundStyle(Palette.fg)
        .font(Typo.body)
    }
}

// MARK: - Kemer + durum

struct HeroCopy {
    let eyebrow: String
    let title: String
    let lede: String
    let dot: Color

    @MainActor
    init(model: AppModel) {
        let s = model.status
        let groups = SiteGrouping.group(s.domains).map(\.name)
        let names: String
        switch groups.count {
        case 0: names = "Listedeki siteler"
        case 1: names = groups[0]
        case 2, 3: names = groups.dropLast().joined(separator: ", ") + " ve " + groups[groups.count - 1]
        default: names = groups.prefix(2).joined(separator: ", ") + " ve \(groups.count - 2) site grubu daha"
        }

        if model.busy == .toggling {
            eyebrow = "Bir saniye"
            title = s.enabled ? "Geçit açılıyor" : "Geçit kapanıyor"
            lede = s.enabled ? "Engelli siteler birazdan açılacak." : "Bütün siteler birazdan normal bağlantıyla açılacak."
            dot = Palette.ash
            return
        }
        switch s.health {
        case .active:
            eyebrow = "Etkin · açılışta kendiliğinden başlar"
            title = "Geçit açık"
            lede = "\(names) engelsiz açılıyor. Diğer bütün siteler hiç dokunulmadan, her zamanki bağlantınla açılır."
            dot = Palette.glow
        case .degraded:
            eyebrow = "Dikkat · bir parça yanıt vermiyor"
            title = "Geçit toparlanıyor"
            if !s.proxyRunning {
                lede = "Geçit motoru yeniden başlıyor. Birkaç saniye içinde düzelmezse aşağıdan testi başlat."
            } else if !s.pacRunning {
                lede = "Site yönlendirmesi yanıt vermiyor. Birkaç saniye içinde düzelmezse aşağıdan testi başlat."
            } else {
                lede = "\(model.primaryNetwork ?? "Bu ağ") için ayarlar yapılıyor. Bu genelde birkaç saniye sürer."
            }
            dot = Palette.amber
        case .off:
            eyebrow = "Kapalı · elle kapatıldı"
            title = "Geçit kapalı"
            lede = "Bütün siteler normal bağlantıyla açılıyor. Engelli siteler şu an açılmaz."
            dot = Palette.ash
        case .notInstalled:
            eyebrow = "Kurulum gerekli"
            title = "Geçit kurulu değil"
            lede = "Kurulumu bir kez yapman yeterli."
            dot = Palette.ash
        }
    }
}

struct HeroView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showFix = false

    var body: some View {
        let copy = HeroCopy(model: model)
        let health = model.status.health
        HStack(alignment: .center, spacing: 28) {
            Button(action: model.toggle) {
                ArchView(mode: archMode)
                    .frame(width: 190, height: 190)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(model.busy != nil || health == .notInstalled)
            .help(health == .off ? "Açmak için tıkla" : "Kapatmak için tıkla")

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle().fill(copy.dot).frame(width: 8, height: 8)
                        .background(Circle().fill(copy.dot.opacity(0.25)).frame(width: 16, height: 16))
                    Text(copy.eyebrow.uppercased(with: Locale(identifier: "tr_TR")))
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(Palette.nightMuted)
                }
                Text(copy.title)
                    .font(Typo.display(34))
                    .foregroundStyle(Palette.nightFg)
                Text(copy.lede)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.nightMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 500, alignment: .leading)
                HStack(spacing: 8) {
                    Fact(symbol: "wifi", bold: model.primaryNetwork ?? "Ağ yok", rest: "etkin ağ")
                    Fact(symbol: "wand.and.stars", lead: "Yöntem:", bold: "Otomatik · \(model.status.profile.title)")
                    Fact(symbol: "bolt.fill", rest: "VPN yok, hız kaybı yok")
                }
                .padding(.top, 10)
                Button {
                    showFix = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lifepreserver")
                        Text("Bir site açılmıyor mu?")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.glow)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Palette.glow.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(Palette.glow.opacity(0.35)))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(health == .notInstalled)
                .popover(isPresented: $showFix, arrowEdge: .bottom) {
                    FixPanel()
                        .environmentObject(model)
                        .onDisappear { model.resetFix() }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 22, leading: 18, bottom: 22, trailing: 28))
        .background(
            RadialGradient(colors: [Palette.night2, Palette.night],
                           center: UnitPoint(x: 0.18, y: 1), startRadius: 0, endRadius: 700)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.06)))
        .animation(.easeInOut(duration: 0.25), value: copy.title)
    }

    private var archMode: ArchView.Mode {
        switch model.status.health {
        case .active: return .open
        case .degraded: return .warning
        case .off, .notInstalled: return .closed
        }
    }
}

private struct Fact: View {
    let symbol: String
    var lead: String?
    var bold: String?
    var rest: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 11)).opacity(0.8)
            if let lead { Text(lead) }
            if let bold { Text(bold).fontWeight(.semibold) }
            if let rest { Text(rest) }
        }
        .font(.system(size: 12))
        .foregroundStyle(Palette.nightFg)
        .lineLimit(1)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.07)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
    }
}

// MARK: - Siteler ve uygulamalar

struct SitesCard: View {
    @EnvironmentObject private var model: AppModel
    @State private var input = ""
    @State private var error: String?
    @State private var adding = false

    var body: some View {
        Card(title: "Engelli siteler ve uygulamalar", subtitle: "\(model.status.domains.count) alan adı") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    TextField("site.com ya da tam adresi yapıştır", text: $input)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.window))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.line))
                        .onSubmit(add)
                    Button("Ekle", action: add)
                        .buttonStyle(AccentButtonStyle())
                        .disabled(adding || input.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let error {
                    Text(error).font(Typo.small).foregroundStyle(Palette.stop)
                        .transition(.opacity)
                }
                let groups = SiteGrouping.group(model.status.domains)
                if groups.isEmpty {
                    Text("Liste boş. Açılmayan bir siteyi yukarıya yazıp ekle.")
                        .font(Typo.small).foregroundStyle(Palette.muted)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 2) {
                        ForEach(groups) { g in
                            GroupRow(group: g, apps: model.coveredApps[g.name] ?? [])
                        }
                    }
                }
                Text("Discord gibi masaüstü uygulamaları da macOS'un bağlantı ayarını kullandığı için aynı listeyle açılır.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .animation(.easeOut(duration: 0.2), value: error)
        }
    }

    private func add() {
        let text = input
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty, !adding else { return }
        adding = true
        Task {
            error = await model.add(text)
            if error == nil { input = "" }
            adding = false
        }
    }
}

private struct GroupRow: View {
    @EnvironmentObject private var model: AppModel
    let group: SiteGroup
    let apps: [CoveredApp]
    @State private var hover = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(group.name.prefix(1)))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Self.brand(group.name)))
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(group.name).fontWeight(.semibold)
                    Text("\(group.domains.count) alan adı").font(Typo.small).foregroundStyle(Palette.muted)
                    Spacer(minLength: 0)
                    ForEach(apps) { app in
                        HStack(spacing: 4) {
                            Image(nsImage: app.icon).resizable().frame(width: 14, height: 14)
                            Text("\(app.name) uygulaması da").font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Palette.pass)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Palette.passSoft))
                        .help("Bu Mac'te kurulu \(app.name) uygulaması da bu listeyle engelsiz bağlanır.")
                    }
                }
                FlowLayout(spacing: 5) {
                    ForEach(group.domains, id: \.self) { d in
                        DomainChip(domain: d, fresh: d == model.lastAdded)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(hover ? Palette.chip : Color.clear))
        .onHover { hover = $0 }
    }

    static func brand(_ name: String) -> Color {
        switch name {
        case "Discord": return Color(hex: 0x5865F2)
        case "Roblox": return Color(hex: 0x3B3F45)
        case "Wattpad": return Color(hex: 0xF25D22)
        default:
            let h = name.unicodeScalars.reduce(7) { ($0 * 31 + Int($1.value)) % 360 }
            return Color(hue: Double(h) / 360, saturation: 0.45, brightness: 0.6)
        }
    }
}

private struct DomainChip: View {
    @EnvironmentObject private var model: AppModel
    let domain: String
    let fresh: Bool
    @State private var hover = false
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 4) {
            Text(domain).font(Typo.mono)
            Button {
                model.remove(domain)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 16, height: 16)
                    .foregroundStyle(hover ? Palette.stop : Palette.muted)
                    .background(RoundedRectangle(cornerRadius: 4).fill(hover ? Palette.stopSoft : Color.clear))
                    .opacity(hover ? 1 : 0.55)
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }
            .help("\(domain) adresini listeden çıkar")
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(fresh && !appeared ? Palette.passSoft : Palette.chip))
        .scaleEffect(fresh && !appeared ? 0.85 : 1)
        .onAppear {
            guard fresh else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.05)) { appeared = true }
        }
    }
}

// MARK: - Ağlar

struct NetworksCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Card(title: "Ağlar", subtitle: "Ağ değişince kendiliğinden ayarlanır") {
            VStack(spacing: 2) {
                if model.status.services.isEmpty {
                    Text("Ağ servisi bulunamadı.").font(Typo.small).foregroundStyle(Palette.muted)
                }
                ForEach(model.status.services) { svc in
                    HStack(spacing: 10) {
                        Image(systemName: Self.symbol(svc.name))
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.muted)
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.chip))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(svc.name).fontWeight(.medium)
                            Text(svc.name == model.primaryNetwork ? "Bağlı · etkin ağ" : "Hazır bekliyor")
                                .font(Typo.small).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        if !model.status.enabled {
                            Pill(text: "Kapalı", kind: .idle)
                        } else if svc.pacActive {
                            Pill(text: "Hazır", kind: .ok)
                        } else {
                            Pill(text: "Ayarlanıyor", kind: .warn)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    static func symbol(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("wi-fi") || n.contains("wifi") || n.contains("airport") { return "wifi" }
        if n.contains("iphone") || n.contains("ipad") { return "iphone" }
        if n.contains("bluetooth") { return "dot.radiowaves.left.and.right" }
        if n.contains("thunderbolt") || n.contains("ethernet") || n.contains("lan") || n.contains("usb") { return "cable.connector" }
        return "network"
    }
}

// MARK: - Yöntem (otomatik; elle seçim "Gelişmiş"te)

struct MethodCard: View {
    @EnvironmentObject private var model: AppModel
    @State private var showAdvanced = false

    var body: some View {
        Card(title: "Yöntem", subtitle: "Otomatik") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(Palette.accent)
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.passSoft))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Şu an: \(model.status.profile.title)").fontWeight(.medium)
                        Text("Ağ değişince engelli siteleri dener, açılmazsa uygun yöntemi kendisi bulur.")
                            .font(Typo.small).foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let note = model.tuneNote {
                    HStack(spacing: 6) {
                        if model.busy == .tuning { ProgressView().controlSize(.small) }
                        Text(note).font(Typo.small).foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack {
                    Button("Şimdi yeniden bul", action: model.autoTune)
                        .buttonStyle(QuietButtonStyle())
                        .disabled(model.busy != nil || !model.status.enabled)
                    Spacer()
                    Button(showAdvanced ? "Gelişmişi gizle" : "Gelişmiş") {
                        withAnimation(.easeOut(duration: 0.2)) { showAdvanced.toggle() }
                    }
                    .buttonStyle(.plain)
                    .font(Typo.small)
                    .foregroundStyle(Palette.muted)
                }
                if showAdvanced {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Yalnızca otomatik seçim işe yaramazsa elle değiştir. Hepsi sadece listedeki sitelere uygulanır.")
                            .font(.system(size: 11.5)).foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            ForEach(Profile.allCases) { p in
                                ProfileButton(profile: p, selected: p == model.status.profile)
                            }
                        }
                        Text(model.status.profile.detail)
                            .font(.system(size: 11.5)).foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

private struct ProfileButton: View {
    @EnvironmentObject private var model: AppModel
    let profile: Profile
    let selected: Bool

    var body: some View {
        Button {
            model.setProfile(profile)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(i < level ? (selected ? Palette.accent : Palette.muted) : Palette.line)
                            .frame(width: 4, height: CGFloat(6 + i * 4))
                    }
                }
                .frame(height: 14, alignment: .bottom)
                Text(profile.title).font(.system(size: 12.5, weight: .semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(selected ? Palette.passSoft : Palette.window))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(selected ? Palette.accent : Palette.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.busy != nil)
    }

    private var level: Int {
        switch profile { case .hafif: return 1; case .orta: return 2; case .guclu: return 3 }
    }
}

// MARK: - Canlı test

struct TestCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let run = model.tests
        Card(title: "Canlı test", accessory: {
            Button(run.running ? "Deneniyor…" : (run.finished ? "Yeniden test et" : "Testi başlat"), action: model.runTests)
                .buttonStyle(AccentButtonStyle())
                .disabled(run.running || !model.status.installed)
        }) {
            VStack(alignment: .leading, spacing: 12) {
                if run.blocked.isEmpty && run.normal.isEmpty {
                    Text("Engelli siteleri Geçit üzerinden, normal siteleri hiç dokunmadan, doğrudan dener. Hangisinin açıldığını ve ne kadar sürdüğünü gösterir.")
                        .font(Typo.small).foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(alignment: .top, spacing: 28) {
                        TestColumn(title: "Engelli siteler · Geçit üzerinden", rows: run.blocked)
                        TestColumn(title: "Normal siteler · doğrudan, dokunulmadan", rows: run.normal)
                    }
                }
                if run.finished { Verdict(run: run, enabled: model.status.enabled) }
            }
        }
    }
}

private struct TestColumn: View {
    let title: String
    let rows: [TestRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased(with: Locale(identifier: "tr_TR")))
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.9)
                .foregroundStyle(Palette.muted)
            ForEach(rows) { row in
                HStack(spacing: 10) {
                    StatusDot(state: row.state)
                    Text(row.host).font(.system(size: 12, design: .monospaced)).lineLimit(1)
                    Spacer(minLength: 8)
                    LatencyBar(state: row.state).frame(width: 90)
                    Text(Self.label(row.state))
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(Palette.muted)
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.vertical, 3)
                .help(Self.help(row))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func label(_ s: TestRow.State) -> String {
        switch s {
        case .waiting: return "–"
        case .done(.ok(let ms, _)): return "\(ms) ms"
        case .done(.failed): return "açılmadı"
        }
    }

    static func help(_ row: TestRow) -> String {
        if case .done(.failed(let why)) = row.state { return "\(row.host): \(why)" }
        return row.host
    }
}

private struct StatusDot: View {
    let state: TestRow.State
    @State private var spin = false

    var body: some View {
        ZStack {
            switch state {
            case .waiting:
                Circle().trim(from: 0, to: 0.75)
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: spin)
                    .onAppear { spin = true }
                    .onDisappear { spin = false } // "Yeniden test et"te tekrar dönebilsin
            case .done(.ok):
                Circle().fill(Palette.pass)
                Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)).foregroundStyle(.white)
            case .done(.failed):
                Circle().fill(Palette.stop)
                Image(systemName: "xmark").font(.system(size: 7, weight: .heavy)).foregroundStyle(.white)
            }
        }
        .frame(width: 16, height: 16)
        .transition(.scale.combined(with: .opacity))
    }
}

private struct LatencyBar: View {
    let state: TestRow.State

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.chip)
                Capsule().fill(Palette.pass).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 4)
        .animation(.easeOut(duration: 0.5), value: fraction)
    }

    private var fraction: CGFloat {
        if case .done(.ok(let ms, _)) = state { return min(1, max(0.04, CGFloat(ms) / 400)) }
        return 0
    }
}

private struct Verdict: View {
    let run: TestRun
    let enabled: Bool

    var body: some View {
        let (text, good) = message
        HStack(spacing: 10) {
            Image(systemName: good ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(good ? Palette.pass : Palette.stop)
            Text(text).font(.system(size: 12.5)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(good ? Palette.passSoft : Palette.stopSoft))
    }

    private var message: (String, Bool) {
        if run.normalFailures > 0 && run.normalFailures == run.normal.count {
            return ("Normal siteler de açılmadı. İnternet bağlantını kontrol et; sorun Geçit'te değil.", false)
        }
        if run.normalFailures > 0 {
            return ("Bazı normal siteler açılmadı. Geçit bunlara hiç dokunmuyor; o siteler ya da bağlantın yavaş olabilir.", false)
        }
        if run.blockedFailures > 0 {
            if !enabled { return ("Geçit kapalıyken engelli siteler açılmaz. Açmak için kemere tıkla.", false) }
            return ("Bazı engelli siteler açılmadı. \"Şimdi yeniden bul\" bu ağa uygun yöntemi arar.", false)
        }
        var text = "Her şey yolunda: engelli siteler Geçit üzerinden, normal siteler doğrudan açılıyor."
        if let via = TestRun.averageMs(run.blocked), let direct = TestRun.averageMs(run.normal) {
            text += " Ortalama açılış Geçit üzerinden \(via) ms, doğrudan \(direct) ms."
            text += " Bu süre ping değil: siteye sıfırdan bağlanıp (DNS, bağlantı, şifreleme) ilk yanıtı alma süresi."
            if via <= direct + direct / 5 { text += " İkisi aynı seviyede, yani Geçit bağlantını yavaşlatmıyor." }
        }
        return (text, true)
    }
}

// MARK: - Ayarlar ve kayıtlar

struct SettingsCard: View {
    @EnvironmentObject private var model: AppModel
    @State private var showLogs = false
    @State private var confirmUninstall = false

    var body: some View {
        Card(title: "Ayarlar") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 18) {
                    Toggle("Mac açılınca menü çubuğunda başlasın", isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(Palette.pass)
                    Spacer()
                    Button(showLogs ? "Kayıtları gizle" : "Kayıtları göster") {
                        withAnimation(.easeOut(duration: 0.2)) { showLogs.toggle() }
                    }
                    .buttonStyle(QuietButtonStyle())
                    Button("Kaldır…") { confirmUninstall = true }
                        .buttonStyle(QuietButtonStyle())
                        .disabled(model.busy != nil)
                }
                Text("Geçit motoru, uygulama kapalıyken de çalışmaya devam eder. Bu ayar yalnızca menü çubuğu simgesi içindir.")
                    .font(.system(size: 11.5)).foregroundStyle(Palette.muted)
                if showLogs {
                    ScrollView(.horizontal) {
                        Text(model.logLines.isEmpty ? "Henüz kayıt yok." : model.logLines.joined(separator: "\n"))
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(Color(hex: 0xB9D3CA))
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Palette.night))
                    .transition(.opacity)
                }
            }
        }
        .confirmationDialog("Geçit kaldırılsın mı?", isPresented: $confirmUninstall) {
            Button("Kaldır", role: .destructive, action: model.uninstall)
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Arka plandaki servisler silinir ve ağ ayarların eski haline döner. Engelli siteler yeniden açılmaz.")
        }
    }
}

// MARK: - Bildirim

struct ToastView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if let text = model.toast {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill").foregroundStyle(Palette.accent)
                    Text(text).font(.system(size: 12.5)).fixedSize(horizontal: false, vertical: true)
                    Button {
                        model.toast = nil
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: 520)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line))
                .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
                .padding(.bottom, 18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: text) {
                    try? await Task.sleep(nanoseconds: 7_000_000_000)
                    if model.toast == text { model.toast = nil }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.toast)
    }
}

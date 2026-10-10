import AppKit
import CryptoKit
import GecitCore
import ServiceManagement
import SwiftUI
import SystemConfiguration

extension EngineStatus {
    /// Geçit trafiği geçiriyor mu (sorunlu da olsa açık sayılır).
    var isPassing: Bool { health == .active || health == .degraded }
}

struct TestRow: Identifiable, Equatable {
    enum State: Equatable { case waiting, done(Outcome) }
    var id: String { host }
    let host: String
    var state: State = .waiting
}

struct TestRun: Equatable {
    var blocked: [TestRow] = []
    var normal: [TestRow] = []
    var running = false
    var finished = false

    var blockedFailures: Int { blocked.filter { if case .done(.failed) = $0.state { return true } else { return false } }.count }
    var normalFailures: Int { normal.filter { if case .done(.failed) = $0.state { return true } else { return false } }.count }
}

/// Bilgisayarda kurulu, listedeki sitelerle aynı aileden bir uygulama (ör. Discord).
struct CoveredApp: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let icon: NSImage
}

/// Uygulamanın tüm durumu. Çekirdeği yalnızca `macdpi` komutlarıyla değiştirir.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    enum Busy: Equatable { case toggling, tuning, fixing, installing, uninstalling }

    /// "Bir site açılmıyor mu?" akışının durumu.
    enum FixPhase: Equatable {
        case idle
        case adding(String)
        case trying(Profile, String)
        case works(Profile, String)
        case notBlocked(String)
        case exhausted(String)
    }

    @Published private(set) var status: EngineStatus = .placeholder
    @Published private(set) var loaded = false
    @Published private(set) var primaryNetwork: String?
    @Published private(set) var busy: Busy?
    @Published private(set) var tuneNote: String?
    @Published private(set) var tests = TestRun()
    @Published private(set) var coveredApps: [String: [CoveredApp]] = [:]
    @Published private(set) var launchAtLogin = false
    @Published private(set) var logLines: [String] = []
    @Published private(set) var fix: FixPhase = .idle
    /// Bu düzeltme turunda denenen yöntemler: true = site açıldı.
    @Published private(set) var fixAttempts: [Profile: Bool] = [:]
    @Published var toast: String?
    @Published var lastAdded: String?

    let paths = MacdpiPaths.standard
    private let probe = StatusProbe()
    private let cli = MacdpiCLI()
    private let runner = ProcessRunner()
    private var timer: Timer?
    private var lastNetwork: String?
    private var healing = false
    private var ticking = false

    var windowVisible = false {
        didSet { schedule(); if windowVisible { refreshApps(); Task { await refresh() } } }
    }

    // MARK: - Yaşam döngüsü

    func start() {
        refreshLaunchAtLogin()
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "girisOgesiAyarlandi") {
            defaults.set(true, forKey: "girisOgesiAyarlandi")
            setLaunchAtLogin(true)
        }
        refreshApps()
        schedule()
        Task { await refresh() }

        // Uykudan uyanınca ve 15 dakikada bir sessizce kontrol et.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in await AppModel.shared.heal(reason: "Mac uykudan uyandı") }
        }
        Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { _ in
            Task { @MainActor in await AppModel.shared.heal(reason: "Düzenli kontrol") }
        }
    }

    private func schedule() {
        timer?.invalidate()
        let interval: TimeInterval = windowVisible ? 3 : 8
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in await AppModel.shared.tick() }
        }
    }

    /// Zamanlayıcıdan gelen yenileme: bir önceki bitmeden yenisini başlatma
    /// (yavaş bir `networksetup` turunda süreçler üst üste binmesin).
    private func tick() async {
        guard !ticking else { return }
        ticking = true
        defer { ticking = false }
        await refresh()
    }

    func refresh() async {
        let s = await probe.probe()
        let network = PrimaryNetwork.serviceName()
        if s != status { status = s }
        primaryNetwork = network
        loaded = true
        if windowVisible { logLines = Self.readLogs(paths) }

        // Ağ değişti: engelli siteler hâlâ açılıyor mu, bakıp gerekirse yöntemi kendisi bulsun.
        if let network, network != lastNetwork {
            let first = lastNetwork == nil
            lastNetwork = network
            // Beklemeden: heal saniyeler sürer, refresh'i bekleyenleri tutmasın.
            if !first { Task { await heal(reason: "\(network) ağına geçildi") } }
        }
    }

    // MARK: - Aç / kapat

    func setEnabled(_ on: Bool) {
        guard busy == nil, status.installed else { return }
        busy = .toggling
        status.enabled = on
        Task {
            let r = await cli.setEnabled(on)
            if r.exitCode != 0 { toast = Self.firstLine(r.output, fallback: "Durum değiştirilemedi.") }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await refresh()
            busy = nil
        }
    }

    func toggle() { setEnabled(!status.enabled) }

    // MARK: - Site listesi

    /// Hata varsa kullanıcıya gösterilecek metni döndürür.
    func add(_ raw: String) async -> String? {
        guard let domain = Domain.normalize(raw) else {
            return "Bu bir site adı gibi görünmüyor. Örnek: twitch.tv"
        }
        if status.domains.contains(domain) { return "\(domain) zaten listede." }
        let r = await cli.add([domain])
        guard r.exitCode == 0 else { return Self.firstLine(r.output, fallback: "Eklenemedi.") }
        lastAdded = domain
        await refresh()
        return nil
    }

    func remove(_ domain: String) {
        Task {
            let r = await cli.remove([domain])
            if r.exitCode != 0 { toast = Self.firstLine(r.output, fallback: "Çıkarılamadı.") }
            await refresh()
        }
    }

    // MARK: - Yöntem (otomatik)

    /// Bu ağda çalışan en hafif yöntemi bulur (`macdpi otoayar`).
    func autoTune() {
        guard busy == nil, status.installed else { return }
        busy = .tuning
        tuneNote = "Bu ağ için en uygun yöntem aranıyor…"
        Task {
            var chosen: Profile?
            for await line in cli.autoTune() {
                if let p = MacdpiCLI.chosenProfile(fromAutoTuneLine: line) { chosen = p }
                if line.hasPrefix("Deneniyor:"), let p = Profile(rawValue: line.dropFirst(10).trimmingCharacters(in: .whitespaces)) {
                    tuneNote = "\(p.title) yöntem deneniyor…"
                }
            }
            if let chosen {
                tuneNote = "Bu ağda \(chosen.title) yöntem çalışıyor, o seçildi."
            } else {
                tuneNote = "Hiçbir yöntem işe yaramadı. Bu ağ siteyi adres düzeyinde engelliyor olabilir."
            }
            await refresh()
            busy = nil
        }
    }

    /// Gelişmiş: yöntemi elle seç.
    func setProfile(_ p: Profile) {
        guard busy == nil, status.installed, p != status.profile else { return }
        busy = .tuning
        tuneNote = "\(p.title) yönteme geçiliyor…"
        status.profile = p
        Task {
            var failed = false
            for await line in cli.setProfile(p) where line.contains("AÇILMIYOR") { failed = true }
            tuneNote = failed ? "\(p.title) yöntemle bazı siteler açılmadı." : "\(p.title) yöntem etkin."
            await refresh()
            busy = nil
        }
    }

    /// Engelli sitelerden birkaçını dener; açılmıyorsa yöntemi kendisi yeniden bulur.
    func heal(reason: String) async {
        guard !healing, busy == nil, status.installed, status.enabled else { return }
        healing = true
        defer { healing = false }
        try? await Task.sleep(nanoseconds: 4_000_000_000) // ajan yeni ağı ayarlasın
        // Beklerken kullanıcı kapatmış ya da başka bir işlem başlatmış olabilir.
        guard busy == nil, status.enabled else { return }
        let sample = Array(Self.blockedSample(status.domains).prefix(2))
        guard !sample.isEmpty else { return }
        let tester = SiteTester(timeout: 6)
        var allOK = true
        for host in sample {
            if case .failed = await tester.test(host: host, route: .viaMacdpi) { allOK = false }
        }
        if !allOK, busy == nil, status.enabled {
            tuneNote = "\(reason). Engelli siteler açılmadı, yöntem yeniden aranıyor…"
            autoTune()
        }
    }

    // MARK: - "Bir site açılmıyor mu?"

    /// Siteyi (verilmezse listeden birkaç siteyi) bir sonraki yöntemlerle dener; açılana kadar
    /// sırayla ilerler. Her yöntemde siteyi gerçekten açmayı dener.
    func fixNotWorking(site raw: String?) {
        guard busy == nil, status.installed else { return }
        busy = .fixing
        Task {
            defer { busy = nil }
            if !status.enabled {
                _ = await cli.setEnabled(true)
                await refresh()
            }

            var targets: [String]
            let typed = raw.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
            if let typed {
                guard let domain = Domain.normalize(typed) else {
                    toast = "Bu bir site adı gibi görünmüyor. Örnek: twitch.tv"
                    return
                }
                if !Self.isCovered(domain, by: status.domains) {
                    fix = .adding(domain)
                    let r = await cli.add([domain])
                    guard r.exitCode == 0 else {
                        toast = Self.firstLine(r.output, fallback: "Site eklenemedi.")
                        fix = .idle
                        return
                    }
                    lastAdded = domain
                    await refresh()
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // ajan listeyi yaysın
                }
                targets = [domain]
            } else {
                targets = Array(Self.blockedSample(status.domains).prefix(3))
            }
            guard let label = targets.first else { fix = .idle; return }

            // Şu ankinden bir sonrakiyle başla, en son şu ankini yeniden dene.
            let all = Profile.allCases
            let start = all.firstIndex(of: status.profile) ?? 1
            let order = (1...all.count).map { all[(start + $0) % all.count] }
            fixAttempts = [:]
            for p in order {
                fix = .trying(p, label)
                await apply(p)
                let ok = await Self.opens(targets)
                fixAttempts[p] = ok
                if ok {
                    fix = .works(p, label)
                    await refresh()
                    return
                }
            }

            // Hiçbiri olmadı: site bu ağda gerçekten engelli mi?
            let direct = await SiteTester(timeout: 8).test(host: label, route: .direct)
            if case .ok = direct {
                fix = .notBlocked(label)
            } else {
                fix = .exhausted(label)
            }
            await apply(.orta)
            await refresh()
        }
    }

    func resetFix() {
        guard busy != .fixing else { return }
        fix = .idle
        fixAttempts = [:]
    }

    /// Yöntemi değiştirir ve geçit motorunun yeniden başlamasını bekler.
    private func apply(_ p: Profile) async {
        // `macdpi profil` ayarı hemen yazar, sonra kendi testini yapar; o testi beklemeyiz.
        for await line in cli.setProfile(p) where line.hasPrefix("Profil:") { break }
        status.profile = p
        await Self.waitForRestart(paths)
    }

    /// `macdpi`deki restart_wait'in aynısı: önce ajanın yeni ayarı uyguladığını (config.sum)
    /// görür, sonra portun açılmasını bekler. Yalnızca port beklemek yetmez: eski motor hâlâ
    /// açıkken yeni yöntem denenmiş sanılırdı. `nonisolated async` olduğu için ana iş
    /// parçacığında çalışmaz (PortProbe bloklayan bir connect yapar).
    nonisolated private static func waitForRestart(_ paths: MacdpiPaths) async {
        let sumFile = paths.home.appendingPathComponent("var/config.sum")
        if let config = try? Data(contentsOf: paths.configFile) {
            let want = Insecure.SHA1.hash(data: config).map { String(format: "%02x", $0) }.joined()
            for _ in 0..<20 {
                let have = (try? String(contentsOf: sumFile, encoding: .utf8))?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if have == want { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        } else {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
        }
        for _ in 0..<12 {
            if PortProbe.isOpen(port: MacdpiPaths.proxyPort) { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private static func opens(_ hosts: [String]) async -> Bool {
        let tester = SiteTester(timeout: 8)
        for h in hosts {
            if case .failed = await tester.test(host: h, route: .viaMacdpi) { return false }
        }
        return true
    }

    /// "discord.com" listede ise "cdn.discord.com" da kapsanır.
    static func isCovered(_ domain: String, by list: [String]) -> Bool {
        list.contains { domain == $0 || domain.hasSuffix("." + $0) }
    }

    // MARK: - Canlı test

    func runTests() {
        guard !tests.running else { return }
        let blocked = Self.blockedSample(status.domains)
        let normal = Array(SiteTester.normalSites.prefix(6))
        tests = TestRun(blocked: blocked.map { TestRow(host: $0) },
                        normal: normal.map { TestRow(host: $0) },
                        running: true)
        let tester = SiteTester()
        let jobs = blocked.map { (Route.viaMacdpi, $0) } + normal.map { (Route.direct, $0) }
        for (route, host) in jobs {
            Task {
                let outcome = await tester.test(host: host, route: route)
                if route == .viaMacdpi, let i = tests.blocked.firstIndex(where: { $0.host == host }) {
                    tests.blocked[i].state = .done(outcome)
                } else if route == .direct, let i = tests.normal.firstIndex(where: { $0.host == host }) {
                    tests.normal[i].state = .done(outcome)
                }
                let pending = (tests.blocked + tests.normal).contains { $0.state == .waiting }
                if !pending, tests.running {
                    tests.running = false
                    tests.finished = true
                }
            }
        }
    }

    /// Her site ailesinden bir temsilci (discord.com gibi .com olanı tercih eder), en fazla 6.
    static func blockedSample(_ domains: [String]) -> [String] {
        var picks: [String] = []
        for g in SiteGrouping.group(domains) {
            let candidates = g.domains.filter { $0 != "dis.gd" }
            let preferred = candidates.first { $0 == g.name.lowercased() + ".com" } ?? candidates.first
            if let preferred { picks.append(preferred) }
        }
        for d in SiteTester.blockedSample(from: domains, limit: 12) where picks.count < 6 && !picks.contains(d) {
            picks.append(d)
        }
        return Array(picks.prefix(6))
    }

    // MARK: - Kurulum

    var bundledCore: URL? { Bundle.main.resourceURL?.appendingPathComponent("core") }

    func install() {
        guard busy == nil, let core = bundledCore else { return }
        busy = .installing
        var cmd = "/bin/sh \(Admin.quote(core.appendingPathComponent("kur.sh").path)) --sessiz --kullanici \(Admin.quote(NSUserName()))"
        let bin = core.appendingPathComponent("bin/spoofdpi")
        if FileManager.default.isExecutableFile(atPath: bin.path) { cmd += " --bin \(Admin.quote(bin.path))" }
        Task {
            let r = await Admin.run(cmd, prompt: "Geçit kurulumu için bir kez Mac şifren gerekiyor.", runner: runner)
            if r.exitCode != 0, !Admin.wasCancelled(r) {
                toast = "Kurulum tamamlanamadı: " + Self.firstLine(r.output, fallback: "bilinmeyen hata")
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await refresh()
            busy = nil
            if status.installed { autoTune() }
        }
    }

    func uninstall() {
        guard busy == nil else { return }
        busy = .uninstalling
        let installed = paths.home.appendingPathComponent("lib/kaldir.sh")
        let script = FileManager.default.fileExists(atPath: installed.path)
            ? installed : bundledCore?.appendingPathComponent("kaldir.sh")
        guard let script else { busy = nil; return }
        Task {
            let r = await Admin.run("/bin/sh \(Admin.quote(script.path))",
                                    prompt: "Geçit'i kaldırmak ve ağ ayarlarını eski haline getirmek için Mac şifren gerekiyor.",
                                    runner: runner)
            if r.exitCode != 0, !Admin.wasCancelled(r) {
                toast = "Kaldırılamadı: " + Self.firstLine(r.output, fallback: "bilinmeyen hata")
            } else if r.exitCode == 0 {
                setLaunchAtLogin(false)
                toast = "Geçit kaldırıldı, ağ ayarların eski haline döndü. Uygulamayı Çöp Sepeti'ne sürükleyebilirsin."
            }
            await refresh()
            busy = nil
        }
    }

    // MARK: - Girişte aç

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            if on { toast = "Girişte açılma ayarlanamadı. Sistem Ayarları > Genel > Giriş Öğeleri'nden Geçit'i ekleyebilirsin." }
        }
        refreshLaunchAtLogin()
    }

    private func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Uygulamalar (Discord masaüstü vb.)

    private static let knownApps: [String: [String]] = [
        "Discord": ["Discord.app", "Discord PTB.app", "Discord Canary.app"],
        "Roblox": ["Roblox.app", "RobloxPlayer.app", "RobloxStudio.app"],
        "Wattpad": ["Wattpad.app"],
    ]

    func refreshApps() {
        let fm = FileManager.default
        let roots = ["/Applications", NSHomeDirectory() + "/Applications"]
        var found: [String: [CoveredApp]] = [:]
        for (family, bundles) in Self.knownApps {
            for root in roots {
                for b in bundles {
                    let path = root + "/" + b
                    guard fm.fileExists(atPath: path) else { continue }
                    let icon = NSWorkspace.shared.icon(forFile: path)
                    icon.size = NSSize(width: 32, height: 32)
                    found[family, default: []].append(CoveredApp(name: String(b.dropLast(4)), path: path, icon: icon))
                }
            }
        }
        coveredApps = found
    }

    // MARK: - Yardımcılar

    private static func readLogs(_ paths: MacdpiPaths) -> [String] {
        LogReader.tail(paths.agentLog, lines: 12) + LogReader.tail(paths.spoofLog, lines: 8)
    }

    static func firstLine(_ s: String, fallback: String) -> String {
        s.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? fallback
    }
}

/// Yönetici izni gereken tek iki iş (kurulum ve kaldırma) için macOS'un kendi şifre penceresi.
enum Admin {
    static func quote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private static func appleScriptString(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    static func run(_ command: String, prompt: String, runner: CommandRunning) async -> CommandResult {
        let script = "do shell script \(appleScriptString(command)) with prompt \(appleScriptString(prompt)) with administrator privileges"
        return await runner.run("/usr/bin/osascript", ["-e", script])
    }

    static func wasCancelled(_ r: CommandResult) -> Bool { r.output.contains("-128") }
}

/// Şu an internete çıkılan ağ servisinin adı ("Wi-Fi", "iPhone USB"...).
enum PrimaryNetwork {
    static func serviceName() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "Gecit" as CFString, nil, nil),
              let global = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let serviceID = global["PrimaryService"] as? String,
              let prefs = SCPreferencesCreate(nil, "Gecit" as CFString, nil),
              let services = SCNetworkServiceCopyAll(prefs) as? [SCNetworkService]
        else { return nil }
        for service in services {
            guard let id = SCNetworkServiceGetServiceID(service), (id as String) == serviceID else { continue }
            return SCNetworkServiceGetName(service).map { $0 as String }
        }
        return nil
    }
}

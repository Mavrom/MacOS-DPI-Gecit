import AppKit
import GecitCore

/// Discord masaüstü uygulamasının güncelleyicisi sistemin proxy ayarını (PAC) dinlemez:
/// doğrudan bağlanır, engele takılır ve uygulama "Güncelleme başarısız"/"Başlatılıyor"da
/// kalır (tarayıcıda Discord açılırken uygulamanın açılmamasının sebebi). Geçit, Discord
/// kendiliğinden (Dock, girişte açılma, kendi güncellemesi sonrası) açıldığında onu kapatıp
/// `macdpi discord` ile yerel proxy verilerek yeniden açar. Böylece kullanıcı hiçbir şey yapmaz.
@MainActor
final class DiscordGuard {
    static let shared = DiscordGuard()
    static let bundleIDs: Set<String> = ["com.hnc.Discord", "com.hnc.DiscordPTB", "com.hnc.DiscordCanary"]
    /// `macdpi discord`un verdiği bayrak; bunu taşıyan Discord bizim açtığımızdır.
    nonisolated static let marker = "--proxy-server=http://127.0.0.1:18080"

    private let cli = MacdpiCLI()
    private var recent: [Date] = []
    private var working = false

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let pid = app?.processIdentifier
            let bundle = app?.bundleIdentifier
            Task { @MainActor in DiscordGuard.shared.check(bundle: bundle, pid: pid) }
        }
        // Geçit'ten önce açılmış (ör. girişte) bir Discord varsa onu da düzelt.
        for app in NSWorkspace.shared.runningApplications {
            check(bundle: app.bundleIdentifier, pid: app.processIdentifier)
        }
    }

    private func check(bundle: String?, pid: pid_t?) {
        guard let bundle, Self.bundleIDs.contains(bundle), let pid, !working else { return }
        let status = AppModel.shared.status
        guard status.installed, status.enabled else { return }
        Task.detached(priority: .userInitiated) {
            let ours = Self.arguments(of: pid).contains(Self.marker)
            await MainActor.run { if !ours { DiscordGuard.shared.relaunch() } }
        }
    }

    private func relaunch() {
        // Bir şeyler ters giderse döngüye girmesin: dakikada en fazla iki kez.
        let now = Date()
        recent = recent.filter { now.timeIntervalSince($0) < 60 }
        guard recent.count < 2, !working else { return }
        recent.append(now)
        working = true
        Task {
            _ = await cli.launchDiscord(restart: true)
            working = false
        }
    }

    /// Aynı kullanıcının sürecinin komut satırı (`ps`); okunamazsa boş.
    nonisolated static func arguments(of pid: pid_t) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-o", "args=", "-p", String(pid)]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

# GecitCore API sözleşmesi (arayüz bu imzalara göre yazılıyor; değiştirmeyin)

Module `GecitCore`, Foundation only (`#if canImport(FoundationNetworking) import FoundationNetworking #endif`).
Must compile on macOS 13+ and Linux (Swift 5.9+ / 6.0 toolchain, language mode 5). All public.

```swift
// Paths.swift
public struct MacdpiPaths: Sendable, Equatable {
    public static let proxyPort: UInt16 = 18080
    public static let pacPort: UInt16 = 18079
    public static let pacURL = URL(string: "http://127.0.0.1:18079/proxy.pac")!
    public var home: URL            // /usr/local/macdpi
    public var cli: URL             // /usr/local/bin/macdpi
    public init(home: URL, cli: URL)
    public static let standard: MacdpiPaths
    public var listFile: URL        // home/etc/engelli-siteler.txt
    public var profileFile: URL     // home/etc/profil
    public var offFlag: URL         // home/etc/kapali
    public var configFile: URL      // home/etc/spoofdpi.toml
    public var spoofLog: URL        // home/log/spoofdpi.log
    public var agentLog: URL        // home/log/agent.log
    public var isInstalled: Bool    // listFile exists AND cli exists
}

// Domain.swift  — mirrors the shell CLI exactly
public enum Domain {
    /// Like `macdpi ekle`: trim whitespace, lowercase, strip "scheme://", strip "/path...",
    /// strip leading "*.", strip leading "www.", strip leading "." ; nil unless isValid.
    public static func normalize(_ input: String) -> String?
    /// ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$
    public static func isValid(_ domain: String) -> Bool
    /// Like common.sh clean_domains: strip "#..." comments, trim, lowercase, strip scheme,
    /// path, "*.", leading "."; keep only valid; sorted ascending, unique.
    /// (Note: does NOT strip "www." — same as the shell.)
    public static func parseList(_ contents: String) -> [String]
}

// SiteGroup.swift
public struct SiteGroup: Identifiable, Equatable, Sendable {
    public var id: String { name }
    public let name: String         // "Discord", "Roblox", "Wattpad", else capitalized first label ("twitch.tv" -> "Twitch")
    public let symbol: String       // SF Symbol: Discord "bubble.left.and.bubble.right.fill", Roblox "gamecontroller.fill", Wattpad "book.fill", other "globe"
    public let domains: [String]    // sorted
}
public enum SiteGrouping {
    /// Known families: Discord = discord*, dis.gd ; Roblox = roblox*, rbx* ; Wattpad = wattpad*.
    /// (match on the label before the TLD, i.e. registrable second-level label, by prefix.)
    /// Others grouped by that same label. Order: Discord, Roblox, Wattpad (when present),
    /// then other groups by name (Turkish-insensitive ascending).
    public static func group(_ domains: [String]) -> [SiteGroup]
}

// Profile.swift
public enum Profile: String, CaseIterable, Identifiable, Sendable {
    case hafif, orta, guclu
    public var id: String { rawValue }
    public var title: String        // "Hafif", "Orta", "Güçlü"
    public var detail: String       // hafif: "İlk paketi site adından ikiye böler. En az müdahale."
                                    // orta:  "Böler ve parçaların sırasını karıştırır. Çoğu ağda yeterli."
                                    // guclu: "İlk paketi bayt bayt gönderir. İnatçı ağlar için."
    public static func read(from url: URL) -> Profile   // trims; default .orta
}

// ANSI.swift
public enum ANSI { public static func strip(_ s: String) -> String }   // removes ESC[ ... letter sequences

// NetworkSetupParser.swift
public enum NetworkSetupParser {
    /// output of `networksetup -listallnetworkservices`: drop first line (the "An asterisk..." note),
    /// drop lines beginning with "*" (disabled), trim, drop empty.
    public static func services(_ output: String) -> [String]
    /// output of `networksetup -getautoproxyurl SVC`: lines "URL: ..." and "Enabled: Yes|No".
    /// url nil when "(null)" or missing.
    public static func autoProxy(_ output: String) -> (url: String?, enabled: Bool)
}

// CommandRunner.swift
public struct CommandResult: Sendable, Equatable { public let exitCode: Int32; public let output: String } // output = stdout+stderr, ANSI stripped
public protocol CommandRunning: Sendable {
    func run(_ executable: String, _ args: [String]) async -> CommandResult
    /// Yields each output line (ANSI stripped) as it arrives; finishes when the process exits.
    func stream(_ executable: String, _ args: [String]) -> AsyncStream<String>
}
public struct ProcessRunner: CommandRunning { public init() }   // Foundation Process + Pipe; never blocks the main thread; failure to launch -> exitCode -1 with message

// PortProbe.swift
public enum PortProbe {
    /// Non-blocking POSIX connect to host:port with timeout. Darwin + Glibc.
    public static func isOpen(host: String = "127.0.0.1", port: UInt16, timeout: TimeInterval = 0.6) -> Bool
}

// EngineStatus.swift
public struct ServiceStatus: Identifiable, Equatable, Sendable {
    public var id: String { name }
    public let name: String         // "Wi-Fi", "iPhone USB", "Thunderbolt Ethernet"...
    public let pacActive: Bool      // our PAC URL set AND enabled
}
public enum Health: Equatable, Sendable { case notInstalled, off, degraded, active }
public struct EngineStatus: Equatable, Sendable {
    public var installed: Bool
    public var enabled: Bool        // !exists(offFlag)
    public var proxyRunning: Bool
    public var pacRunning: Bool
    public var profile: Profile
    public var services: [ServiceStatus]
    public var domains: [String]
    public init(installed:enabled:proxyRunning:pacRunning:profile:services:domains:) // memberwise, public
    public static let placeholder: EngineStatus   // installed true, enabled true, all running, .orta, [], []
    /// notInstalled if !installed; off if !enabled; active if proxyRunning && pacRunning
    /// && (services.isEmpty || services.contains{ $0.pacActive }); else degraded.
    public var health: Health
}

// StatusProbe.swift
public struct StatusProbe: Sendable {
    public init(paths: MacdpiPaths = .standard, runner: CommandRunning = ProcessRunner())
    /// Reads files, probes port 18080, GETs pacURL (timeout 2 s, body contains "FindProxyForURL"),
    /// runs /usr/sbin/networksetup (only when that file exists; else services = []).
    public func probe() async -> EngineStatus
}

// SiteTester.swift
public enum Route: String, Sendable { case viaMacdpi, direct }
public enum Outcome: Equatable, Sendable { case ok(ms: Int, status: Int), failed(String) }
public struct SiteTester: Sendable {
    public static let normalSites: [String] = ["google.com","youtube.com","apple.com","github.com","eksisozluk.com","trendyol.com","hepsiburada.com","sahibinden.com","turkiye.gov.tr","whatsapp.com","instagram.com"]
    public init(timeout: TimeInterval = 10)
    /// GET https://host/ ; any HTTP response = .ok (handshake completed). Ephemeral session, no cache,
    /// does not follow redirects (count the 3xx as ok). viaMacdpi: connectionProxyDictionary
    /// HTTP+HTTPS proxy 127.0.0.1:18080 (string keys "HTTPEnable","HTTPProxy","HTTPPort",
    /// "HTTPSEnable","HTTPSProxy","HTTPSPort"); direct: connectionProxyDictionary = [:] (ignores system PAC).
    /// failed message is short Turkish: "Zaman aşımı", "Bağlantı kesildi", "Bulunamadı", else localizedDescription.
    public func test(host: String, route: Route) async -> Outcome
    /// Picks up to 6 domains from the list for the blocked test, like the CLI: skip "dis.gd",
    /// prefer one per group (first domain of each group), then fill in list order.
    public static func blockedSample(from domains: [String], limit: Int = 6) -> [String]
}

// LogReader.swift
public enum LogReader { public static func tail(_ url: URL, lines: Int) -> [String] }  // [] if unreadable; reads at most last 256 KB

// MacdpiCLI.swift — the only way the app changes state
public struct MacdpiCLI: Sendable {
    public init(paths: MacdpiPaths = .standard, runner: CommandRunning = ProcessRunner())
    public func add(_ domains: [String]) async -> CommandResult        // macdpi ekle d1 d2
    public func remove(_ domains: [String]) async -> CommandResult     // macdpi cikar ...
    public func setEnabled(_ on: Bool) async -> CommandResult          // macdpi ac | kapat
    public func setProfile(_ p: Profile) -> AsyncStream<String>        // macdpi profil <raw>
    public func autoTune() -> AsyncStream<String>                      // macdpi otoayar
    /// Parses a final "Seçildi: <profil>" line from otoayar output. nil if none.
    public static func chosenProfile(fromAutoTuneLine line: String) -> Profile?
}
```

Tests (XCTest, `Tests/GecitCoreTests`) cover: normalize (scheme, path, www, *., uppercase, spaces,
invalid like "a", "-x.com", "x..com", "ex ample.com"), parseList with the real
`../etc/engelli-siteler.txt` content embedded as a string literal, grouping order and names,
Profile.read (missing, junk, "guclu\n"), ANSI.strip with `\u{1B}[32mAÇIK\u{1B}[0m`,
NetworkSetupParser on realistic macOS output, EngineStatus.health table, blockedSample,
chosenProfile, LogReader.tail on a temp file, MacdpiCLI argument building with a fake runner,
StatusProbe with temp-dir paths + fake runner (port closed -> proxyRunning false).

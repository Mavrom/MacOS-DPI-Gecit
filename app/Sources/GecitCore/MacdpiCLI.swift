import Foundation

/// Uygulamanın durumu değiştirmesinin tek yolu.
public struct MacdpiCLI: Sendable {
    private let paths: MacdpiPaths
    private let runner: CommandRunning

    public init(paths: MacdpiPaths = .standard, runner: CommandRunning = ProcessRunner()) {
        self.paths = paths
        self.runner = runner
    }

    private var exe: String { paths.cli.path }

    public func add(_ domains: [String]) async -> CommandResult {
        await runner.run(exe, ["ekle"] + domains)
    }

    public func remove(_ domains: [String]) async -> CommandResult {
        await runner.run(exe, ["cikar"] + domains)
    }

    public func setEnabled(_ on: Bool) async -> CommandResult {
        await runner.run(exe, [on ? "ac" : "kapat"])
    }

    public func setProfile(_ p: Profile) -> AsyncStream<String> {
        runner.stream(exe, ["profil", p.rawValue])
    }

    public func autoTune() -> AsyncStream<String> {
        runner.stream(exe, ["otoayar"])
    }

    /// Ağ değişince: bu ağ için kayıtlı yöntemi kullanır, bilinmeyen ağda `otoayar` çalışır.
    public func networkChanged() -> AsyncStream<String> {
        runner.stream(exe, ["ag"])
    }

    /// otoayar çıktısındaki "Seçildi: <profil>" satırını çözer; yoksa nil.
    public static func chosenProfile(fromAutoTuneLine line: String) -> Profile? {
        let clean = ANSI.strip(line)
        guard let range = clean.range(of: "Seçildi:") else { return nil }
        let rest = clean[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        let token = rest.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
        return Profile(rawValue: token.lowercased())
    }
}

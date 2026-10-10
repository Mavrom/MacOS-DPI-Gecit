import Foundation

public struct MacdpiPaths: Sendable, Equatable {
    public static let proxyPort: UInt16 = 18080
    public static let pacPort: UInt16 = 18079
    public static let pacURL = URL(string: "http://127.0.0.1:18079/proxy.pac")!

    /// /usr/local/macdpi
    public var home: URL
    /// /usr/local/bin/macdpi
    public var cli: URL

    public init(home: URL, cli: URL) {
        self.home = home
        self.cli = cli
    }

    public static let standard = MacdpiPaths(
        home: URL(fileURLWithPath: "/usr/local/macdpi", isDirectory: true),
        cli: URL(fileURLWithPath: "/usr/local/bin/macdpi")
    )

    public var listFile: URL { home.appendingPathComponent("etc/engelli-siteler.txt") }
    public var profileFile: URL { home.appendingPathComponent("etc/profil") }
    public var offFlag: URL { home.appendingPathComponent("etc/kapali") }
    public var configFile: URL { home.appendingPathComponent("etc/spoofdpi.toml") }
    public var spoofLog: URL { home.appendingPathComponent("log/spoofdpi.log") }
    public var agentLog: URL { home.appendingPathComponent("log/agent.log") }

    /// listFile ve cli birlikte varsa kurulu sayılır.
    public var isInstalled: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: listFile.path) && fm.fileExists(atPath: cli.path)
    }
}

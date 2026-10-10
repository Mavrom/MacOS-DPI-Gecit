import Foundation

public struct ServiceStatus: Identifiable, Equatable, Sendable {
    public var id: String { name }
    public let name: String
    /// Bizim PAC adresi ayarlı VE etkin.
    public let pacActive: Bool

    public init(name: String, pacActive: Bool) {
        self.name = name
        self.pacActive = pacActive
    }
}

public enum Health: Equatable, Sendable { case notInstalled, off, degraded, active }

public struct EngineStatus: Equatable, Sendable {
    public var installed: Bool
    public var enabled: Bool
    public var proxyRunning: Bool
    public var pacRunning: Bool
    public var profile: Profile
    public var services: [ServiceStatus]
    public var domains: [String]

    public init(installed: Bool, enabled: Bool, proxyRunning: Bool, pacRunning: Bool,
                profile: Profile, services: [ServiceStatus], domains: [String]) {
        self.installed = installed
        self.enabled = enabled
        self.proxyRunning = proxyRunning
        self.pacRunning = pacRunning
        self.profile = profile
        self.services = services
        self.domains = domains
    }

    public static let placeholder = EngineStatus(
        installed: true, enabled: true, proxyRunning: true, pacRunning: true,
        profile: .orta, services: [], domains: []
    )

    public var health: Health {
        if !installed { return .notInstalled }
        if !enabled { return .off }
        if proxyRunning && pacRunning && (services.isEmpty || services.contains { $0.pacActive }) {
            return .active
        }
        return .degraded
    }
}

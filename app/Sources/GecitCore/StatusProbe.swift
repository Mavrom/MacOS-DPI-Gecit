import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct StatusProbe: Sendable {
    private let paths: MacdpiPaths
    private let runner: CommandRunning
    private let networksetup: String

    public init(paths: MacdpiPaths = .standard, runner: CommandRunning = ProcessRunner()) {
        self.init(paths: paths, runner: runner, networksetup: "/usr/sbin/networksetup")
    }

    /// Testler için: networksetup yolu değiştirilebilir.
    init(paths: MacdpiPaths, runner: CommandRunning, networksetup: String) {
        self.paths = paths
        self.runner = runner
        self.networksetup = networksetup
    }

    /// Dosyaları okur, 18080 portunu yoklar, PAC'ı çeker, ağ servislerine bakar.
    public func probe() async -> EngineStatus {
        let paths = self.paths
        let fm = FileManager.default
        let installed = paths.isInstalled
        let enabled = !fm.fileExists(atPath: paths.offFlag.path)
        let profile = Profile.read(from: paths.profileFile)
        let domains: [String]
        if let data = try? Data(contentsOf: paths.listFile) {
            domains = Domain.parseList(String(decoding: data, as: UTF8.self))
        } else {
            domains = []
        }

        async let proxyOK = StatusProbe.portOpen(MacdpiPaths.proxyPort)
        async let pacOK = StatusProbe.pacServed()
        async let svcs = serviceStatuses()

        return EngineStatus(
            installed: installed,
            enabled: enabled,
            proxyRunning: await proxyOK,
            pacRunning: await pacOK,
            profile: profile,
            services: await svcs,
            domains: domains
        )
    }

    // MARK: - İç yardımcılar

    private static func portOpen(_ port: UInt16) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: PortProbe.isOpen(port: port))
            }
        }
    }

    /// PAC adresine GET (2 sn), gövdede "FindProxyForURL" var mı?
    private static func pacServed() async -> Bool {
        // Port kapalıysa HTTP isteğine hiç girme.
        guard await portOpen(MacdpiPaths.pacPort) else { return false }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        config.timeoutIntervalForResource = 2
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.connectionProxyDictionary = [:]
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: MacdpiPaths.pacURL)
        request.timeoutInterval = 2
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let task = session.dataTask(with: request) { data, response, _ in
                guard let data = data,
                      let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    cont.resume(returning: false)
                    return
                }
                cont.resume(returning: String(decoding: data, as: UTF8.self).contains("FindProxyForURL"))
            }
            task.resume()
        }
    }

    private func serviceStatuses() async -> [ServiceStatus] {
        guard FileManager.default.fileExists(atPath: networksetup) else { return [] }
        let list = await runner.run(networksetup, ["-listallnetworkservices"])
        guard list.exitCode == 0 else { return [] }
        let names = NetworkSetupParser.services(list.output)
        let pac = MacdpiPaths.pacURL.absoluteString
        var result: [ServiceStatus] = []
        for name in names {
            let r = await runner.run(networksetup, ["-getautoproxyurl", name])
            let parsed = NetworkSetupParser.autoProxy(r.output)
            result.append(ServiceStatus(name: name, pacActive: parsed.enabled && parsed.url == pac))
        }
        return result
    }
}

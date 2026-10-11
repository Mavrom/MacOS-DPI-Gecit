import XCTest
@testable import GecitCore

final class ModelTests: XCTestCase {
    // MARK: Gruplama
    func testGroupingRealList() {
        let groups = SiteGrouping.group(Domain.parseList(realList))
        XCTAssertEqual(groups.map(\.name), ["Discord", "Roblox", "Wattpad"])
        XCTAssertEqual(groups.map(\.symbol), ["bubble.left.and.bubble.right.fill", "gamecontroller.fill", "book.fill"])
        XCTAssertEqual(groups[0].domains.count, 12)
        XCTAssertTrue(groups[0].domains.contains("dis.gd"))
        XCTAssertEqual(groups[1].domains, ["rbx.com", "rbxcdn.com", "roblox.com"])
        XCTAssertEqual(groups[2].domains, ["wattpad.com"])
        XCTAssertEqual(groups[0].id, "Discord")
    }

    func testGroupingOthersAndOrder() {
        let groups = SiteGrouping.group(["twitch.tv", "zeta.org", "wattpad.com", "turkiye.gov.tr", "cdn.twitch.tv", "isik.com", "discord.gg"])
        XCTAssertEqual(groups.map(\.name), ["Discord", "Wattpad", "Isik", "Turkiye", "Twitch", "Zeta"])
        XCTAssertEqual(groups.first { $0.name == "Twitch" }?.domains, ["cdn.twitch.tv", "twitch.tv"])
        XCTAssertEqual(groups.first { $0.name == "Twitch" }?.symbol, "globe")
        XCTAssertEqual(SiteGrouping.group([]), [])
    }

    func testGroupingOnlyOthersSorted() {
        let groups = SiteGrouping.group(["b.com", "a.com", "c.org"])
        XCTAssertEqual(groups.map(\.name), ["A", "B", "C"])
    }

    // MARK: Profil
    func testProfileRead() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gecit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        XCTAssertEqual(Profile.read(from: dir.appendingPathComponent("yok")), .orta)

        let f = dir.appendingPathComponent("profil")
        try "guclu\n".write(to: f, atomically: true, encoding: .utf8)
        XCTAssertEqual(Profile.read(from: f), .guclu)
        try "  hafif  ".write(to: f, atomically: true, encoding: .utf8)
        XCTAssertEqual(Profile.read(from: f), .hafif)
        try "cokguclu\n".write(to: f, atomically: true, encoding: .utf8)
        XCTAssertEqual(Profile.read(from: f), .cokguclu)
        try "bozuk".write(to: f, atomically: true, encoding: .utf8)
        XCTAssertEqual(Profile.read(from: f), .orta)
        try "".write(to: f, atomically: true, encoding: .utf8)
        XCTAssertEqual(Profile.read(from: f), .orta)
    }

    func testProfileText() {
        XCTAssertEqual(Profile.allCases, [.hafif, .orta, .guclu, .cokguclu])
        XCTAssertEqual(Profile.cokguclu.title, "Çok güçlü")
        XCTAssertEqual(Profile.guclu.title, "Güçlü")
        XCTAssertEqual(Profile.hafif.detail, "İlk paketi site adının ortasından iki TLS kaydına böler. Gecikme eklemez.")
        XCTAssertEqual(Profile.orta.detail, "Kayıtlara böler ve parçaların sırasını karıştırır. İnatçı ağlar için.")
        XCTAssertEqual(Profile.guclu.detail, "İlk paketi bayt bayt gönderir. İnatçı ağlar için.")
        XCTAssertEqual(Profile.orta.id, "orta")
    }

    // MARK: ANSI
    func testANSIStrip() {
        XCTAssertEqual(ANSI.strip("\u{1B}[32mAÇIK\u{1B}[0m"), "AÇIK")
        XCTAssertEqual(ANSI.strip("  \u{1B}[31mAÇILMIYOR\u{1B}[0m discord.com"), "  AÇILMIYOR discord.com")
        XCTAssertEqual(ANSI.strip("düz metin"), "düz metin")
        XCTAssertEqual(ANSI.strip("\u{1B}[1;32mx\u{1B}[0m"), "x")
    }

    // MARK: networksetup
    func testServices() {
        let out = """
        An asterisk (*) denotes that a network service is disabled.
        Wi-Fi
        iPhone USB
        *Thunderbolt Bridge
        Thunderbolt Ethernet

        """
        XCTAssertEqual(NetworkSetupParser.services(out), ["Wi-Fi", "iPhone USB", "Thunderbolt Ethernet"])
        XCTAssertEqual(NetworkSetupParser.services(""), [])
    }

    func testAutoProxy() {
        let on = "URL: http://127.0.0.1:18079/proxy.pac\nEnabled: Yes\n"
        let r1 = NetworkSetupParser.autoProxy(on)
        XCTAssertEqual(r1.url, "http://127.0.0.1:18079/proxy.pac")
        XCTAssertTrue(r1.enabled)

        let off = "URL: (null)\nEnabled: No\n"
        let r2 = NetworkSetupParser.autoProxy(off)
        XCTAssertNil(r2.url)
        XCTAssertFalse(r2.enabled)

        let r3 = NetworkSetupParser.autoProxy("URL: http://x/y.pac\nEnabled: No\n")
        XCTAssertEqual(r3.url, "http://x/y.pac")
        XCTAssertFalse(r3.enabled)

        let r4 = NetworkSetupParser.autoProxy("")
        XCTAssertNil(r4.url)
        XCTAssertFalse(r4.enabled)
    }

    // MARK: EngineStatus.health
    func testHealthTable() {
        func make(installed: Bool = true, enabled: Bool = true, proxy: Bool = true, pac: Bool = true,
                  services: [ServiceStatus] = []) -> EngineStatus {
            EngineStatus(installed: installed, enabled: enabled, proxyRunning: proxy, pacRunning: pac,
                         profile: .orta, services: services, domains: [])
        }
        let on = ServiceStatus(name: "Wi-Fi", pacActive: true)
        let offSvc = ServiceStatus(name: "iPhone USB", pacActive: false)

        XCTAssertEqual(make(installed: false).health, .notInstalled)
        XCTAssertEqual(make(installed: false, enabled: false).health, .notInstalled)
        XCTAssertEqual(make(enabled: false).health, .off)
        XCTAssertEqual(make().health, .active)
        XCTAssertEqual(make(services: [on]).health, .active)
        XCTAssertEqual(make(services: [offSvc, on]).health, .active)
        XCTAssertEqual(make(services: [offSvc]).health, .degraded)
        XCTAssertEqual(make(proxy: false).health, .degraded)
        XCTAssertEqual(make(pac: false, services: [on]).health, .degraded)
        XCTAssertEqual(EngineStatus.placeholder.health, .active)
        XCTAssertEqual(on.id, "Wi-Fi")
    }

    // MARK: blockedSample
    func testBlockedSample() {
        let list = Domain.parseList(realList)
        let sample = SiteTester.blockedSample(from: list)
        XCTAssertEqual(sample.count, 6)
        XCTAssertFalse(sample.contains("dis.gd"))
        XCTAssertEqual(Set(sample).count, 6)
        // her gruptan birer alan adı
        XCTAssertTrue(sample.contains("discord.co"))
        XCTAssertTrue(sample.contains("rbx.com"))
        XCTAssertTrue(sample.contains("wattpad.com"))
        XCTAssertEqual(sample.prefix(3), ["discord.co", "rbx.com", "wattpad.com"])
        XCTAssertEqual(Array(sample.suffix(3)), ["discord.com", "discord.dev", "discord.gg"])

        XCTAssertEqual(SiteTester.blockedSample(from: ["dis.gd"]), [])
        XCTAssertEqual(SiteTester.blockedSample(from: ["a.com", "b.com"], limit: 1), ["a.com"])
        XCTAssertEqual(SiteTester.blockedSample(from: []), [])
        XCTAssertEqual(SiteTester.normalSites.count, 11)
    }

    // MARK: chosenProfile
    func testChosenProfile() {
        XCTAssertEqual(MacdpiCLI.chosenProfile(fromAutoTuneLine: "Seçildi: hafif"), .hafif)
        XCTAssertEqual(MacdpiCLI.chosenProfile(fromAutoTuneLine: "\u{1B}[32mSeçildi:\u{1B}[0m guclu"), .guclu)
        XCTAssertEqual(MacdpiCLI.chosenProfile(fromAutoTuneLine: "Seçildi: cokguclu"), .cokguclu)
        XCTAssertEqual(MacdpiCLI.chosenProfile(fromAutoTuneLine: "Seçildi: orta  "), .orta)
        XCTAssertNil(MacdpiCLI.chosenProfile(fromAutoTuneLine: "Deneniyor: orta"))
        XCTAssertNil(MacdpiCLI.chosenProfile(fromAutoTuneLine: "Seçildi: bilinmeyen"))
        XCTAssertNil(MacdpiCLI.chosenProfile(fromAutoTuneLine: ""))
    }

    // MARK: Paths
    func testPaths() throws {
        let p = MacdpiPaths.standard
        XCTAssertEqual(p.listFile.path, "/usr/local/macdpi/etc/engelli-siteler.txt")
        XCTAssertEqual(p.profileFile.path, "/usr/local/macdpi/etc/profil")
        XCTAssertEqual(p.offFlag.path, "/usr/local/macdpi/etc/kapali")
        XCTAssertEqual(p.configFile.path, "/usr/local/macdpi/etc/spoofdpi.toml")
        XCTAssertEqual(p.spoofLog.path, "/usr/local/macdpi/log/spoofdpi.log")
        XCTAssertEqual(p.agentLog.path, "/usr/local/macdpi/log/agent.log")
        XCTAssertEqual(p.cli.path, "/usr/local/bin/macdpi")
        XCTAssertEqual(MacdpiPaths.pacURL.absoluteString, "http://127.0.0.1:18079/proxy.pac")
        XCTAssertEqual(MacdpiPaths.proxyPort, 18080)
        XCTAssertEqual(MacdpiPaths.pacPort, 18079)
    }
}

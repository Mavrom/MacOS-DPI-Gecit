import XCTest
@testable import GecitCore

/// Kayıt tutan sahte çalıştırıcı.
final class FakeRunner: CommandRunning, @unchecked Sendable {
    struct Call: Equatable { let exe: String; let args: [String] }
    private let lock = NSLock()
    private var _calls: [Call] = []
    var calls: [Call] { lock.lock(); defer { lock.unlock() }; return _calls }
    private func record(_ c: Call) { lock.lock(); _calls.append(c); lock.unlock() }
    var handler: @Sendable (String, [String]) -> CommandResult
    var streamLines: [String] = []

    init(handler: @escaping @Sendable (String, [String]) -> CommandResult = { _, _ in CommandResult(exitCode: 0, output: "") }) {
        self.handler = handler
    }

    func run(_ executable: String, _ args: [String]) async -> CommandResult {
        record(Call(exe: executable, args: args))
        return handler(executable, args)
    }

    func stream(_ executable: String, _ args: [String]) -> AsyncStream<String> {
        record(Call(exe: executable, args: args))
        let lines = streamLines
        return AsyncStream { c in
            for l in lines { c.yield(l) }
            c.finish()
        }
    }
}

func makeTempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gecit-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

final class LogReaderTests: XCTestCase {
    func testTail() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let f = dir.appendingPathComponent("a.log")
        try (1...10).map { "satır \($0)" }.joined(separator: "\n").appending("\n").write(to: f, atomically: true, encoding: .utf8)
        XCTAssertEqual(LogReader.tail(f, lines: 3), ["satır 8", "satır 9", "satır 10"])
        XCTAssertEqual(LogReader.tail(f, lines: 100).count, 10)
        XCTAssertEqual(LogReader.tail(f, lines: 0), [])
    }

    func testTailMissingAndEmpty() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertEqual(LogReader.tail(dir.appendingPathComponent("yok.log"), lines: 5), [])
        let f = dir.appendingPathComponent("bos.log")
        try "".write(to: f, atomically: true, encoding: .utf8)
        XCTAssertEqual(LogReader.tail(f, lines: 5), [])
    }

    func testTailLargeFileReadsOnlyEnd() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let f = dir.appendingPathComponent("big.log")
        var text = ""
        for i in 0..<30000 { text += "kayıt numarası \(i) ------------------------\n" }
        XCTAssertGreaterThan(text.utf8.count, 256 * 1024)
        try text.write(to: f, atomically: true, encoding: .utf8)
        let last = LogReader.tail(f, lines: 2)
        XCTAssertEqual(last.count, 2)
        XCTAssertTrue(last[1].hasPrefix("kayıt numarası 29999 "))
        XCTAssertTrue(last[0].hasPrefix("kayıt numarası 29998 "))
        // 256 KB sınırı: istenen satır çok olsa da en çok o kadar döner
        XCTAssertLessThan(LogReader.tail(f, lines: 1_000_000).count, 30000)
    }
}

final class CLITests: XCTestCase {
    func testArguments() async {
        let runner = FakeRunner()
        let cli = MacdpiCLI(paths: .standard, runner: runner)
        _ = await cli.add(["a.com", "b.com"])
        _ = await cli.remove(["a.com"])
        _ = await cli.setEnabled(true)
        _ = await cli.setEnabled(false)
        _ = await cli.launchDiscord(restart: true)
        _ = await cli.launchDiscord(restart: false)
        XCTAssertEqual(runner.calls, [
            .init(exe: "/usr/local/bin/macdpi", args: ["ekle", "a.com", "b.com"]),
            .init(exe: "/usr/local/bin/macdpi", args: ["cikar", "a.com"]),
            .init(exe: "/usr/local/bin/macdpi", args: ["ac"]),
            .init(exe: "/usr/local/bin/macdpi", args: ["kapat"]),
            .init(exe: "/usr/local/bin/macdpi", args: ["discord", "--yeniden"]),
            .init(exe: "/usr/local/bin/macdpi", args: ["discord"]),
        ])
    }

    func testResultPassthrough() async {
        let runner = FakeRunner { _, _ in CommandResult(exitCode: 1, output: "Zaten listede: a.com") }
        let r = await MacdpiCLI(runner: runner).add(["a.com"])
        XCTAssertEqual(r, CommandResult(exitCode: 1, output: "Zaten listede: a.com"))
    }

    func testStreams() async {
        let runner = FakeRunner()
        runner.streamLines = ["Deneniyor: hafif", "Seçildi: hafif"]
        let cli = MacdpiCLI(paths: MacdpiPaths(home: URL(fileURLWithPath: "/h"), cli: URL(fileURLWithPath: "/h/bin/macdpi")), runner: runner)
        var got: [String] = []
        for await l in cli.setProfile(.guclu) { got.append(l) }
        for await l in cli.autoTune() { got.append(l) }
        for await l in cli.networkChanged() { got.append(l) }
        XCTAssertEqual(got.count, 6)
        XCTAssertEqual(runner.calls, [
            .init(exe: "/h/bin/macdpi", args: ["profil", "guclu"]),
            .init(exe: "/h/bin/macdpi", args: ["otoayar"]),
            .init(exe: "/h/bin/macdpi", args: ["ag"]),
        ])
    }
}

final class StatusProbeTests: XCTestCase {
    private func makeHome(offFlag: Bool = false, profile: String? = "guclu") throws -> MacdpiPaths {
        let dir = try makeTempDir()
        let etc = dir.appendingPathComponent("etc")
        try FileManager.default.createDirectory(at: etc, withIntermediateDirectories: true)
        try "# x\ndiscord.com\nroblox.com\n".write(to: etc.appendingPathComponent("engelli-siteler.txt"), atomically: true, encoding: .utf8)
        if let profile { try profile.write(to: etc.appendingPathComponent("profil"), atomically: true, encoding: .utf8) }
        if offFlag { try "".write(to: etc.appendingPathComponent("kapali"), atomically: true, encoding: .utf8) }
        let cli = dir.appendingPathComponent("macdpi")
        try "#!/bin/sh\n".write(to: cli, atomically: true, encoding: .utf8)
        return MacdpiPaths(home: dir, cli: cli)
    }

    func testProbeReadsFilesAndClosedPort() async throws {
        let paths = try makeHome()
        defer { try? FileManager.default.removeItem(at: paths.home) }
        let runner = FakeRunner()
        // networksetup yolunu yok sayılan bir yere ver: sonuç macOS'ta da Linux'ta da aynı olsun.
        let status = await StatusProbe(paths: paths, runner: runner, networksetup: "/yok/networksetup").probe()
        XCTAssertTrue(status.installed)
        XCTAssertTrue(status.enabled)
        XCTAssertEqual(status.profile, .guclu)
        XCTAssertEqual(status.domains, ["discord.com", "roblox.com"])
        XCTAssertFalse(status.proxyRunning)      // 18080 test ortamında kapalı
        XCTAssertFalse(status.pacRunning)
        XCTAssertEqual(status.services, [])      // networksetup yok -> çalıştırılmaz
        XCTAssertEqual(status.health, .degraded)
        XCTAssertTrue(runner.calls.isEmpty)
    }

    func testProbeOffAndNotInstalled() async throws {
        let paths = try makeHome(offFlag: true, profile: nil)
        defer { try? FileManager.default.removeItem(at: paths.home) }
        let off = await StatusProbe(paths: paths, runner: FakeRunner()).probe()
        XCTAssertFalse(off.enabled)
        XCTAssertEqual(off.profile, .orta)
        XCTAssertEqual(off.health, .off)

        let missing = MacdpiPaths(home: paths.home.appendingPathComponent("yok"), cli: paths.home.appendingPathComponent("yok/macdpi"))
        let s = await StatusProbe(paths: missing, runner: FakeRunner()).probe()
        XCTAssertFalse(s.installed)
        XCTAssertEqual(s.domains, [])
        XCTAssertEqual(s.health, .notInstalled)
    }

    func testProbeServicesViaFakeRunner() async throws {
        let paths = try makeHome()
        defer { try? FileManager.default.removeItem(at: paths.home) }
        let fakeNS = paths.home.appendingPathComponent("networksetup").path
        try "".write(toFile: fakeNS, atomically: true, encoding: .utf8)

        let runner = FakeRunner { _, args in
            if args == ["-listallnetworkservices"] {
                return CommandResult(exitCode: 0, output: "An asterisk (*) denotes that a network service is disabled.\nWi-Fi\n*Bridge\niPhone USB\n")
            }
            if args == ["-getautoproxyurl", "Wi-Fi"] {
                return CommandResult(exitCode: 0, output: "URL: http://127.0.0.1:18079/proxy.pac\nEnabled: Yes\n")
            }
            return CommandResult(exitCode: 0, output: "URL: (null)\nEnabled: No\n")
        }
        let status = await StatusProbe(paths: paths, runner: runner, networksetup: fakeNS).probe()
        XCTAssertEqual(status.services, [ServiceStatus(name: "Wi-Fi", pacActive: true), ServiceStatus(name: "iPhone USB", pacActive: false)])
        XCTAssertEqual(runner.calls.map(\.args), [["-listallnetworkservices"], ["-getautoproxyurl", "Wi-Fi"], ["-getautoproxyurl", "iPhone USB"]])
    }
}

final class ProcessRunnerTests: XCTestCase {
    func testRunCapturesOutputAndExitCode() async {
        let r = await ProcessRunner().run("/bin/sh", ["-c", "printf '\\033[32mAÇIK\\033[0m\\n'; echo err >&2; exit 3"])
        XCTAssertEqual(r.exitCode, 3)
        XCTAssertTrue(r.output.contains("AÇIK"))
        XCTAssertTrue(r.output.contains("err"))
        XCTAssertFalse(r.output.contains("\u{1B}"))
    }

    func testRunLargeOutputDoesNotDeadlock() async {
        let r = await ProcessRunner().run("/bin/sh", ["-c", "i=0; while [ $i -lt 20000 ]; do echo 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'; i=$((i+1)); done"])
        XCTAssertEqual(r.exitCode, 0)
        XCTAssertGreaterThan(r.output.utf8.count, 1_000_000)
    }

    func testLaunchFailure() async {
        let r = await ProcessRunner().run("/yok/boyle/bir/komut", [])
        XCTAssertEqual(r.exitCode, -1)
        XCTAssertFalse(r.output.isEmpty)
    }

    func testPathLookup() async {
        let r = await ProcessRunner().run("echo", ["merhaba"])
        XCTAssertEqual(r.exitCode, 0)
        XCTAssertEqual(r.output.trimmingCharacters(in: .whitespacesAndNewlines), "merhaba")
    }

    func testStreamYieldsLinesAndFinishes() async {
        var lines: [String] = []
        for await l in ProcessRunner().stream("/bin/sh", ["-c", "echo bir; echo iki; printf '\\033[31mkirmizi\\033[0m\\n'; printf 'sonsuz'"]) {
            lines.append(l)
        }
        XCTAssertEqual(lines, ["bir", "iki", "kirmizi", "sonsuz"])
    }

    func testStreamIsIncremental() async {
        // İlk satır, süreç bitmeden (2 sn uyku) gelmeli.
        let start = Date()
        var firstAt: TimeInterval?
        var count = 0
        for await _ in ProcessRunner().stream("/bin/sh", ["-c", "echo ilk; sleep 1.5; echo son"]) {
            if firstAt == nil { firstAt = Date().timeIntervalSince(start) }
            count += 1
        }
        XCTAssertEqual(count, 2)
        XCTAssertLessThan(firstAt ?? 99, 1.0)
    }
}

final class PortProbeTests: XCTestCase {
    func testClosedPort() {
        // Kullanılmayan bir port: kendi ayırıp bırakamayız, bu yüzden nadir bir port.
        XCTAssertFalse(PortProbe.isOpen(port: 1, timeout: 0.3))
    }
}

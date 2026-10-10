import Foundation

public struct CommandResult: Sendable, Equatable {
    public let exitCode: Int32
    /// stdout + stderr, ANSI temizlenmiş.
    public let output: String

    public init(exitCode: Int32, output: String) {
        self.exitCode = exitCode
        self.output = output
    }
}

public protocol CommandRunning: Sendable {
    func run(_ executable: String, _ args: [String]) async -> CommandResult
    /// Her çıktı satırını (ANSI temizlenmiş) geldikçe verir; süreç bitince tamamlanır.
    func stream(_ executable: String, _ args: [String]) -> AsyncStream<String>
}

/// `Process` + `Pipe`. Çağıran iş parçacığını bloklamaz.
public struct ProcessRunner: CommandRunning {
    public init() {}

    public func run(_ executable: String, _ args: [String]) async -> CommandResult {
        await withCheckedContinuation { (cont: CheckedContinuation<CommandResult, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: ProcessRunner.runBlocking(executable, args))
            }
        }
    }

    public func stream(_ executable: String, _ args: [String]) -> AsyncStream<String> {
        AsyncStream<String> { continuation in
            let box = ProcessBox()
            continuation.onTermination = { _ in box.terminate() }
            DispatchQueue.global(qos: .userInitiated).async {
                ProcessRunner.streamBlocking(executable, args, box: box) { line in
                    continuation.yield(line)
                }
                continuation.finish()
            }
        }
    }

    // MARK: - İç yardımcılar

    /// Kilit korumalı süreç kutusu (iptal için).
    private final class ProcessBox: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?
        private var cancelled = false

        /// İptal edilmişse false döner.
        func set(_ p: Process) -> Bool {
            lock.lock(); defer { lock.unlock() }
            if cancelled { return false }
            process = p
            return true
        }

        func terminate() {
            lock.lock()
            cancelled = true
            let p = process
            lock.unlock()
            if let p = p, p.isRunning { p.terminate() }
        }
    }

    private static func makeProcess(_ executable: String, _ args: [String]) -> (Process, Pipe) {
        let process = Process()
        if executable.contains("/") {
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [executable] + args
        }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        return (process, pipe)
    }

    private static func runBlocking(_ executable: String, _ args: [String]) -> CommandResult {
        let (process, pipe) = makeProcess(executable, args)
        do {
            try process.run()
        } catch {
            return CommandResult(exitCode: -1, output: "Komut başlatılamadı: \(executable): \(error.localizedDescription)")
        }
        // Önce sonuna kadar oku (boru dolup süreç takılmasın), sonra bitmesini bekle.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
        return CommandResult(exitCode: process.terminationStatus, output: ANSI.strip(text))
    }

    private static func streamBlocking(_ executable: String, _ args: [String], box: ProcessBox, emit: (String) -> Void) {
        let (process, pipe) = makeProcess(executable, args)
        do {
            try process.run()
        } catch {
            emit("Komut başlatılamadı: \(executable): \(error.localizedDescription)")
            return
        }
        if !box.set(process) {
            process.terminate()
            process.waitUntilExit()
            return
        }
        var pending = Data()
        let handle = pipe.fileHandleForReading
        func flush(_ final: Bool) {
            while let nl = pending.firstIndex(where: { $0 == 0x0A }) {
                let lineData = pending[pending.startIndex..<nl]
                pending = Data(pending[pending.index(after: nl)...])
                emitLine(lineData, emit)
            }
            if final, !pending.isEmpty {
                emitLine(pending, emit)
                pending = Data()
            }
        }
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            pending.append(chunk)
            flush(false)
        }
        flush(true)
        process.waitUntilExit()
    }

    private static func emitLine(_ data: Data, _ emit: (String) -> Void) {
        var s = String(decoding: data, as: UTF8.self)
        if s.hasSuffix("\r") { s.removeLast() }
        emit(ANSI.strip(s))
    }
}

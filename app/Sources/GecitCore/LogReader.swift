import Foundation

public enum LogReader {
    /// Dosyanın son `lines` satırı; okunamazsa []. En çok son 256 KB okunur.
    public static func tail(_ url: URL, lines: Int) -> [String] {
        guard lines > 0, let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        let maxBytes: UInt64 = 256 * 1024
        guard let size = try? handle.seekToEnd() else { return [] }
        let start = size > maxBytes ? size - maxBytes : 0
        do {
            try handle.seek(toOffset: start)
        } catch { return [] }
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return [] }

        var text = String(decoding: data, as: UTF8.self)
        var all = text.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" }).map(String.init)
        text = ""
        if start > 0, !all.isEmpty { all.removeFirst() }   // yarım kalan ilk satır
        if let last = all.last, last.isEmpty { all.removeLast() }
        return Array(all.suffix(lines))
    }
}

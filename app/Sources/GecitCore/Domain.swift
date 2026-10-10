import Foundation

/// Kabuktaki `macdpi` / `common.sh` davranışını birebir yansıtır.
public enum Domain {
    /// `macdpi ekle` gibi: boşlukları kırp, küçük harfe çevir, "şema://", "/yol...",
    /// baştaki "*.", "www." ve "." at. Geçerli değilse nil.
    public static func normalize(_ input: String) -> String? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        s = stripScheme(s)
        s = stripPath(s)
        if s.hasPrefix("*.") { s.removeFirst(2) }
        if s.hasPrefix("www.") { s.removeFirst(4) }
        if s.hasPrefix(".") { s.removeFirst(1) }
        return isValid(s) ? s : nil
    }

    /// ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$
    public static func isValid(_ domain: String) -> Bool {
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        for label in labels {
            guard isValidLabel(label) else { return false }
        }
        return true
    }

    /// common.sh `clean_domains`: yorumları at, kırp, küçük harf, şema, yol, "*.", baştaki "."
    /// at; yalnızca geçerli olanları artan sırada ve tekrarsız döndür.
    /// ("www." AYRIŞTIRILMAZ; kabuktaki gibi.)
    public static func parseList(_ contents: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        let lines = contents.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" })
        for rawLine in lines {
            var s = String(rawLine)
            if let hash = s.firstIndex(of: "#") { s = String(s[s.startIndex..<hash]) }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            s = stripScheme(s)
            s = stripPath(s)
            if s.hasPrefix("*.") { s.removeFirst(2) }
            if s.hasPrefix(".") { s.removeFirst(1) }
            guard isValid(s), seen.insert(s).inserted else { continue }
            result.append(s)
        }
        return result.sorted { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }
    }

    // MARK: - İç yardımcılar

    /// sed 's#^[a-z]*://##'
    static func stripScheme(_ s: String) -> String {
        var idx = s.startIndex
        while idx < s.endIndex, let a = s[idx].asciiValue, a >= 97, a <= 122 {
            idx = s.index(after: idx)
        }
        let rest = s[idx...]
        if rest.hasPrefix("://") {
            return String(rest.dropFirst(3))
        }
        return s
    }

    /// sed 's#/.*##'
    static func stripPath(_ s: String) -> String {
        if let slash = s.firstIndex(of: "/") { return String(s[s.startIndex..<slash]) }
        return s
    }

    private static func isAlnum(_ b: UInt8) -> Bool {
        (b >= 97 && b <= 122) || (b >= 48 && b <= 57)
    }

    private static func isValidLabel(_ label: Substring) -> Bool {
        let bytes = Array(label.utf8)
        guard let first = bytes.first, let last = bytes.last else { return false }
        guard isAlnum(first), isAlnum(last) else { return false }
        for b in bytes where !(isAlnum(b) || b == 45) { return false }
        return true
    }
}

import Foundation

public enum ANSI {
    /// ESC [ ... harf dizilerini (renk vb.) siler.
    public static func strip(_ s: String) -> String {
        guard s.unicodeScalars.contains("\u{1B}") else { return s }
        var out = String.UnicodeScalarView()
        let scalars = Array(s.unicodeScalars)
        var i = 0
        while i < scalars.count {
            let c = scalars[i]
            if c == "\u{1B}" {
                if i + 1 < scalars.count, scalars[i + 1] == "[" {
                    var j = i + 2
                    // Parametre ve ara baytlar (0x20-0x3F), ardından son bayt (0x40-0x7E).
                    while j < scalars.count, scalars[j].value >= 0x20, scalars[j].value <= 0x3F { j += 1 }
                    if j < scalars.count, scalars[j].value >= 0x40, scalars[j].value <= 0x7E {
                        i = j + 1
                        continue
                    }
                    // Eksik dizi: ESC[ ve parametreleri at.
                    i = j
                    continue
                }
                // Tek başına ESC
                i += 1
                continue
            }
            out.append(c)
            i += 1
        }
        return String(out)
    }
}

import Foundation

public enum NetworkSetupParser {
    /// `networksetup -listallnetworkservices` çıktısı: ilk satır (yıldız açıklaması) atılır,
    /// "*" ile başlayanlar (devre dışı) atılır, kırpılır, boşlar atılır.
    public static func services(_ output: String) -> [String] {
        let lines = output.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r" })
        return lines.dropFirst()
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("*") }
    }

    /// `networksetup -getautoproxyurl SVC` çıktısı: "URL: ..." ve "Enabled: Yes|No" satırları.
    public static func autoProxy(_ output: String) -> (url: String?, enabled: Bool) {
        var url: String?
        var enabled = false
        for rawLine in output.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("URL:") {
                let value = line.dropFirst(4).trimmingCharacters(in: .whitespaces)
                url = (value.isEmpty || value == "(null)") ? nil : value
            } else if line.hasPrefix("Enabled:") {
                let value = line.dropFirst(8).trimmingCharacters(in: .whitespaces).lowercased()
                enabled = (value == "yes")
            }
        }
        return (url, enabled)
    }
}

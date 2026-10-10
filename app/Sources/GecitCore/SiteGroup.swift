import Foundation

public struct SiteGroup: Identifiable, Equatable, Sendable {
    public var id: String { name }
    public let name: String
    public let symbol: String
    public let domains: [String]

    public init(name: String, symbol: String, domains: [String]) {
        self.name = name
        self.symbol = symbol
        self.domains = domains
    }
}

public enum SiteGrouping {
    /// Bilinen aileler: Discord = discord*, dis.gd; Roblox = roblox*, rbx*; Wattpad = wattpad*.
    /// Eşleşme, TLD'den önceki (kayıtlı) etiket üzerinden önek ile yapılır.
    public static func group(_ domains: [String]) -> [SiteGroup] {
        var buckets: [String: [String]] = [:]
        var seen = Set<String>()
        for d in domains where seen.insert(d).inserted {
            buckets[groupName(for: d), default: []].append(d)
        }

        let known = ["Discord", "Roblox", "Wattpad"]
        var result: [SiteGroup] = []
        for name in known {
            if let ds = buckets[name] {
                result.append(SiteGroup(name: name, symbol: symbol(for: name), domains: sortedASCII(ds)))
            }
        }
        let others = buckets.keys.filter { !known.contains($0) }.sorted(by: nameLess)
        for name in others {
            result.append(SiteGroup(name: name, symbol: symbol(for: name), domains: sortedASCII(buckets[name] ?? [])))
        }
        return result
    }

    // MARK: - İç yardımcılar

    private static let secondLevelLabels: Set<String> = [
        "com", "co", "org", "net", "gov", "edu", "gen", "biz", "info", "web",
        "k12", "av", "bel", "tsk", "pol", "mil", "name", "ac",
    ]

    /// TLD'den önceki etiket (turkiye.gov.tr -> "turkiye", bbc.co.uk -> "bbc").
    static func registrableLabel(of domain: String) -> String {
        let labels = domain.split(separator: ".").map(String.init)
        guard labels.count >= 2 else { return domain }
        let tld = labels[labels.count - 1]
        let sld = labels[labels.count - 2]
        if labels.count >= 3, tld.count == 2, secondLevelLabels.contains(sld) {
            return labels[labels.count - 3]
        }
        return sld
    }

    static func groupName(for domain: String) -> String {
        let label = registrableLabel(of: domain)
        if label.hasPrefix("discord") || domain == "dis.gd" { return "Discord" }
        if label.hasPrefix("roblox") || label.hasPrefix("rbx") { return "Roblox" }
        if label.hasPrefix("wattpad") { return "Wattpad" }
        return capitalized(label)
    }

    static func symbol(for name: String) -> String {
        switch name {
        case "Discord": return "bubble.left.and.bubble.right.fill"
        case "Roblox": return "gamecontroller.fill"
        case "Wattpad": return "book.fill"
        default: return "globe"
        }
    }

    private static func capitalized(_ s: String) -> String {
        guard let first = s.first else { return s }
        return String(first).uppercased() + s.dropFirst()
    }

    private static func sortedASCII(_ a: [String]) -> [String] {
        a.sorted { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }
    }

    private static func nameLess(_ a: String, _ b: String) -> Bool {
        let fa = a.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let fb = b.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        if fa != fb { return fa < fb }
        return a < b
    }
}

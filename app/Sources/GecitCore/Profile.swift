import Foundation

public enum Profile: String, CaseIterable, Identifiable, Sendable {
    case hafif, orta, guclu, cokguclu

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hafif: return "Hafif"
        case .orta: return "Orta"
        case .guclu: return "Güçlü"
        case .cokguclu: return "Çok güçlü"
        }
    }

    public var detail: String {
        switch self {
        case .hafif: return "İlk paketi site adının ortasından iki TLS kaydına böler. Gecikme eklemez."
        case .orta: return "Kayıtlara böler ve parçaların sırasını karıştırır. İnatçı ağlar için."
        case .guclu: return "İlk paketi bayt bayt gönderir. İnatçı ağlar için."
        case .cokguclu: return "Önce operatörün göreceği sahte bir ilk paket, sonra gerçeğini bölerek gönderir. Mobil hat gibi en inatçı ağlar için."
        }
    }

    /// Dosyayı okur, kırpar; okunamazsa ya da bilinmiyorsa `.orta`.
    public static func read(from url: URL) -> Profile {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return .orta }
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Profile(rawValue: name) ?? .orta
    }
}

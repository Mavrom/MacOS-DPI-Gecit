import Foundation

public enum Profile: String, CaseIterable, Identifiable, Sendable {
    case hafif, orta, guclu

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hafif: return "Hafif"
        case .orta: return "Orta"
        case .guclu: return "Güçlü"
        }
    }

    public var detail: String {
        switch self {
        case .hafif: return "İlk paketi site adından ikiye böler. En az müdahale."
        case .orta: return "Böler ve parçaların sırasını karıştırır. Çoğu ağda yeterli."
        case .guclu: return "İlk paketi bayt bayt gönderir. İnatçı ağlar için."
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

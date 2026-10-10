import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum Route: String, Sendable { case viaMacdpi, direct }
public enum Outcome: Equatable, Sendable { case ok(ms: Int, status: Int), failed(String) }

public struct SiteTester: Sendable {
    public static let normalSites: [String] = [
        "google.com", "youtube.com", "apple.com", "github.com", "eksisozluk.com",
        "trendyol.com", "hepsiburada.com", "sahibinden.com", "turkiye.gov.tr",
        "whatsapp.com", "instagram.com",
    ]

    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 10) {
        self.timeout = timeout
    }

    /// GET https://host/ ; herhangi bir HTTP yanıtı (3xx dahil) = .ok.
    /// `measureWarm` açıksa, açılan siteye aynı bağlantı üzerinden bir HEAD daha gönderilir ve
    /// süre olarak o kullanılır: DNS, bağlantı kurma ve şifreleme dışarıda kalır, ping'e yakın
    /// "gidip gelme" süresi ölçülür (tarayıcı da bağlantıyı böyle yeniden kullanır).
    public func test(host: String, route: Route, measureWarm: Bool = false) async -> Outcome {
        guard let url = URL(string: "https://\(host)/") else { return .failed("Geçersiz adres") }

        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        switch route {
        case .viaMacdpi:
            let port = Int(MacdpiPaths.proxyPort)
            config.connectionProxyDictionary = [
                "HTTPEnable": 1, "HTTPProxy": "127.0.0.1", "HTTPPort": port,
                "HTTPSEnable": 1, "HTTPSProxy": "127.0.0.1", "HTTPSPort": port,
            ]
        case .direct:
            config.connectionProxyDictionary = [:]
        }

        let session = URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = timeout

        let first = await Self.fetch(session, request)
        guard measureWarm, case .ok(_, let status) = first else { return first }
        request.httpMethod = "HEAD"
        if case .ok(let warm, _) = await Self.fetch(session, request) {
            return .ok(ms: warm, status: status)
        }
        return first
    }

    private static func fetch(_ session: URLSession, _ request: URLRequest) async -> Outcome {
        let started = Date()
        return await withCheckedContinuation { (cont: CheckedContinuation<Outcome, Never>) in
            let task = session.dataTask(with: request) { _, response, error in
                if let http = response as? HTTPURLResponse {
                    let ms = Int(Date().timeIntervalSince(started) * 1000)
                    cont.resume(returning: .ok(ms: ms, status: http.statusCode))
                } else {
                    cont.resume(returning: .failed(SiteTester.message(for: error)))
                }
            }
            task.resume()
        }
    }

    /// Engelli testi için en çok `limit` alan adı seçer: "dis.gd" atlanır, her gruptan
    /// birer (grubun ilk alan adı), sonra liste sırasıyla doldurulur.
    public static func blockedSample(from domains: [String], limit: Int = 6) -> [String] {
        guard limit > 0 else { return [] }
        var seen = Set<String>()
        let candidates = domains.filter { $0 != "dis.gd" && seen.insert($0).inserted }
        var picked: [String] = []
        for group in SiteGrouping.group(candidates) {
            if picked.count >= limit { break }
            if let first = group.domains.first { picked.append(first) }
        }
        for d in candidates {
            if picked.count >= limit { break }
            if !picked.contains(d) { picked.append(d) }
        }
        return picked
    }

    // MARK: - İç yardımcılar

    static func message(for error: Error?) -> String {
        guard let error = error else { return "Bilinmeyen hata" }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return "Zaman aşımı"
            case .networkConnectionLost, .cannotConnectToHost:
                return "Bağlantı kesildi"
            case .cannotFindHost, .dnsLookupFailed:
                return "Bulunamadı"
            default:
                return urlError.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)   // yönlendirmeyi izleme; 3xx de başarı sayılır
        }
    }
}

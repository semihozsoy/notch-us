import Foundation
import SwiftUI

struct LimitWindow: Identifiable {
    let id: String
    let title: String
    let percent: Double
    let resetsAt: Date?
}

@MainActor
final class UsageStore: ObservableObject {
    static let shared = UsageStore()

    @Published var session: LimitWindow?
    @Published var weekly: LimitWindow?
    @Published var extraLimits: [LimitWindow] = []
    @Published var plan: String?
    @Published var error: String?
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var local = LocalStats()
    @Published var now = Date()

    private var pollTimer: Timer?
    private var clockTimer: Timer?
    private let pollInterval: TimeInterval = 120
    /// Set after a 429; polls before this date skip the API so the limit can clear.
    private var backoffUntil: Date?
    private var backoff: TimeInterval = 0

    private init() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
            Task { @MainActor in await UsageStore.shared.refresh() }
        }
        clockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in UsageStore.shared.now = Date() }
        }
        Task { await refresh() }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false; now = Date() }

        async let stats = Task.detached(priority: .utility) { LocalStats.load() }.value
        if let until = backoffUntil, until > Date() {
            local = await stats
            return
        }
        do {
            let result = try await Task.detached { try UsageAPI.fetch() }.value
            session = result.session
            weekly = result.weekly
            extraLimits = result.extra
            plan = result.plan
            error = nil
            lastUpdated = Date()
            backoffUntil = nil
            backoff = 0
        } catch UsageError.rateLimited(let retryAfter) {
            // Back off exponentially (2m, 4m, 8m… up to 30m) unless the server says how long to wait.
            backoff = min(max(backoff * 2, pollInterval), 1800)
            let wait = retryAfter ?? backoff
            backoffUntil = Date().addingTimeInterval(wait)
            self.error = L10n.rateLimited(Fmt.countdown(to: backoffUntil, now: Date()))
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        local = await stats
    }
}

// MARK: - API

enum UsageError: LocalizedError {
    case noCredentials
    case tokenExpired
    case http(Int)
    case rateLimited(retryAfter: TimeInterval?)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .noCredentials: return L10n.noCredentials
        case .tokenExpired: return L10n.tokenExpired
        case .http(let code): return L10n.httpError(code)
        case .rateLimited: return L10n.httpError(429)
        case .badResponse: return L10n.badResponse
        }
    }
}

struct UsageResult {
    var session: LimitWindow?
    var weekly: LimitWindow?
    var extra: [LimitWindow]
    var plan: String?
}

enum UsageAPI {
    struct Credentials {
        let accessToken: String
        let expiresAt: Date?
        let plan: String?
    }

    /// Claude Code stores its OAuth credentials in the login keychain. Going through
    /// /usr/bin/security avoids a keychain prompt, since that tool is already trusted for the item.
    static func readCredentials() -> Credentials? {
        var data: Data?
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        if (try? p.run()) != nil {
            let d = out.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            if p.terminationStatus == 0 { data = d }
        }
        if data == nil {
            let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/.credentials.json")
            data = try? Data(contentsOf: file)
        }
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else { return nil }
        let expires = (oauth["expiresAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
        return Credentials(accessToken: token, expiresAt: expires, plan: oauth["subscriptionType"] as? String)
    }

    static func fetch() throws -> UsageResult {
        guard let creds = readCredentials() else { throw UsageError.noCredentials }
        if let exp = creds.expiresAt, exp < Date() { throw UsageError.tokenExpired }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 20

        let (data, response) = try syncData(req)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            let retryAfter = (http.value(forHTTPHeaderField: "Retry-After")).flatMap(TimeInterval.init)
            throw UsageError.rateLimited(retryAfter: retryAfter)
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw http.statusCode == 401 ? UsageError.tokenExpired : UsageError.http(http.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.badResponse
        }

        func window(_ key: String, _ title: String) -> LimitWindow? {
            guard let w = json[key] as? [String: Any],
                  let util = (w["utilization"] as? NSNumber)?.doubleValue else { return nil }
            return LimitWindow(id: key, title: title, percent: util, resetsAt: parseDate(w["resets_at"] as? String))
        }

        let extra = [
            window("seven_day_opus", L10n.weeklyOpus),
            window("seven_day_sonnet", L10n.weeklySonnet),
        ].compactMap { $0 }

        return UsageResult(
            session: window("five_hour", L10n.session),
            weekly: window("seven_day", L10n.weekly),
            extra: extra,
            plan: creds.plan
        )
    }

    private static func syncData(_ req: URLRequest) throws -> (Data, URLResponse) {
        let sem = DispatchSemaphore(value: 0)
        var result: Result<(Data, URLResponse), Error> = .failure(UsageError.badResponse)
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err { result = .failure(err) }
            else if let data, let resp { result = .success((data, resp)) }
            sem.signal()
        }.resume()
        sem.wait()
        return try result.get()
    }

    /// The API returns microsecond precision, which ISO8601DateFormatter does not parse reliably.
    static func parseDate(_ s: String?) -> Date? {
        guard var s else { return nil }
        if let r = s.range(of: #"\.\d+"#, options: .regularExpression) { s.removeSubrange(r) }
        return ISO8601DateFormatter().date(from: s)
    }
}

// MARK: - Formatting

enum Fmt {
    static func countdown(to date: Date?, now: Date) -> String {
        guard let date else { return "" }
        let secs = Int(date.timeIntervalSince(now))
        if secs <= 0 { return L10n.resettingNow }
        let d = secs / 86400, h = (secs % 86400) / 3600, m = (secs % 3600) / 60
        if d > 0 { return L10n.days(d, hours: h) }
        if h > 0 { return L10n.hours(h, minutes: m) }
        return L10n.minutes(max(m, 1))
    }

    static func resetTime(_ date: Date?) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.locale = L10n.locale
        f.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "d MMM EEE HH:mm"
        return f.string(from: date)
    }

    static func tokens(_ n: Int) -> String {
        switch n {
        case 1_000_000...: return String(format: "%.1fM", Double(n) / 1_000_000)
        case 1_000...: return String(format: "%.1fK", Double(n) / 1_000)
        default: return "\(n)"
        }
    }

    static func color(for percent: Double) -> Color {
        switch percent {
        case ..<50: return .green
        case ..<80: return .orange
        default: return .red
        }
    }
}

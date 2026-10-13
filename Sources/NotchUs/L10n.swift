import Foundation

/// UI strings in English (default) and Turkish, picked from the system's preferred language.
enum L10n {
    static let isTurkish = Locale.preferredLanguages.first?.hasPrefix("tr") ?? false
    static let locale = Locale(identifier: isTurkish ? "tr_TR" : "en_US")

    private static func t(_ en: String, _ tr: String) -> String { isTurkish ? tr : en }

    // Limits
    static var session: String { t("Session (5 hours)", "Oturum (5 saat)") }
    static var weekly: String { t("Weekly", "Haftalık") }
    static var weeklyOpus: String { t("Weekly · Opus", "Haftalık · Opus") }
    static var weeklySonnet: String { t("Weekly · Sonnet", "Haftalık · Sonnet") }
    static var weekShort: String { t("7d", "7g") }
    static func percent(_ n: Int) -> String { isTurkish ? "%\(n)" : "\(n)%" }
    static func resetsIn(_ countdown: String, at time: String) -> String {
        t("Resets in \(countdown) · \(time)", "\(countdown) sonra sıfırlanır · \(time)")
    }

    // Countdown
    static var resettingNow: String { t("resetting now", "şimdi sıfırlanıyor") }
    static func days(_ d: Int, hours h: Int) -> String { t("\(d)d \(h)h", "\(d)g \(h)sa") }
    static func hours(_ h: Int, minutes m: Int) -> String { t("\(h)h \(m)m", "\(h)sa \(m)dk") }
    static func minutes(_ m: Int) -> String { t("\(m)m", "\(m)dk") }

    // Local stats
    static var localLogs: String { t("Local logs", "Yerel kayıtlar") }
    static var today: String { t("Today", "Bugün") }
    static var todayOutput: String { t("Today output", "Bugün çıktı") }
    static var last5Hours: String { t("Last 5 hours", "Son 5 saat") }
    static func tokens(_ n: String) -> String { "\(n) token\(isTurkish ? "" : "s")" }
    static func tokensAndReplies(_ n: String, _ replies: Int) -> String {
        t("\(n) tokens · \(replies) replies", "\(n) token · \(replies) yanıt")
    }
    static func notchToday(_ n: String, _ replies: Int) -> String {
        t("Today \(n) tokens · \(replies) replies", "Bugün \(n) token · \(replies) yanıt")
    }
    static func notchLast5h(_ n: String) -> String { t("Last 5h \(n)", "Son 5sa \(n)") }

    // Menu
    static var title: String { t("Claude Code Usage", "Claude Code Kullanımı") }
    static var showInNotch: String { t("Show in notch", "Çentikte göster") }
    static var leftSide: String { t("Left side", "Sol taraf") }
    static var rightSide: String { t("Right side", "Sağ taraf") }
    static var launchAtLogin: String { t("Launch at login", "Girişte başlat") }
    static func launchAtLoginFailed(_ reason: String) -> String {
        t("Couldn't set launch at login: \(reason)", "Girişte başlatma ayarlanamadı: \(reason)")
    }
    static func updated(_ time: String) -> String { t("Updated \(time)", "Güncellendi \(time)") }
    static var quit: String { t("Quit", "Çık") }

    // Updates
    static func updateAvailable(_ latest: String, installed: String) -> String {
        t("v\(latest) available (installed: v\(installed))", "v\(latest) mevcut (yüklü: v\(installed))")
    }
    static var update: String { t("Update", "Güncelle") }
    static func updateFailed(_ reason: String) -> String { t("Update failed: \(reason)", "Güncelleme başarısız: \(reason)") }

    // Errors
    static var noCredentials: String {
        t("No Claude Code login found. Sign in with `claude` in Terminal.",
          "Claude Code girişi bulunamadı. Terminalde `claude` ile giriş yap.")
    }
    static var tokenExpired: String {
        t("Your session token has expired. Running Claude Code once will refresh it.",
          "Oturum anahtarının süresi dolmuş. Claude Code'u bir kez çalıştırınca yenilenir.")
    }
    static func httpError(_ code: Int) -> String { t("Server error (HTTP \(code)).", "Sunucu hatası (HTTP \(code)).") }
    static func rateLimited(_ wait: String) -> String {
        t("Rate limited by the server. Retrying in \(wait).",
          "Sunucu istek sınırına takıldı. \(wait) sonra tekrar denenecek.")
    }
    static var badResponse: String { t("Unexpected response.", "Beklenmeyen yanıt.") }
}

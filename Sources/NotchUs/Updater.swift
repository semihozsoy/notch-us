import AppKit
import Foundation

/// Checks GitHub for a newer release and can install it in place, like install.sh does.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    @Published var latestVersion: String?
    @Published var isUpdating = false
    @Published var error: String?

    /// nil when running outside an app bundle (e.g. `swift run`), which disables update checks.
    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

    var updateAvailable: Bool {
        guard let latestVersion, let currentVersion else { return false }
        return Self.isNewer(latestVersion, than: currentVersion)
    }

    private static let repo = "semihozsoy/notch-us"
    private var timer: Timer?

    private init() {
        guard currentVersion != nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { _ in
            Task { @MainActor in await Updater.shared.check() }
        }
        Task { await check() }
    }

    func check() async {
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("NotchUs", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else { return }
        latestVersion = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    /// Downloads the latest zip, swaps it in for the running bundle and relaunches.
    func install() async {
        guard !isUpdating else { return }
        isUpdating = true
        error = nil
        do {
            let app = Bundle.main.bundleURL
            let url = URL(string: "https://github.com/\(Self.repo)/releases/latest/download/NotchUs.zip")!
            try await Task.detached { try Self.replace(app, withZipAt: url) }.value
            relaunch(app)
        } catch {
            self.error = L10n.updateFailed(error.localizedDescription)
            isUpdating = false
        }
    }

    nonisolated private static func replace(_ app: URL, withZipAt url: URL) throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        let zip = tmp.appendingPathComponent("NotchUs.zip")
        try Data(contentsOf: url).write(to: zip)
        try run("/usr/bin/ditto", "-x", "-k", zip.path, tmp.path)

        let fresh = tmp.appendingPathComponent("NotchUs.app")
        guard fm.fileExists(atPath: fresh.path) else { throw CocoaError(.fileReadCorruptFile) }
        try? run("/usr/bin/xattr", "-dr", "com.apple.quarantine", fresh.path)
        // A running app's files can be replaced; the process keeps its mapped copy until it quits.
        _ = try fm.replaceItemAt(app, withItemAt: fresh)
    }

    nonisolated private static func run(_ tool: String, _ args: String...) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 { throw CocoaError(.fileWriteUnknown) }
    }

    /// Opens the new copy once this process has exited.
    private func relaunch(_ app: URL) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; open \"$0\"", app.path]
        try? p.run()
        NSApp.terminate(nil)
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}

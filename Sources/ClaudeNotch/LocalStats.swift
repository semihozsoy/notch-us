import Foundation

/// Token counts read from Claude Code's local transcripts (~/.claude/projects/**/*.jsonl).
struct LocalStats {
    var todayTokens = 0
    var todayOutput = 0
    var todayMessages = 0
    var last5hTokens = 0
    var last5hMessages = 0
    var todayByModel: [(model: String, tokens: Int)] = []

    static func load() -> LocalStats {
        let fm = FileManager.default
        let root = fm.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        let cutoff = min(startOfDay, fiveHoursAgo)

        guard let it = fm.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey],
                                     options: [.skipsHiddenFiles]) else { return LocalStats() }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var stats = LocalStats()
        var seen = Set<String>()
        var byModel: [String: Int] = [:]

        for case let url as URL in it where url.pathExtension == "jsonl" {
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            guard let mod, mod >= cutoff,
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }

            for line in text.split(separator: "\n") where line.contains("\"usage\"") {
                guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                      obj["type"] as? String == "assistant",
                      let msg = obj["message"] as? [String: Any],
                      let usage = msg["usage"] as? [String: Any],
                      let ts = (obj["timestamp"] as? String).flatMap(iso.date(from:)),
                      ts >= cutoff else { continue }

                let model = msg["model"] as? String ?? "?"
                if model == "<synthetic>" { continue }

                // Streaming writes the same message several times; count it once.
                let key = "\(msg["id"] as? String ?? "")|\(obj["requestId"] as? String ?? UUID().uuidString)"
                guard seen.insert(key).inserted else { continue }

                func n(_ k: String) -> Int { (usage[k] as? NSNumber)?.intValue ?? 0 }
                let output = n("output_tokens")
                let total = n("input_tokens") + output + n("cache_creation_input_tokens") + n("cache_read_input_tokens")

                if ts >= startOfDay {
                    stats.todayTokens += total
                    stats.todayOutput += output
                    stats.todayMessages += 1
                    byModel[model, default: 0] += total
                }
                if ts >= fiveHoursAgo {
                    stats.last5hTokens += total
                    stats.last5hMessages += 1
                }
            }
        }

        stats.todayByModel = byModel.sorted { $0.value > $1.value }.map { (model: $0.key, tokens: $0.value) }
        return stats
    }
}

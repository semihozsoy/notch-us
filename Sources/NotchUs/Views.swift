import SwiftUI
import ServiceManagement

struct LimitRow: View {
    let limit: LimitWindow
    let now: Date
    var dark = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(limit.title).font(.system(size: 12, weight: .medium))
                Spacer()
                Text("%\(Int(limit.percent.rounded()))")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Fmt.color(for: limit.percent))
            }
            ProgressBar(value: limit.percent / 100, color: Fmt.color(for: limit.percent), dark: dark)
            if limit.resetsAt != nil {
                Text("\(Fmt.countdown(to: limit.resetsAt, now: now)) sonra sıfırlanır · \(Fmt.resetTime(limit.resetsAt))")
                    .font(.system(size: 10))
                    .foregroundStyle(dark ? Color.white.opacity(0.55) : .secondary)
            }
        }
        .foregroundStyle(dark ? Color.white : .primary)
    }
}

struct ProgressBar: View {
    let value: Double
    let color: Color
    var dark = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(dark ? Color.white.opacity(0.15) : Color.primary.opacity(0.1))
                Capsule().fill(color).frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 6)
    }
}

struct RingView: View {
    let value: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.2), lineWidth: 2.5)
            Circle().trim(from: 0, to: min(max(value, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Menu bar popover

struct MenuContent: View {
    @ObservedObject var store: UsageStore
    @AppStorage("showNotch") private var showNotch = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkle").foregroundStyle(.orange)
                Text("Claude Code Kullanımı").font(.headline)
                Spacer()
                if let plan = store.plan {
                    Text(plan.capitalized)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.2)))
                }
            }

            if let error = store.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let s = store.session { LimitRow(limit: s, now: store.now) }
            if let w = store.weekly { LimitRow(limit: w, now: store.now) }
            ForEach(store.extraLimits) { LimitRow(limit: $0, now: store.now) }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Yerel kayıtlar").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                statLine("Bugün", "\(Fmt.tokens(store.local.todayTokens)) token · \(store.local.todayMessages) yanıt")
                statLine("Bugün çıktı", "\(Fmt.tokens(store.local.todayOutput)) token")
                statLine("Son 5 saat", "\(Fmt.tokens(store.local.last5hTokens)) token · \(store.local.last5hMessages) yanıt")
                ForEach(store.local.todayByModel.prefix(3), id: \.model) { m in
                    statLine("  " + m.model.replacingOccurrences(of: "claude-", with: ""), Fmt.tokens(m.tokens))
                }
            }

            Divider()

            Toggle("Çentikte göster", isOn: $showNotch)
            Toggle("Girişte başlat", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        store.error = "Girişte başlatma ayarlanamadı: \(error.localizedDescription)"
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            HStack {
                if let t = store.lastUpdated {
                    Text("Güncellendi \(Fmt.resetTime(t))").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await store.refresh() }
                } label: {
                    if store.isLoading { ProgressView().controlSize(.small) } else { Image(systemName: "arrow.clockwise") }
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("r")
                Button("Çık") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .keyboardShortcut("q")
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(14)
        .frame(width: 300)
    }

    private func statLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 11))
            Spacer()
            Text(value).font(.system(size: 11).monospacedDigit()).foregroundStyle(.secondary)
        }
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: store.error != nil && store.session == nil ? "exclamationmark.circle" : "sparkle")
            if let s = store.session {
                let w = store.weekly.map { " · \(Int($0.percent.rounded()))%" } ?? ""
                Text("\(Int(s.percent.rounded()))%\(w)").monospacedDigit()
            }
        }
    }
}

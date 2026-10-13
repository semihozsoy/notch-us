import AppKit
import SwiftUI

@MainActor
final class NotchModel: ObservableObject {
    @Published var expanded = false
    @Published var notchWidth: CGFloat = 180
    @Published var notchHeight: CGFloat = 32

    let wingWidth: CGFloat = 66
    var compactWidth: CGFloat { notchWidth + wingWidth * 2 }
    var expandedWidth: CGFloat { max(compactWidth, 380) }
    var expandedHeight: CGFloat { notchHeight + 150 }
}

/// A borderless panel that sits over the camera notch. Collapsed it shows two "wings"
/// on either side of the notch; hovering over it drops down a detail panel.
@MainActor
final class NotchController {
    private var panel: NSPanel?
    private let model = NotchModel()
    private var notchMidX: CGFloat = 0
    private var screenTop: CGFloat = 0
    private var monitors: [Any] = []
    private var collapseTimer: Timer?

    func show() {
        guard panel == nil else { return }
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar + 1
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.isMovable = false
        panel.contentView = NSHostingView(rootView: NotchView(store: .shared, model: model))
        self.panel = panel

        layout()
        panel.orderFrontRegardless()

        if let m = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] _ in
            Task { @MainActor in self?.mouseMoved() }
        }) { monitors.append(m) }

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.layout() }
        }
    }

    func hide() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        collapseTimer?.invalidate()
        collapseTimer = nil
        NotificationCenter.default.removeObserver(self)
        panel?.orderOut(nil)
        panel = nil
        model.expanded = false
    }

    private func layout() {
        guard let panel else { return }
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.frame

        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, screen.safeAreaInsets.top > 0 {
            model.notchWidth = right.minX - left.maxX
            model.notchHeight = screen.safeAreaInsets.top
            notchMidX = (left.maxX + right.minX) / 2
        } else {
            // No notch: draw a small pill in the middle of the menu bar.
            model.notchWidth = 0
            model.notchHeight = NSStatusBar.system.thickness
            notchMidX = frame.midX
        }
        screenTop = frame.maxY

        let w = model.expandedWidth, h = model.expandedHeight
        panel.setFrame(NSRect(x: notchMidX - w / 2, y: screenTop - h, width: w, height: h), display: true)
    }

    private var compactRect: NSRect {
        NSRect(x: notchMidX - model.compactWidth / 2, y: screenTop - model.notchHeight,
               width: model.compactWidth, height: model.notchHeight)
    }

    private var expandedRect: NSRect {
        NSRect(x: notchMidX - model.expandedWidth / 2, y: screenTop - model.expandedHeight,
               width: model.expandedWidth, height: model.expandedHeight).insetBy(dx: -6, dy: -6)
    }

    private func mouseMoved() {
        guard !model.expanded, compactRect.contains(NSEvent.mouseLocation) else { return }
        setExpanded(true)
    }

    private func setExpanded(_ on: Bool) {
        model.expanded = on
        panel?.ignoresMouseEvents = !on
        collapseTimer?.invalidate()
        collapseTimer = nil
        if on {
            // Mouse events over our own panel don't reach the global monitor, so poll while open.
            collapseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, !self.expandedRect.contains(NSEvent.mouseLocation) else { return }
                    self.setExpanded(false)
                }
            }
        }
    }
}

struct NotchView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var model: NotchModel

    private var width: CGFloat { model.expanded ? model.expandedWidth : model.compactWidth }
    private var height: CGFloat { model.expanded ? model.expandedHeight : model.notchHeight }
    private var radius: CGFloat { model.expanded ? 22 : 10 }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)
                    .fill(Color.black)

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        leftWing.frame(width: model.wingWidth)
                        Color.clear.frame(width: model.notchWidth)
                        rightWing.frame(width: model.wingWidth)
                    }
                    .frame(height: model.notchHeight)

                    if model.expanded {
                        expandedContent
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .frame(width: width, height: height)
            .clipped()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: model.expanded)
    }

    private var leftWing: some View {
        HStack(spacing: 5) {
            if let s = store.session {
                RingView(value: s.percent / 100, color: Fmt.color(for: s.percent)).frame(width: 13, height: 13)
                Text("\(Int(s.percent.rounded()))%")
            } else {
                Image(systemName: store.error != nil ? "exclamationmark.circle" : "sparkle")
                    .foregroundStyle(.orange)
            }
        }
        .font(.system(size: 11, weight: .semibold).monospacedDigit())
        .foregroundStyle(.white)
    }

    private var rightWing: some View {
        HStack(spacing: 3) {
            if let w = store.weekly {
                Text("\(Int(w.percent.rounded()))%")
                    .foregroundStyle(.white)
                Text(L10n.weekShort).foregroundStyle(.white.opacity(0.5))
            }
        }
        .font(.system(size: 11, weight: .semibold).monospacedDigit())
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = store.error, store.session == nil {
                Text(error).font(.system(size: 11)).foregroundStyle(.orange)
            }
            if let s = store.session { LimitRow(limit: s, now: store.now, dark: true) }
            if let w = store.weekly { LimitRow(limit: w, now: store.now, dark: true) }
            HStack {
                Text(L10n.notchToday(Fmt.tokens(store.local.todayTokens), store.local.todayMessages))
                Spacer()
                Text(L10n.notchLast5h(Fmt.tokens(store.local.last5hTokens)))
            }
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.white.opacity(0.55))
        }
    }
}

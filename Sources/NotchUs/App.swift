import SwiftUI
import Combine

@main
struct NotchUsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var store = UsageStore.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notch = NotchController()
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["showNotch": true])
        cancellable = UserDefaults.standard.publisher(for: \.showNotch)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] on in
                if on { self?.notch.show() } else { self?.notch.hide() }
            }
    }
}

extension UserDefaults {
    @objc dynamic var showNotch: Bool { bool(forKey: "showNotch") }
}

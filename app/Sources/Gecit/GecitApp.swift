import AppKit
import SwiftUI

/// Geçit: menü çubuğunda yaşayan, istenince ana penceresini açan uygulama.
@main
struct GecitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuPanel()
                .environmentObject(model)
        } label: {
            Image(nsImage: MenuBarIcon.image(open: model.status.isPassing))
                .accessibilityLabel(model.status.isPassing ? "Geçit açık" : "Geçit kapalı")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Ana pencereyi AppKit ile yönetir: açılışta ne zaman gösterileceğine biz karar veririz
/// (girişte sessizce menü çubuğunda başlar, elle açılınca pencere gelir).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) weak var shared: AppDelegate?
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        let model = AppModel.shared
        model.start()

        let args = ProcessInfo.processInfo.arguments
        // Mac yeni açıldıysa bu büyük ihtimalle girişte otomatik başlatmadır: pencere açma.
        let looksLikeLogin = ProcessInfo.processInfo.systemUptime < 240
        if args.contains("--ilk") || !looksLikeLogin || !model.paths.isInstalled {
            showMainWindow()
        }
        // Kurulum paketinden ilk açılış: bu ağa uygun yöntemi kendisi seçsin.
        if args.contains("--ilk") {
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await model.refresh()
                model.autoTune()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func showMainWindow() {
        if window == nil {
            let host = NSHostingController(rootView: MainView().environmentObject(AppModel.shared))
            host.sizingOptions = []
            let w = NSWindow(contentViewController: host)
            w.title = "Geçit"
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.isMovableByWindowBackground = true
            w.setContentSize(NSSize(width: 960, height: 800))
            w.minSize = NSSize(width: 780, height: 560)
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            w.setFrameAutosaveName("GecitAnaPencere")
            window = w
        }
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        AppModel.shared.windowVisible = true
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppModel.shared.windowVisible = false
    }
}

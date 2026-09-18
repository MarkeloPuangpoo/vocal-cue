import SwiftUI

// MARK: - VocalCue App

@main
struct VocalCueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var engine = AudioEngineManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 650)

        // Menu Bar integration — shares the same engine instance
        MenuBarExtra {
            MenuBarView()
                .environmentObject(engine)
        } label: {
            Image(systemName: "headphones")
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.isMovableByWindowBackground = true
            window.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // Keep running when window is closed (menu bar app)
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @EnvironmentObject var engine: AudioEngineManager

    var body: some View {
        VStack(spacing: 4) {
            Button(engine.isRunning ? "⏹ Stop Monitor" : "▶ Start Monitor") {
                engine.toggle()
            }
            .keyboardShortcut("m", modifiers: .command)

            Divider()

            HStack {
                Text("Status:")
                Spacer()
                Text(engine.isRunning ? "🟢 Live" : "🔴 Off")
            }
            .font(.system(size: 12))
            .padding(.horizontal, 8)

            Divider()

            Button("Quit VocalCue") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(4)
    }
}

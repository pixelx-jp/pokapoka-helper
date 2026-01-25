import Foundation
import AppKit
import ScreenCaptureKit

/// Menu bar app for capturing system audio
class CueCompanionApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var audioCaptureManager: AudioCaptureManager!
    private var webSocketServer: AudioWebSocketServer!
    private var isCapturing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar only app)
        NSApp.setActivationPolicy(.accessory)

        // Register URL Scheme handler
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        // Initialize components
        audioCaptureManager = AudioCaptureManager()
        webSocketServer = AudioWebSocketServer(port: 9999)

        // Setup menu bar
        setupMenuBar()

        // Listen for system wake notifications to restart capture
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // Start capture (will auto-detect best method)
        Task {
            await startServices()
        }

        print("CueCompanion started")
    }

    /// Handle system wake - restart audio capture
    @objc private func handleSystemWake(_ notification: Notification) {
        print("System woke from sleep, restarting audio capture...")
        Task {
            // Stop and restart capture to reinitialize ScreenCaptureKit
            await stopCapture()
            try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5s
            await startCapture()
            updateMenuStatus("Running (port 9999)")
        }
    }

    /// Handle URL Scheme: cuecompanion://start
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        print("Received URL: \(url)")

        // Handle different commands
        switch url.host {
        case "start":
            // Already running, just bring to front if needed
            Task {
                if !isCapturing {
                    await startCapture()
                    updateMenuStatus("Running (port 9999)")
                }
            }
        case "stop":
            Task {
                await stopCapture()
                updateMenuStatus("Stopped")
            }
        default:
            print("Unknown URL command: \(url.host ?? "nil")")
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Cue Companion")
            button.toolTip = "Cue Companion - System Audio Capture"
        }

        let menu = NSMenu()

        let statusMenuItem = NSMenuItem(title: "Status: Starting...", action: nil, keyEquivalent: "")
        statusMenuItem.tag = 100
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(title: "Start Capture", action: #selector(toggleCapture), keyEquivalent: "s")
        toggleItem.tag = 101
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func startServices() async {
        do {
            // Start WebSocket server
            try await webSocketServer.start()

            // Start audio capture (auto-detects best method)
            await startCapture()

            updateMenuStatus("Running (port 9999)")
        } catch {
            print("Startup error: \(error)")
            updateMenuStatus("Error: \(error.localizedDescription)")

            // Show alert for permission issue (only relevant for ScreenCaptureKit fallback)
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = "Audio Capture Error"
                alert.informativeText = "CueCompanion failed to start audio capture.\n\nError: \(error.localizedDescription)\n\nIf using ScreenCaptureKit, please grant Screen Recording permission in System Settings > Privacy & Security > Screen Recording."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")

                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                }
            }
        }
    }

    private func startCapture() async {
        do {
            try await audioCaptureManager.startCapture { [weak self] audioData in
                // Send audio data to all connected WebSocket clients
                self?.webSocketServer.broadcast(audioData: audioData)
            }
            isCapturing = true
            await webSocketServer.setCapturing(true)
            updateToggleMenu(capturing: true)
        } catch {
            print("Failed to start capture: \(error)")
            updateMenuStatus("Error: \(error.localizedDescription)")
        }
    }

    private func stopCapture() async {
        await audioCaptureManager.stopCapture()
        isCapturing = false
        await webSocketServer.setCapturing(false)
        updateToggleMenu(capturing: false)
    }

    @objc private func toggleCapture() {
        Task {
            if isCapturing {
                await stopCapture()
                updateMenuStatus("Stopped")
            } else {
                await startCapture()
                updateMenuStatus("Running (port 9999)")
            }
        }
    }

    private func updateMenuStatus(_ status: String) {
        DispatchQueue.main.async { [weak self] in
            if let menuItem = self?.statusItem.menu?.item(withTag: 100) {
                menuItem.title = "Status: \(status)"
            }
        }
    }

    private func updateToggleMenu(capturing: Bool) {
        DispatchQueue.main.async { [weak self] in
            if let menuItem = self?.statusItem.menu?.item(withTag: 101) {
                menuItem.title = capturing ? "Stop Capture" : "Start Capture"
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Remove observer
        NSWorkspace.shared.notificationCenter.removeObserver(self)

        Task {
            await stopCapture()
            await webSocketServer.stop()
        }
    }
}

// Entry point
let app = NSApplication.shared
let delegate = CueCompanionApp()
app.delegate = delegate
app.run()

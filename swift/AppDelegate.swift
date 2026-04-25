// AppDelegate.swift
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var pauseMenuItem: NSMenuItem!
    private var statusUpdateTimer: Timer?
    private var preferencesWindowController: NSWindowController?

    private var supportDir: String { NSString(string: "~/Library/Application Support/VAM-RPC").expandingTildeInPath }
    private var dataDir: String { "\(supportDir)/data" }
    private var userConfigPath: String { "\(dataDir)/config.json" }
    private var statusFilePath: String { "\(supportDir)/status.txt" }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        ensureConfigFilesAreInPlace()
        Agent.shared.start()
        setupMenu()
        startStatusTimer()
    }
    
    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "VAM-RPC")
        let menu = NSMenu()
        statusMenuItem = NSMenuItem(title: "Status: Initializing...", action: nil, keyEquivalent: "")
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        pauseMenuItem = NSMenuItem(title: "Pause RPC", action: #selector(toggleServicePause), keyEquivalent: "")
        menu.addItem(pauseMenuItem)
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(.separator())
        let quitMenuItem = NSMenuItem(title: "Quit VAM-RPC", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitMenuItem)
        statusItem.menu = menu
    }
    
    private func ensureConfigFilesAreInPlace() {
        do {
            try FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: userConfigPath) {
                guard let bundledConfigPath = Bundle.main.path(forResource: "config", ofType: "json", inDirectory: "data") else {
                    showAlert(title: "Fatal Error", text: "Default config.json missing from app bundle.")
                    NSApp.terminate(nil)
                    return
                }
                try FileManager.default.copyItem(atPath: bundledConfigPath, toPath: userConfigPath)
            }
        } catch {
            showAlert(title: "Fatal Error", text: "Could not set up configuration files: \(error.localizedDescription)")
            NSApp.terminate(nil)
        }
    }

    // Service running logic handled natively by Agent now.
    
    private func isServiceActive() -> Bool {
        return FileManager.default.fileExists(atPath: statusFilePath)
    }

    @objc func toggleServicePause() {
        _ = Agent.shared.togglePause()
        updateStatus()
    }
    
    @objc func quitApp() {
        Agent.shared.stop()
        NSApplication.shared.terminate(self)
    }
    
    private func startStatusTimer() {
        statusUpdateTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(updateStatus), userInfo: nil, repeats: true)
        statusUpdateTimer?.fire()
    }
    
    @objc private func updateStatus() {
        if isServiceActive() {
            pauseMenuItem.title = "Pause RPC"
            do {
                let newStatus = try String(contentsOfFile: statusFilePath, encoding: .utf8)
                statusMenuItem.title = "Status: \(newStatus.trimmingCharacters(in: .whitespacesAndNewlines))"
            } catch { statusMenuItem.title = "Status: Service running..." }
        } else {
            pauseMenuItem.title = "Resume RPC"
            statusMenuItem.title = "Status: RPC Paused"
        }
    }
    
    private func runShellCommand(_ command: String, arguments: [String]) -> String? { let task = Process(); task.executableURL = URL(fileURLWithPath: command); task.arguments = arguments; let pipe = Pipe(); task.standardOutput = pipe; try? task.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); return String(data: data, encoding: .utf8) }
    private func showAlert(title: String, text: String) { let alert = NSAlert(); alert.messageText = title; alert.informativeText = text; alert.runModal(); }
    
    @objc func showPreferences() {
        if preferencesWindowController == nil {
            let preferencesVC = PreferencesViewController()
            let window = NSWindow(contentViewController: preferencesVC)
            
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            
            window.title = "VAM-RPC Settings" 
            window.isReleasedWhenClosed = false
            window.center()
            preferencesWindowController = NSWindowController(window: window)
        }
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {

    // --- UI Properties ---
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var pauseMenuItem: NSMenuItem!
    private var statusUpdateTimer: Timer?
    
    // Window Controllers
    private var modernWindowController: NSWindowController?
    private var legacyWindowController: NSWindowController?

    // --- Configuration Paths ---
    private let plistName = "com.vam-rpc.agent.plist"
    private var plistPath: String { NSString(string: "~/Library/LaunchAgents/\(plistName)").expandingTildeInPath }
    private var supportDir: String { NSString(string: "~/Library/Application Support/VAM-RPC").expandingTildeInPath }
    private var dataDir: String { "\(supportDir)/data" }
    private var userConfigPath: String { "\(dataDir)/config.json" }
    private var agentDestPath: String { "\(supportDir)/agent.ts" }
    private var statusFilePath: String { "\(supportDir)/status.txt" }
    
    // --- App Lifecycle ---
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Force copy agent.ts to ensure updates apply
        if let agentSourcePath = Bundle.main.path(forResource: "agent", ofType: "ts") {
            try? FileManager.default.removeItem(atPath: agentDestPath)
            try? FileManager.default.copyItem(atPath: agentSourcePath, toPath: agentDestPath)
        }
        
        ensureConfigFilesAreInPlace()
        ensureServiceIsRunning()
        setupMenu()
        startStatusTimer()
    }
    
    // --- Menu Setup ---
    
    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "VAM-RPC")
        
        let menu = NSMenu()
        
        // Status Line
        statusMenuItem = NSMenuItem(title: "Status: Initializing...", action: nil, keyEquivalent: "")
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        
        // Main Action
        menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(showModernSettings), keyEquivalent: ","))
        
        // Controls
        pauseMenuItem = NSMenuItem(title: "Pause RPC", action: #selector(toggleServicePause), keyEquivalent: "")
        menu.addItem(pauseMenuItem)
        menu.addItem(.separator())
        
        // Quit
        let quitMenuItem = NSMenuItem(title: "Quit VAM-RPC", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitMenuItem)
        
        statusItem.menu = menu
    }
    
    
    @objc func showModernSettings() {
        if modernWindowController == nil {
            let win = CustomWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1250, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            // Set minimum size
            win.minSize = NSSize(width: 1100, height: 520)
            
            // Configure window appearance
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.isMovableByWindowBackground = true
            
            // Transparency
            win.isOpaque = false
            win.backgroundColor = NSColor.clear
            
            // Create and set content view controller
            let vc = ModernPreferencesViewController()
            win.contentViewController = vc
            
            // CRITICAL: Force layout BEFORE showing
            win.layoutIfNeeded()
            vc.view.layoutSubtreeIfNeeded()
            
            // Position window
            win.center()
            win.title = "VAM-RPC"
            
            modernWindowController = NSWindowController(window: win)
        }
        
        modernWindowController?.showWindow(nil)
        
        if let win = modernWindowController?.window as? CustomWindow {
            DispatchQueue.main.async {
                win.forcePositionTrafficLights()
            }
        }
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func openLegacySettings() {
        if legacyWindowController == nil {
            let vc = PreferencesViewController()
            let win = NSWindow(contentViewController: vc)
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.title = "Legacy Preferences"
            win.center()
            legacyWindowController = NSWindowController(window: win)
        }
        legacyWindowController?.showWindow(nil)
    }
    
    // --- Backend Management (Original Logic) ---
    
    private func ensureConfigFilesAreInPlace() {
        do {
            try FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: userConfigPath) {
                guard let bundledConfigPath = Bundle.main.path(forResource: "config", ofType: "json", inDirectory: "data") else {
                    return
                }
                try? FileManager.default.copyItem(atPath: bundledConfigPath, toPath: userConfigPath)
            }
        } catch {
            print("Config setup error: \(error)")
        }
    }

    private func ensureServiceIsRunning() {
        guard let denoPath = findDenoExecutable() else {
            showAlert(title: "Fatal Error", text: "Deno was not found. Please install it from deno.land and relaunch.")
            return
        }
        
        _ = runShellCommand("/bin/launchctl", arguments: ["unload", plistPath])
        
        do {
            let plistContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>\(plistName)</string>
                <key>ProgramArguments</key>
                <array>
                    <string>\(denoPath)</string>
                    <string>run</string>
                    <string>-A</string>
                    <string>\(agentDestPath)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
                <key>KeepAlive</key>
                <true/>
                <key>StandardOutPath</key>
                <string>\(supportDir)/stdout.log</string>
                <key>StandardErrorPath</key>
                <string>\(supportDir)/stderr.log</string>
            </dict>
            </plist>
            """
            try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
        } catch {
            showAlert(title: "Fatal Error", text: "Could not write service files: \(error.localizedDescription)")
        }
        
        _ = runShellCommand("/bin/launchctl", arguments: ["load", plistPath])
    }
    
    private func isServiceActive() -> Bool {
        return FileManager.default.fileExists(atPath: statusFilePath)
    }

    @objc func toggleServicePause() {
        if isServiceActive() {
            _ = runShellCommand("/bin/launchctl", arguments: ["unload", plistPath])
            try? FileManager.default.removeItem(atPath: statusFilePath)
        } else {
            _ = runShellCommand("/bin/launchctl", arguments: ["load", plistPath])
        }
        updateStatus()
    }
    
    @objc func quitApp() {
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
    
    private func findDenoExecutable() -> String? {
        let paths = ["/opt/homebrew/bin/deno", "/usr/local/bin/deno", "~/.deno/bin/deno"]
        return paths.first { FileManager.default.fileExists(atPath: NSString(string: $0).expandingTildeInPath) }
            .map { NSString(string: $0).expandingTildeInPath }
    }
    
    private func runShellCommand(_ command: String, arguments: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: command)
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
    
    private func showAlert(title: String, text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}

// MARK: - Custom Window with FIXED Traffic Lights

class CustomWindow: NSWindow {
    
    private var hasPositionedButtons = false
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    }
    
    // Public method to force positioning
    func forcePositionTrafficLights() {
        positionTrafficLights()
        hasPositionedButtons = true
    }
    
    // Called after window becomes visible
    override func orderFront(_ sender: Any?) {
        super.orderFront(sender)
        if !hasPositionedButtons {
            DispatchQueue.main.async { [weak self] in
                self?.positionTrafficLights()
                self?.hasPositionedButtons = true
            }
        }
    }
    
    // Called on window resize
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        if hasPositionedButtons {
            positionTrafficLights()
        }
    }
    
    private func positionTrafficLights() {
//positioning
        guard let closeButton = standardWindowButton(.closeButton),
              let miniButton = standardWindowButton(.miniaturizeButton),
              let zoomButton = standardWindowButton(.zoomButton) else {
            return
        }
        
        let titlebarHeight = frame.height - contentLayoutRect.height
        
        let verticalCenter = titlebarHeight / 7 //this one is... top padding.
        let buttonRadius: CGFloat = 6 
        let targetY = verticalCenter - buttonRadius
        
        closeButton.setFrameOrigin(NSPoint(x: 20, y: targetY))
        miniButton.setFrameOrigin(NSPoint(x: 40, y: targetY))
        zoomButton.setFrameOrigin(NSPoint(x: 60, y: targetY))
        
        closeButton.isEnabled = true
        miniButton.isEnabled = true
        zoomButton.isEnabled = true
        closeButton.isHidden = false
        miniButton.isHidden = false
        zoomButton.isHidden = false
    }
}
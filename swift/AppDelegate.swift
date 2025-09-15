// AppDelegate.swift main component
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var pauseMenuItem: NSMenuItem!
    private var statusUpdateTimer: Timer?
    private var preferencesWindowController: NSWindowController?

    private let plistName = "com.vam-rpc.agent.plist"
    private var plistPath: String { NSString(string: "~/Library/LaunchAgents/\(plistName)").expandingTildeInPath }
    private var supportDir: String { NSString(string: "~/Library/Application Support/VAM-RPC").expandingTildeInPath }
    private var agentDestPath: String { "\(supportDir)/agent.ts" }
    private var statusFilePath: String { "\(supportDir)/status.txt" }
    private var agentSourcePath: String? { Bundle.main.path(forResource: "agent", ofType: "ts") }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        ensureServiceIsRunning()
        
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
    
    // --- service management ---
    
    private func ensureServiceIsRunning() {
        
        //uninstall any old version so its stable
        _ = runShellCommand("/bin/launchctl", arguments: ["unload", plistPath])
        try? FileManager.default.removeItem(atPath: plistPath)
        
        // double check
        guard let denoPath = findDenoExecutable() else {
            showAlert(title: "Fatal Error", text: "Deno was not found on your system. Please install it from deno.land and relaunch the app.")
            NSApp.terminate(nil)
            return
        }
        guard let sourcePath = agentSourcePath else {
            showAlert(title: "Fatal Error", text: "The agent.ts script is missing from the app. Please try reinstalling VAM-RPC.")
            NSApp.terminate(nil)
            return
        }
        
        // fresh instll
        do {
            try FileManager.default.createDirectory(atPath: supportDir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: agentDestPath) { try FileManager.default.removeItem(atPath: agentDestPath) }
            try FileManager.default.copyItem(atPath: sourcePath, toPath: agentDestPath)
            let configPath = "\(supportDir)/config.json"; if !FileManager.default.fileExists(atPath: configPath) { try "{\"refreshInterval\": 5, \"detailsString\": \"by {artist}\", \"stateString\": \"on {album}\"}".write(toFile: configPath, atomically: true, encoding: .utf8) }
            let plistContent = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>Label</key><string>\(plistName)</string><key>ProgramArguments</key><array><string>\(denoPath)</string><string>run</string><string>-A</string><string>\(agentDestPath)</string></array><key>RunAtLoad</key><true/><key>KeepAlive</key><true/><key>StandardOutPath</key><string>\(supportDir)/stdout.log</string><key>StandardErrorPath</key><string>\(supportDir)/stderr.log</string></dict></plist>"
            try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
            
            // load servc
            //  _ = runShellCommand("/bin/launchctl", arguments: ["load", plistPath])
            _ = runShellCommand("/bin/launchctl", arguments: ["load", plistPath])
        } catch {
            showAlert(title: "Fatal Error", text: "Could not start the background service: \(error.localizedDescription)")
            NSApp.terminate(nil)
        }
    }

    private func isServiceActive() -> Bool {
        //doublechck
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
        _ = runShellCommand("/bin/launchctl", arguments: ["unload", plistPath])
        NSApplication.shared.terminate(self)
    }
    
    private func startStatusTimer() {
        statusUpdateTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(updateStatus), userInfo: nil, repeats: true); statusUpdateTimer?.fire()
    }
    
    @objc private func updateStatus() {
        if isServiceActive() {
            pauseMenuItem.title = "Pause RPC"
            do {
                let newStatus = try String(contentsOfFile: statusFilePath, encoding: .utf8)
                statusMenuItem.title = "Status: \(newStatus.trimmingCharacters(in: .whitespacesAndNewlines))"
            } catch {
                statusMenuItem.title = "Status: Service running..."
            }
        } else {
            pauseMenuItem.title = "Resume RPC"
            statusMenuItem.title = "Status: RPC Paused"
        }
    }
    
    //helpers
    private func findDenoExecutable() -> String? { ["/opt/homebrew/bin/deno", "/usr/local/bin/deno", "~/.deno/bin/deno"].first { FileManager.default.fileExists(atPath: NSString(string: $0).expandingTildeInPath) }.map { NSString(string: $0).expandingTildeInPath } }
    private func runShellCommand(_ command: String, arguments: [String]) -> String? { let task = Process(); task.executableURL = URL(fileURLWithPath: command); task.arguments = arguments; let pipe = Pipe(); task.standardOutput = pipe; try? task.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); return String(data: data, encoding: .utf8) }
    private func showAlert(title: String, text: String) { let alert = NSAlert(); alert.messageText = title; alert.informativeText = text; alert.runModal(); }
    @objc func showPreferences() {
        if preferencesWindowController == nil {
            let preferencesVC = PreferencesViewController(); let window = NSWindow(contentViewController: preferencesVC); window.title = "VAM-RPC Preferences"; window.styleMask = [.titled, .closable]; window.isReleasedWhenClosed = false; window.center(); preferencesWindowController = NSWindowController(window: window)
        }
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
}
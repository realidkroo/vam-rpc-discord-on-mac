import Cocoa
import ServiceManagement
import QuartzCore

class AppDelegate: NSObject, NSApplicationDelegate {

    // --- UI Properties ---
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var pauseMenuItem: NSMenuItem!
    private var statusUpdateTimer: Timer?
    private var startupPopover: NSPopover?
    
    // Window Controllers
    private var modernWindowController: NSWindowController?
    
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
        if let agentSourcePath = Bundle.main.path(forResource: "agent", ofType: "ts") {
            try? FileManager.default.removeItem(atPath: agentDestPath)
            try? FileManager.default.copyItem(atPath: agentSourcePath, toPath: agentDestPath)
        }
        
        ensureConfigFilesAreInPlace()
        ensureServiceIsRunning()
        setupMenu()
        startStatusTimer()
        
        // Trigger popup on launch with a slight delay to ensure UI readiness
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showStartupPopup()
        }
    }
    
    // --- Startup Popup Logic ---
    
    @objc func showStartupPopup() {
        if let pop = startupPopover, pop.isShown {
            pop.close()
        }
        
        guard let button = statusItem.button else { return }
        
        let popover = NSPopover()
        // Width 380 to accommodate side-by-side layout, Height 130 for button spacing
        popover.contentSize = NSSize(width: 380, height: 130)
        popover.behavior = .transient
        popover.animates = false // We handle animation manually
        
        let viewController = PopupViewController()
        viewController.appDelegate = self
        popover.contentViewController = viewController
        
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        startupPopover = popover
        
        viewController.startPresentationSequence()
    }
    
    func closePopover() {
        startupPopover?.close()
        startupPopover = nil
    }
    
    // --- Menu Setup ---
    
    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "VAM-RPC")
        
        let menu = NSMenu()
        
        // Simulate button at the top for easy testing
        let simItem = NSMenuItem(title: "Simulate Popup", action: #selector(showStartupPopup), keyEquivalent: "p")
        menu.addItem(simItem)
        menu.addItem(.separator())
        
        statusMenuItem = NSMenuItem(title: "Status: Initializing...", action: nil, keyEquivalent: "")
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        
        menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(showModernSettings), keyEquivalent: ","))
        
        pauseMenuItem = NSMenuItem(title: "Pause RPC", action: #selector(toggleServicePause), keyEquivalent: "")
        menu.addItem(pauseMenuItem)
        menu.addItem(.separator())
        
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
            win.minSize = NSSize(width: 1200, height: 800)
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.isMovableByWindowBackground = true
            win.isOpaque = false
            win.backgroundColor = NSColor.clear
            
            let vc = ModernPreferencesViewController()
            win.contentViewController = vc
            
            win.layoutIfNeeded()
            vc.view.layoutSubtreeIfNeeded()
            win.center()
            win.title = "VAM-RPC"
            
            modernWindowController = NSWindowController(window: win)
        }
        
        modernWindowController?.showWindow(nil)
        
        if let win = modernWindowController?.window as? CustomWindow {
            DispatchQueue.main.async { win.forcePositionTrafficLights() }
        }
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // --- Backend Helpers ---
    
    private func ensureConfigFilesAreInPlace() {
        do {
            try FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: userConfigPath) {
                if let bundledConfigPath = Bundle.main.path(forResource: "config", ofType: "json", inDirectory: "data") {
                    try? FileManager.default.copyItem(atPath: bundledConfigPath, toPath: userConfigPath)
                }
            }
        } catch { print("Config setup error: \(error)") }
    }

    private func ensureServiceIsRunning() {
        guard let denoPath = findDenoExecutable() else {
            showAlert(title: "Fatal Error", text: "Deno was not found. Please install it.")
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
            """
            try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
        } catch { showAlert(title: "Error", text: "\(error.localizedDescription)") }
        
        _ = runShellCommand("/bin/launchctl", arguments: ["load", plistPath])
    }
    
    private func isServiceActive() -> Bool { FileManager.default.fileExists(atPath: statusFilePath) }

    @objc func toggleServicePause() {
        if isServiceActive() {
            _ = runShellCommand("/bin/launchctl", arguments: ["unload", plistPath])
            try? FileManager.default.removeItem(atPath: statusFilePath)
        } else {
            _ = runShellCommand("/bin/launchctl", arguments: ["load", plistPath])
        }
        updateStatus()
    }
    
    @objc func quitApp() { NSApplication.shared.terminate(self) }
    
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
        ["/opt/homebrew/bin/deno", "/usr/local/bin/deno", "~/.deno/bin/deno"].first {
            FileManager.default.fileExists(atPath: NSString(string: $0).expandingTildeInPath)
        }?.map { NSString(string: $0).expandingTildeInPath }
    }
    
    private func runShellCommand(_ command: String, arguments: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: command)
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }
    
    private func showAlert(title: String, text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}

// MARK: - Popup View Controller

class PopupViewController: NSViewController {
    
    weak var appDelegate: AppDelegate?
    
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var iconImageView: NSImageView!
    private var preferencesButton: MinimalistButton!
    
    // Containers
    private var contentContainer: NSView! // Holds text/icon for blurring
    private var mainContainer: NSView!
    
    private var blurFilter: CIFilter?
    private var presentationTimer: Timer?
    private var blurTimer: Timer?
    
    private var secondsRemaining = 5
    
    override func loadView() {
        // Main View (Glass Background)
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 130))
        containerView.wantsLayer = true
        
        let bgBlur = NSVisualEffectView(frame: containerView.bounds)
        bgBlur.material = .hudWindow
        bgBlur.state = .active
        bgBlur.blendingMode = .behindWindow
        bgBlur.wantsLayer = true
        bgBlur.layer?.cornerRadius = 18
        bgBlur.layer?.masksToBounds = true
        containerView.addSubview(bgBlur)
        
        mainContainer = containerView
        
        // --- Content Wrapper for Blur Effect ---
        contentContainer = NSView(frame: containerView.bounds)
        contentContainer.wantsLayer = true
        contentContainer.layer?.masksToBounds = false
        mainContainer.addSubview(contentContainer)
        
        // Prepare Filter
        blurFilter = CIFilter(name: "CIGaussianBlur")
        blurFilter?.setDefaults()
        blurFilter?.setValue(20.0, forKey: "inputRadius") // Start BLURRED
        
        // --- LAYOUT SETUP (Icon Left, Text Right, Button Bottom) ---
        
        // 1. Icon (Left Side)
        iconImageView = NSImageView()
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        if let iconImage = NSImage(contentsOfFile: "/Users/realidkroo/vam-rpc-discord-on-mac/icon/icon.png") {
            iconImageView.image = iconImage
        } else {
             iconImageView.image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)
        }
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.wantsLayer = true
        iconImageView.layer?.cornerRadius = 14
        iconImageView.layer?.masksToBounds = true
        iconImageView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        contentContainer.addSubview(iconImageView)
        
        // 2. Title (Right of Icon)
        titleLabel = NSTextField(labelWithString: "Vam-RPC lives here...!")
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .left
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(titleLabel)
        
        // 3. Subtitle / Countdown (Right of Icon, below Title)
        subtitleLabel = NSTextField(labelWithString: "this popup will closes in 5 second")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .left
        subtitleLabel.drawsBackground = false
        subtitleLabel.isEditable = false
        subtitleLabel.isSelectable = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(subtitleLabel)
        
        // 4. Button (Bottom, spanning width)
        preferencesButton = MinimalistButton(frame: .zero)
        preferencesButton.title = "Open preferences"
        preferencesButton.target = self
        preferencesButton.action = #selector(openPreferences)
        preferencesButton.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(preferencesButton)
        
        // --- AUTO LAYOUT CONSTRAINTS ---
        NSLayoutConstraint.activate([
            // Icon: Left margin 20, Top 20, Size 54x54
            iconImageView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 20),
            iconImageView.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 20),
            iconImageView.widthAnchor.constraint(equalToConstant: 54),
            iconImageView.heightAnchor.constraint(equalToConstant: 54),
            
            // Title: Left of Icon + 15, Top aligned with Icon (+2 offset for optics)
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 15),
            titleLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -20),
            
            // Subtitle: Leading aligned with Title, Below Title
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -20),
            
            // Button: Bottom margin 15, Side margins 20, Height 28
            preferencesButton.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -15),
            preferencesButton.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 20),
            preferencesButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -20),
            preferencesButton.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        self.view = containerView
        
        // Initial State: Window opacity 0, scaled down
        self.view.alphaValue = 0.0
        self.view.layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
    }
    
    @objc func openPreferences() {
        appDelegate?.showModernSettings()
    }
    
    // --- ANIMATION SEQUENCE ---
    
    func startPresentationSequence() {
        // Reset state
        secondsRemaining = 5
        subtitleLabel.stringValue = "this popup will closes in 5 second"
        self.view.alphaValue = 0.0
        self.view.layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
        
        // Ensure content starts BLURRED
        setBlurRadius(20.0)
        
        // Step 1: Fade In Window (Content remains blurry)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.view.animator().alphaValue = 1.0
            self.view.animator().layer?.transform = CATransform3DIdentity
        }) {
            // Step 2: Smoothly Unblur Content
            self.animateBlurValue(from: 20.0, to: 0.0, duration: 0.8) {
                // Step 3: Start Countdown
                self.startCountdown()
            }
        }
    }
    
    private func startCountdown() {
        presentationTimer?.invalidate()
        presentationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.secondsRemaining -= 1
            
            if self.secondsRemaining > 0 {
                self.subtitleLabel.stringValue = "this popup will closes in \(self.secondsRemaining) second"
            } else {
                self.subtitleLabel.stringValue = "Closing..."
                timer.invalidate()
                self.endPresentationSequence()
            }
        }
    }
    
    private func endPresentationSequence() {
        // Step 4: Blur Content FIRST
        self.animateBlurValue(from: 0.0, to: 20.0, duration: 0.6) {
            // Step 5: Fade Out Window
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                self.view.animator().alphaValue = 0.0
                self.view.animator().layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
            }) {
                self.appDelegate?.closePopover()
            }
        }
    }
    
    // Manual Blur Interpolation (Bypasses Core Animation filter quirks)
    private func animateBlurValue(from start: CGFloat, to end: CGFloat, duration: Double, completion: @escaping () -> Void) {
        let fps = 60.0
        let steps = duration * fps
        var currentStep = 0.0
        
        blurTimer?.invalidate()
        blurTimer = Timer.scheduledTimer(withTimeInterval: 1.0/fps, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            
            currentStep += 1
            let progress = CGFloat(currentStep / steps)
            
            // Cubic Ease Out
            let ease = 1.0 - pow(1.0 - progress, 3.0)
            let currentRadius = start + (end - start) * ease
            
            self.setBlurRadius(currentRadius)
            
            if currentStep >= steps {
                self.setBlurRadius(end)
                timer.invalidate()
                completion()
            }
        }
    }
    
    private func setBlurRadius(_ radius: CGFloat) {
        // Remove filter if effectively 0 to improve performance and sharpness
        if radius < 0.1 {
            contentContainer.layer?.filters = []
        } else {
            blurFilter?.setValue(radius, forKey: "inputRadius")
            if let filter = blurFilter {
                contentContainer.layer?.filters = [filter]
            }
        }
    }
}

// MARK: - Custom Minimalist Button
class MinimalistButton: NSView {
    
    private var titleLabel: NSTextField!
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isPressed = false
    
    var title: String = "Button" {
        didSet { titleLabel.stringValue = title }
    }
    
    var action: Selector?
    weak var target: AnyObject?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        
        titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        updateTrackingAreas()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existingArea = trackingArea { removeTrackingArea(existingArea) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        updateAppearance()
    }
    
    override func mouseDown(with event: NSEvent) {
        isPressed = true
        updateAppearance()
    }
    
    override func mouseUp(with event: NSEvent) {
        isPressed = false
        updateAppearance()
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            if let target = target, let action = action {
                NSApp.sendAction(action, to: target, from: self)
            }
        }
    }
    
    private func updateAppearance() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.allowsImplicitAnimation = true
            if isPressed {
                layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
            } else if isHovered {
                layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
            } else {
                layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
            }
        })
    }
}

// MARK: - Custom Window (Unchanged)
class CustomWindow: NSWindow {
    private var hasPositionedButtons = false
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    }
    
    func forcePositionTrafficLights() {
        positionTrafficLights()
        hasPositionedButtons = true
    }
    
    override func orderFront(_ sender: Any?) {
        super.orderFront(sender)
        if !hasPositionedButtons {
            DispatchQueue.main.async { [weak self] in
                self?.positionTrafficLights()
                self?.hasPositionedButtons = true
            }
        }
    }
    
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        if hasPositionedButtons { positionTrafficLights() }
    }
    
    private func positionTrafficLights() {
        guard let closeButton = standardWindowButton(.closeButton),
              let miniButton = standardWindowButton(.miniaturizeButton),
              let zoomButton = standardWindowButton(.zoomButton) else { return }
        
        let titlebarHeight = frame.height - contentLayoutRect.height
        let verticalCenter = titlebarHeight / 7
        let buttonRadius: CGFloat = 6 
        let targetY = verticalCenter - buttonRadius
        
        closeButton.setFrameOrigin(NSPoint(x: 20, y: targetY))
        miniButton.setFrameOrigin(NSPoint(x: 40, y: targetY))
        zoomButton.setFrameOrigin(NSPoint(x: 60, y: targetY))
        
        closeButton.isEnabled = true
        miniButton.isHidden = false
    }
}
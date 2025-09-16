// PreferencesViewController.swift
import Cocoa

struct Settings: Codable {
    var refreshInterval: Int
    var activityName: String
    var enableSpotifyButton: Bool
    var spotifyButtonLabel: String
    var enableAppleMusicButton: Bool
    var appleMusicButtonLabel: String
    
    static func defaultSettings() -> Settings {
        return Settings(
            refreshInterval: 5,
            activityName: "Apple Music",
            enableSpotifyButton: true,
            spotifyButtonLabel: "♫ Find On Spotify",
            enableAppleMusicButton: true,
            appleMusicButtonLabel: "♫ Open on  Music"
        )
    }
}

class PreferencesViewController: NSViewController {

    private let dataDir = NSString(string: "~/Library/Application Support/VAM-RPC/data").expandingTildeInPath
    private var configPath: String { "\(dataDir)/config.json" }
    private let plistName = "com.vam-rpc.agent.plist"
    private var plistPath: String { NSString(string: "~/Library/LaunchAgents/com.vam-rpc.agent.plist").expandingTildeInPath }

    private let activityTypeDropdown = NSPopUpButton(frame: .zero)
    private let activityNameField = NSTextField()
    private let refreshIntervalField = NSTextField()
    private let spotifySwitch = NSSwitch()
    private let spotifyButtonField = NSTextField()
    private let appleMusicSwitch = NSSwitch()
    private let appleMusicButtonField = NSTextField()

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 580))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSettings()
    }
    
    private func setupUI() {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.material = .sidebar
        view.addSubview(visualEffectView)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = createLabel("Settings", font: .systemFont(ofSize: 28, weight: .bold))
        let profileImageView = NSImageView(image: NSImage(named: "icon/roo") ?? NSImage())
        profileImageView.wantsLayer = true
        profileImageView.layer?.cornerRadius = 20
        profileImageView.layer?.masksToBounds = true
        
        let headerStack = NSStackView(views: [titleLabel, NSView(), profileImageView])
        headerStack.orientation = .horizontal
        
        let subtitleLabel = createLabel("Apple music Listening status for your discord in your mac.", font: .systemFont(ofSize: 14), color: .secondaryLabelColor)
        let divider = NSBox()
        divider.boxType = .separator

        let activityHeader = createLabel("Activity", font: .systemFont(ofSize: 16, weight: .semibold))
        let activitySubtitle = createLabel("Select the activity type, you can only choose 1 of 2", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        activityTypeDropdown.addItems(withTitles: ["Listening", "Playing"])
        let activityNameLabel = createLabel("Activity Name (This will be displayed after activity type)", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)

        let optionsHeader = createLabel("Options", font: .systemFont(ofSize: 16, weight: .semibold))
        let refreshLabel = createLabel("Refresh Interval (1-15 in seconds)", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        
        let spotifyStack = createSwitchStack(label: "Enable find on spotify Button?", sublabel: "If Enabled, Set the Button Name", switchView: spotifySwitch, textField: spotifyButtonField)
        let appleMusicStack = createSwitchStack(label: "Enable Open On Apple Music Button?", sublabel: "If Enabled, Set the Button Name", switchView: appleMusicSwitch, textField: appleMusicButtonField)

        let resetButton = NSButton(title: "Reset", target: self, action: #selector(resetSettings))
        let nextButton = NSButton(title: "Next", target: nil, action: nil)
        nextButton.isEnabled = false
        let saveButton = NSButton(title: "Save and Reopen", target: self, action: #selector(saveSettings))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        
        let buttonStack = NSStackView(views: [resetButton, NSView(), nextButton, saveButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12

        let mainStack = NSStackView(views: [
            headerStack, subtitleLabel, divider,
            activityHeader, activitySubtitle, activityTypeDropdown, activityNameLabel, activityNameField,
            optionsHeader, refreshLabel, refreshIntervalField,
            spotifyStack, appleMusicStack,
            NSView(),
            buttonStack
        ])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 10
        mainStack.setCustomSpacing(4, after: headerStack)
        mainStack.setCustomSpacing(20, after: subtitleLabel)
        mainStack.setCustomSpacing(4, after: activityHeader)
        mainStack.setCustomSpacing(12, after: activitySubtitle)
        mainStack.setCustomSpacing(4, after: activityNameLabel)
        mainStack.setCustomSpacing(24, after: activityNameField)
        mainStack.setCustomSpacing(4, after: optionsHeader)
        mainStack.setCustomSpacing(12, after: refreshLabel)
        mainStack.setCustomSpacing(24, after: refreshIntervalField)
        mainStack.setCustomSpacing(16, after: spotifyStack)
        
        view.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            profileImageView.widthAnchor.constraint(equalToConstant: 40),
            profileImageView.heightAnchor.constraint(equalToConstant: 40),

            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            headerStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            divider.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            activityTypeDropdown.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            activityNameField.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            refreshIntervalField.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            spotifyStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            appleMusicStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            buttonStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])
    }
    
    private func loadSettings() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
            if let bundledConfigPath = Bundle.main.url(forResource: "config", withExtension: "json", subdirectory: "data"),
               let bundledData = try? Data(contentsOf: bundledConfigPath),
               let defaultSettings = try? JSONDecoder().decode(Settings.self, from: bundledData) {
                applySettings(defaultSettings)
            }
            return
        }
        applySettings(settings)
    }
    
    private func applySettings(_ settings: Settings) {
        activityTypeDropdown.selectItem(withTitle: "Listening")
        activityNameField.stringValue = settings.activityName
        refreshIntervalField.integerValue = settings.refreshInterval
        spotifySwitch.state = settings.enableSpotifyButton ? .on : .off
        spotifyButtonField.stringValue = settings.spotifyButtonLabel
        appleMusicSwitch.state = settings.enableAppleMusicButton ? .on : .off
        appleMusicButtonField.stringValue = settings.appleMusicButtonLabel
    }

    @objc private func saveSettings() {
        var interval = refreshIntervalField.integerValue
        if interval < 1 { interval = 1 }
        if interval > 15 { interval = 15 }
        
        let currentSettings = Settings(
            refreshInterval: interval,
            activityName: activityNameField.stringValue,
            enableSpotifyButton: spotifySwitch.state == .on,
            spotifyButtonLabel: spotifyButtonField.stringValue,
            enableAppleMusicButton: appleMusicSwitch.state == .on,
            appleMusicButtonLabel: appleMusicButtonField.stringValue
        )
        
        do {
            let data = try JSONEncoder().encode(currentSettings)
            try data.write(to: URL(fileURLWithPath: configPath))
            restartService()
            self.view.window?.close()
        } catch {
            let alert = NSAlert(); alert.messageText = "Error"; alert.informativeText = "Could not save settings: \(error.localizedDescription)"; alert.runModal()
        }
    }
    
    @objc private func resetSettings() {
        if let bundledConfigPath = Bundle.main.url(forResource: "config", withExtension: "json", subdirectory: "data"),
           let bundledData = try? Data(contentsOf: bundledConfigPath),
           let defaultSettings = try? JSONDecoder().decode(Settings.self, from: bundledData) {
            applySettings(defaultSettings)
        }
    }
    
    private func restartService() {
        _ = runShellCommand("/bin/launchctl", arguments: ["unload", plistPath])
        Thread.sleep(forTimeInterval: 0.1)
        _ = runShellCommand("/bin/launchctl", arguments: ["load", plistPath])
    }
    
    private func runShellCommand(_ command: String, arguments: [String]) -> String? {
        let task = Process(); task.executableURL = URL(fileURLWithPath: command); task.arguments = arguments; let pipe = Pipe(); task.standardOutput = pipe; try? task.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); return String(data: data, encoding: .utf8)
    }

    private func createLabel(_ text: String, font: NSFont, color: NSColor = .labelColor) -> NSTextField {
        let cleanText = text.replacingOccurrences(of: "<u>", with: "").replacingOccurrences(of: "</u>", with: "")
        let label = NSTextField(labelWithString: cleanText)
        label.font = font
        label.textColor = color
        return label
    }

    private func createSwitchStack(label: String, sublabel: String, switchView: NSSwitch, textField: NSTextField) -> NSStackView {
        let headerStack = NSStackView(views: [createLabel(label, font: .systemFont(ofSize: 13, weight: .medium)), NSView(), switchView]); headerStack.orientation = .horizontal
        let subLabelView = createLabel(sublabel, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        let stack = NSStackView(views: [headerStack, subLabelView, textField]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 4; stack.setCustomSpacing(8, after: headerStack)
        headerStack.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        textField.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }
}
// PreferencesViewController.swift
import Cocoa
import ServiceManagement
import QuartzCore // ✨ ADDED: For CATransition

struct Settings: Codable {
    // Page 1
    var refreshInterval: Int
    var activityName: String
    var enableSpotifyButton: Bool
    var spotifyButtonLabel: String
    var enableAppleMusicButton: Bool
    var appleMusicButtonLabel: String
    
    // Page 2
    var enableSonglinkButton: Bool
    var songlinkButtonLabel: String
    var enableYoutubeMusicButton: Bool
    var youtubeMusicButtonLabel: String
    var enableAutoLaunch: Bool
    
    // Page 3
    var detailsString: String
    var stateString: String
    var largeImageText: String
    var smallImageText: String
    var smallImageSource: String // "default" or "albumArt"
    
    static func defaultSettings() -> Settings {
        return Settings(
            refreshInterval: 5,
            activityName: "Apple Music",
            enableSpotifyButton: true,
            spotifyButtonLabel: "♫ Find On Spotify",
            enableAppleMusicButton: true,
            appleMusicButtonLabel: "♫ Open on  Music",
            enableSonglinkButton: false,
            songlinkButtonLabel: "♫ Find on Songlink",
            enableYoutubeMusicButton: false,
            youtubeMusicButtonLabel: "♫ Find on YT Music",
            enableAutoLaunch: false,
            detailsString: "{name}",
            stateString: "by {artist}",
            largeImageText: "{name} - {album}",
            smallImageText: "{artist}",
            smallImageSource: "default"
        )
    }
}

class PreferencesViewController: NSViewController {

    private let dataDir = NSString(string: "~/Library/Application Support/VAM-RPC/data").expandingTildeInPath
    private var configPath: String { "\(dataDir)/config.json" }
    private let plistName = "com.vam-rpc.agent.plist"
    private var plistPath: String { NSString(string: "~/Library/LaunchAgents/com.vam-rpc.agent.plist").expandingTildeInPath }
    private let appBundleId = "com.vam-rpc.app" as CFString

    // Page 1
    private let activityTypeDropdown = NSPopUpButton(frame: .zero)
    private let activityNameField = NSTextField()
    private let refreshIntervalField = NSTextField()
    private let spotifySwitch = NSSwitch()
    private let spotifyButtonField = NSTextField()
    private let appleMusicSwitch = NSSwitch()
    private let appleMusicButtonField = NSTextField()

    // Page 2
    private let songlinkSwitch = NSSwitch()
    private let songlinkButtonField = NSTextField()
    private let youtubeMusicSwitch = NSSwitch()
    private let youtubeMusicButtonField = NSTextField()
    private let autoLaunchSwitch = NSSwitch()
    
    // Page 3
    private let detailsStringField = NSTextField()
    private let stateStringField = NSTextField()
    private let largeImageTextField = NSTextField()
    private let smallImageTextField = NSTextField()
    private let smallImageSourceDropdown = NSPopUpButton(frame: .zero)

    private var buttonSwitches: [NSSwitch] { [spotifySwitch, appleMusicSwitch, songlinkSwitch, youtubeMusicSwitch] }

    private var page1Stack: NSStackView!
    private var page2Stack: NSStackView!
    private var page3Stack: NSStackView!
    private let backButton = NSButton(title: "<", target: self, action: #selector(showPreviousPage))
    private let nextButton = NSButton(title: ">", target: self, action: #selector(showNextPage))
    private let saveButton = NSButton(title: "Save & Reopen", target: self, action: #selector(saveSettings))
    private var currentPage = 1
    
    // ✨ ADDED: A container view to host the current page stack for animations
    private var pageContainerView: NSView!
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 620)) // Increased height
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        self.view = visualEffectView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSettings()
        updatePageVisibility()
    }
    
    private func setupUI() {
        let allTextFields = [activityNameField, refreshIntervalField, spotifyButtonField, appleMusicButtonField, songlinkButtonField, youtubeMusicButtonField, detailsStringField, stateStringField, largeImageTextField, smallImageTextField]
        allTextFields.forEach {
            $0.usesSingleLineMode = true
            $0.bezelStyle = .roundedBezel
        }
        
        buttonSwitches.forEach { s in
            s.target = self
            s.action = #selector(validateButtonSwitches)
        }

        // Page 1
        let activityHeader = createLabel("Activity", font: .systemFont(ofSize: 16, weight: .semibold))
        let activitySubtitle = createLabel("Select the activity type, you can only choose 1 of 2", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        activityTypeDropdown.addItems(withTitles: ["Listening", " ( Coming Soon )"])
        let activityNameLabel = createLabel("Activity Name (This will be displayed after activity type)", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        let optionsHeader = createLabel("Options", font: .systemFont(ofSize: 16, weight: .semibold))
        let refreshLabel = createLabel("Refresh Interval (1-15 in seconds)", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        let spotifyStack = createSwitchStack(label: "Enable find on spotify Button?", sublabel: "If Enabled, Set the Button Name", switchView: spotifySwitch, textField: spotifyButtonField)
        let appleMusicStack = createSwitchStack(label: "Enable Open On Apple Music Button?", sublabel: "If Enabled, Set the Button Name", switchView: appleMusicSwitch, textField: appleMusicButtonField)
        page1Stack = NSStackView(views: [activityHeader, activitySubtitle, activityTypeDropdown, activityNameLabel, activityNameField, optionsHeader, refreshLabel, refreshIntervalField, spotifyStack, appleMusicStack])
        configurePageStack(page1Stack)

        // Page 2
        let linksHeader = createLabel("Link Buttons", font: .systemFont(ofSize: 16, weight: .semibold))
        let songlinkStack = createSwitchStack(label: "Enable Open on Songlink Button?", sublabel: "If Enabled, Set the Button Name", switchView: songlinkSwitch, textField: songlinkButtonField)
        let youtubeMusicStack = createSwitchStack(label: "Enable Open On Youtube Music Button?", sublabel: "If Enabled, Set the Button Name", switchView: youtubeMusicSwitch, textField: youtubeMusicButtonField)
        let generalHeader = createLabel("General", font: .systemFont(ofSize: 16, weight: .semibold))
        let autoLaunchStack = createSwitchStack(label: "Enable Auto open app when Login?", sublabel: "Automatically starts VAM-RPC when you log in.", switchView: autoLaunchSwitch)
        page2Stack = NSStackView(views: [linksHeader, songlinkStack, youtubeMusicStack, generalHeader, autoLaunchStack])
        configurePageStack(page2Stack)
        
        // Page 3
        let stringHeader = createLabel("String Customisations", font: .systemFont(ofSize: 16, weight: .semibold))
        let stringSublabel = createLabel("Use {name}, {artist}, and {album} as placeholders.", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        let imageHeader = createLabel("Image Customisations", font: .systemFont(ofSize: 16, weight: .semibold))
        smallImageSourceDropdown.addItems(withTitles: ["Turn It Off", "Use Album Artwork"])
        page3Stack = NSStackView(views: [stringHeader, stringSublabel, createFieldStack(label: "Details String", textField: detailsStringField), createFieldStack(label: "State String", textField: stateStringField), createFieldStack(label: "Large Image Hover Text", textField: largeImageTextField), createFieldStack(label: "Small Image Hover Text", textField: smallImageTextField), imageHeader, createFieldStack(label: "Small Image Source (Circle)", popup: smallImageSourceDropdown)])
        configurePageStack(page3Stack)

        let titleLabel = createLabel("Settings", font: .systemFont(ofSize: 28, weight: .bold))
        let subtitleLabel = createLabel("Apple music Listening status for your discord in your mac.", font: .systemFont(ofSize: 14), color: .secondaryLabelColor)
        let divider = NSBox(); divider.boxType = .separator
        
        // ✨ ADDED: Initialize the container and enable layers for animation
        pageContainerView = NSView()
        pageContainerView.wantsLayer = true

        let resetButton = NSButton(title: "Reset", target: self, action: #selector(resetSettings))
        let helpButton = NSButton(title: "?", target: self, action: #selector(showHelp))
        helpButton.bezelStyle = .helpButton
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        
        let buttonStack = NSStackView(views: [resetButton, helpButton, NSView(), backButton, nextButton, saveButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12

        // ✨ CHANGED: Add pageContainerView instead of the individual page stacks
        let mainStack = NSStackView(views: [
            titleLabel, subtitleLabel, divider,
            pageContainerView,
            NSView(), // Spacer
            buttonStack
        ])
        mainStack.orientation = .vertical; mainStack.alignment = .leading; mainStack.spacing = 10
        mainStack.setCustomSpacing(20, after: subtitleLabel)

        view.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        // ✨ ADDED: Set up the initial page in the container
        pageContainerView.addSubview(page1Stack)
        page1Stack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            divider.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            pageContainerView.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            buttonStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            
            // Constraints for the initial page to fill the container
            page1Stack.topAnchor.constraint(equalTo: pageContainerView.topAnchor),
            page1Stack.bottomAnchor.constraint(equalTo: pageContainerView.bottomAnchor),
            page1Stack.leadingAnchor.constraint(equalTo: pageContainerView.leadingAnchor),
            page1Stack.trailingAnchor.constraint(equalTo: pageContainerView.trailingAnchor),
        ])
    }
    
    private func configurePageStack(_ stack: NSStackView) {
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10

        if stack === page1Stack {
            stack.setCustomSpacing(4, after: stack.views[0]); stack.setCustomSpacing(12, after: stack.views[1])
            stack.setCustomSpacing(4, after: stack.views[2]); stack.setCustomSpacing(24, after: stack.views[4])
            stack.setCustomSpacing(4, after: stack.views[5]); stack.setCustomSpacing(12, after: stack.views[6])
            stack.setCustomSpacing(24, after: stack.views[7]); stack.setCustomSpacing(16, after: stack.views[8])
        } else if stack === page2Stack {
            stack.setCustomSpacing(4, after: stack.views[0]); stack.setCustomSpacing(24, after: stack.views[2])
            stack.setCustomSpacing(4, after: stack.views[3])
        } else if stack === page3Stack {
            stack.setCustomSpacing(4, after: stack.views[0]); stack.setCustomSpacing(24, after: stack.views[1])
            stack.setCustomSpacing(16, after: stack.views[5])
        }
    }
    
    // ✨ CHANGED: Updated navigation to call the new transition method
    @objc private func showPreviousPage() {
        if currentPage > 1 {
            let oldPage = currentPage
            currentPage -= 1
            transition(to: currentPage, from: oldPage)
            updatePageVisibility()
        }
    }
    
    @objc private func showNextPage() {
        if currentPage < 3 {
            let oldPage = currentPage
            currentPage += 1
            transition(to: currentPage, from: oldPage)
            updatePageVisibility()
        }
    }
    
    // ✨ ADDED: A helper to get the correct page view
    private func stack(for page: Int) -> NSStackView? {
        switch page {
        case 1: return page1Stack
        case 2: return page2Stack
        case 3: return page3Stack
        default: return nil
        }
    }

    // ✨ ADDED: The core animation logic
    private func transition(to newPage: Int, from oldPage: Int) {
        guard let fromView = stack(for: oldPage),
              let toView = stack(for: newPage) else { return }
        
        let slideDirection: CATransitionSubtype = (newPage > oldPage) ? .fromRight : .fromLeft

        let transition = CATransition()
        transition.duration = 0.25
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.type = .push
        transition.subtype = slideDirection
        
        pageContainerView.layer?.add(transition, forKey: kCATransition)
        
        fromView.removeFromSuperview()
        pageContainerView.addSubview(toView)
        
        toView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toView.topAnchor.constraint(equalTo: pageContainerView.topAnchor),
            toView.bottomAnchor.constraint(equalTo: pageContainerView.bottomAnchor),
            toView.leadingAnchor.constraint(equalTo: pageContainerView.leadingAnchor),
            toView.trailingAnchor.constraint(equalTo: pageContainerView.trailingAnchor)
        ])
    }

    // ✨ CHANGED: This method now only handles button state
    private func updatePageVisibility() {
        backButton.isEnabled = (currentPage != 1)
        nextButton.isEnabled = (currentPage != 3)
    }

    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "lorem ipsum dolor color amet"
        alert.informativeText = "lorem ipsum dolor color amet im still working on this"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func loadSettings() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
            applySettings(Settings.defaultSettings())
            return
        }
        applySettings(settings)
    }
    
    private func applySettings(_ settings: Settings) {
        // Page 1
        activityTypeDropdown.selectItem(withTitle: "Listening")
        activityNameField.stringValue = settings.activityName
        refreshIntervalField.integerValue = settings.refreshInterval
        spotifySwitch.state = settings.enableSpotifyButton ? .on : .off
        spotifyButtonField.stringValue = settings.spotifyButtonLabel
        appleMusicSwitch.state = settings.enableAppleMusicButton ? .on : .off
        appleMusicButtonField.stringValue = settings.appleMusicButtonLabel
        
        // Page 2
        songlinkSwitch.state = settings.enableSonglinkButton ? .on : .off
        songlinkButtonField.stringValue = settings.songlinkButtonLabel
        youtubeMusicSwitch.state = settings.enableYoutubeMusicButton ? .on : .off
        youtubeMusicButtonField.stringValue = settings.youtubeMusicButtonLabel
        autoLaunchSwitch.state = settings.enableAutoLaunch ? .on : .off
        
        // Page 3
        detailsStringField.stringValue = settings.detailsString
        stateStringField.stringValue = settings.stateString
        largeImageTextField.stringValue = settings.largeImageText
        smallImageTextField.stringValue = settings.smallImageText
        smallImageSourceDropdown.selectItem(at: settings.smallImageSource == "albumArt" ? 1 : 0)
        
        validateButtonSwitches()
    }
    
    @objc private func validateButtonSwitches() {
        let enabledCount = buttonSwitches.filter { $0.state == .on }.count
        if enabledCount >= 2 {
            for s in buttonSwitches where s.state == .off { s.isEnabled = false }
        } else {
            for s in buttonSwitches { s.isEnabled = true }
        }
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
            appleMusicButtonLabel: appleMusicButtonField.stringValue,
            enableSonglinkButton: songlinkSwitch.state == .on,
            songlinkButtonLabel: songlinkButtonField.stringValue,
            enableYoutubeMusicButton: youtubeMusicSwitch.state == .on,
            youtubeMusicButtonLabel: youtubeMusicButtonField.stringValue,
            enableAutoLaunch: autoLaunchSwitch.state == .on,
            detailsString: detailsStringField.stringValue,
            stateString: stateStringField.stringValue,
            largeImageText: largeImageTextField.stringValue,
            smallImageText: smallImageTextField.stringValue,
            smallImageSource: smallImageSourceDropdown.indexOfSelectedItem == 1 ? "albumArt" : "default"
        )
        
        do {
            let data = try JSONEncoder().encode(currentSettings)
            try data.write(to: URL(fileURLWithPath: configPath))
            SMLoginItemSetEnabled(appBundleId, currentSettings.enableAutoLaunch)
            restartService()
            self.view.window?.close()
        } catch {
            showAlert(title: "Error", text: "Could not save settings: \(error.localizedDescription)")
        }
    }
    
    @objc private func resetSettings() {
        applySettings(Settings.defaultSettings())
    }
    
    private func restartService() {
        _ = runShellCommand("/bin/launchctl", arguments: ["unload", plistPath])
        Thread.sleep(forTimeInterval: 0.1)
        _ = runShellCommand("/bin/launchctl", arguments: ["load", plistPath])
    }
    
    private func runShellCommand(_ command: String, arguments: [String]) -> String? { let task = Process(); task.executableURL = URL(fileURLWithPath: command); task.arguments = arguments; let pipe = Pipe(); task.standardOutput = pipe; try? task.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); return String(data: data, encoding: .utf8) }
    private func showAlert(title: String, text: String) { let alert = NSAlert(); alert.messageText = title; alert.informativeText = text; alert.runModal() }
    private func createLabel(_ text: String, font: NSFont, color: NSColor = .labelColor) -> NSTextField { let label = NSTextField(labelWithString: text); label.font = font; label.textColor = color; return label }
    
    private func createFieldStack(label: String, textField: NSTextField) -> NSStackView {
        let labelView = createLabel(label, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        let stack = NSStackView(views: [labelView, textField]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 4
        textField.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }
    
    private func createFieldStack(label: String, popup: NSPopUpButton) -> NSStackView {
        let labelView = createLabel(label, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        let stack = NSStackView(views: [labelView, popup]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 4
        return stack
    }

    private func createSwitchStack(label: String, sublabel: String, switchView: NSSwitch, textField: NSTextField? = nil) -> NSStackView {
        let headerStack = NSStackView(views: [createLabel(label, font: .systemFont(ofSize: 13, weight: .medium)), NSView(), switchView]); headerStack.orientation = .horizontal
        let subLabelView = createLabel(sublabel, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        var views: [NSView] = [headerStack, subLabelView]
        if let textField = textField { views.append(textField) }
        let stack = NSStackView(views: views); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 4; stack.setCustomSpacing(8, after: headerStack)
        headerStack.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        textField?.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }
}
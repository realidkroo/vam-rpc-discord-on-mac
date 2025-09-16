// PreferencesViewController.swift
import Cocoa
import ServiceManagement
import QuartzCore // For CATransition

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


// A private class to build the RPC Preview UI
private class PreviewView: NSView {

    // Labels that will be updated
    let activityLabel = NSTextField(labelWithString: "Listening to Apple Music")
    let songTitleLabel = NSTextField(labelWithString: "Boom! Boom!")
    let artistLabel = NSTextField(labelWithString: "By Roo")
    let albumLabel = NSTextField(labelWithString: "Broken")
    let smallImageHoverLabel = NSTextField(labelWithString: "Roo")
    let timestampLabel = NSTextField(labelWithString: "0:01 / 3:45")
    
    let spotifyButton = NSButton()
    let appleMusicButton = NSButton()

    let smallImageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupPreviewUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(with settings: Settings, example: (name: String, artist: String, album: String)) {
        // Update Activity
        activityLabel.stringValue = "Listening to \(settings.activityName)"
        
        // Update Song Details
        songTitleLabel.stringValue = settings.detailsString.replacingOccurrences(of: "{name}", with: example.name)
        artistLabel.stringValue = "By \(settings.stateString.replacingOccurrences(of: "{artist}", with: example.artist))"
        albumLabel.stringValue = settings.largeImageText.replacingOccurrences(of: "{album}", with: example.album)
        
        // Update Buttons with padding
        spotifyButton.isHidden = !settings.enableSpotifyButton
        spotifyButton.title = "  \(settings.spotifyButtonLabel)  "
        appleMusicButton.isHidden = !settings.enableAppleMusicButton
        appleMusicButton.title = "  \(settings.appleMusicButtonLabel)  "
        
        // Update Small Image
        smallImageView.isHidden = (settings.smallImageSource != "albumArt")
        smallImageHoverLabel.stringValue = settings.smallImageText.replacingOccurrences(of: "{artist}", with: example.artist)
    }

    private func setupPreviewUI() {
        // --- Create UI Elements ---
        let usernameLabel = createLabel("realidkroo", font: .systemFont(ofSize: 15, weight: .semibold))
        configureLabel(activityLabel, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        configureLabel(songTitleLabel, font: .systemFont(ofSize: 13, weight: .semibold))
        configureLabel(artistLabel, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        configureLabel(albumLabel, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        configureLabel(timestampLabel, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        
        let userAvatar = createPlaceholderImageView(imageName: "roo.jpg", cornerRadius: 16)
        let largeImage = createPlaceholderImageView(imageName: "asltolfo.png", cornerRadius: 8)
        
        smallImageView.image = NSImage(named: "roo.jpg")
        configurePlaceholder(for: smallImageView, cornerRadius: 12)
        smallImageView.layer?.borderWidth = 2
        smallImageView.layer?.borderColor = NSColor.black.withAlphaComponent(0.4).cgColor

        let micIcon = createIcon(systemName: "mic.fill")
        let headphonesIcon = createIcon(systemName: "headphones")
        let settingsIcon = createIcon(systemName: "gearshape.fill")
        
        spotifyButton.title = "  ♫ Find On Spotify  "
        appleMusicButton.title = "  ♫ Open on  Music  "
        
        configurePreviewButton(spotifyButton)
        configurePreviewButton(appleMusicButton)

        let progressBar = NSView()
        progressBar.wantsLayer = true
        progressBar.layer?.backgroundColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.4).cgColor
        progressBar.layer?.cornerRadius = 2
        let progressFill = NSView()
        progressFill.wantsLayer = true
        progressFill.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
        progressFill.layer?.cornerRadius = 2
        progressBar.addSubview(progressFill)
        
        let progressStack = NSStackView(views: [progressBar, timestampLabel])
        progressStack.spacing = 8

        // --- Layout ---
        let topInfoStack = NSStackView(views: [usernameLabel, activityLabel])
        topInfoStack.orientation = .vertical; topInfoStack.alignment = .leading; topInfoStack.spacing = 2

        let iconsStack = NSStackView(views: [micIcon, headphonesIcon])
        
        let topSection = NSStackView(views: [userAvatar, topInfoStack, NSView(), iconsStack])
        topSection.spacing = 8; topSection.alignment = .top
        
        let buttonStack = NSStackView(views: [appleMusicButton, spotifyButton, NSView()])
        buttonStack.spacing = 8
        
        let songInfoStack = NSStackView(views: [songTitleLabel, artistLabel, albumLabel, progressStack, buttonStack])
        songInfoStack.orientation = .vertical; songInfoStack.alignment = .leading; songInfoStack.spacing = 2
        songInfoStack.setCustomSpacing(6, after: albumLabel)
        songInfoStack.setCustomSpacing(8, after: progressStack)
        
        let mainContentStack = NSStackView(views: [largeImage, songInfoStack])
        mainContentStack.spacing = 10
        
        let mainStack = NSStackView(views: [topSection, mainContentStack])
        mainStack.orientation = .vertical; mainStack.spacing = 10; mainStack.alignment = .leading

        let background = NSVisualEffectView()
        background.material = .underWindowBackground
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 8
        
        addSubview(background)
        background.addSubview(mainStack)
        addSubview(smallImageView, positioned: .above, relativeTo: largeImage)
        background.addSubview(settingsIcon)

        // --- Constraints ---
        background.translatesAutoresizingMaskIntoConstraints = false; mainStack.translatesAutoresizingMaskIntoConstraints = false
        progressFill.translatesAutoresizingMaskIntoConstraints = false; smallImageView.translatesAutoresizingMaskIntoConstraints = false
        settingsIcon.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            mainStack.topAnchor.constraint(equalTo: background.topAnchor, constant: 12),
            mainStack.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -12),
            mainStack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -36),
            
            userAvatar.widthAnchor.constraint(equalToConstant: 32),
            userAvatar.heightAnchor.constraint(equalToConstant: 32),
            
            largeImage.widthAnchor.constraint(equalToConstant: 80),
            largeImage.heightAnchor.constraint(equalToConstant: 80),
            
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            progressFill.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressBar.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBar.bottomAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressBar.widthAnchor, multiplier: 0.1),
            
            smallImageView.widthAnchor.constraint(equalToConstant: 28),
            smallImageView.heightAnchor.constraint(equalToConstant: 28),
            smallImageView.trailingAnchor.constraint(equalTo: largeImage.trailingAnchor, constant: 7),
            smallImageView.bottomAnchor.constraint(equalTo: largeImage.bottomAnchor, constant: 7),

            settingsIcon.topAnchor.constraint(equalTo: background.topAnchor, constant: 12),
            settingsIcon.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -12),
        ])
    }
    
    private func createPlaceholderImageView(imageName: String, cornerRadius: CGFloat) -> NSImageView {
        let imageView = NSImageView()
        if let image = NSImage(named: imageName) {
            imageView.image = image
        } else {
            print("⚠️ Image Not Found in Bundle: '\(imageName)'. Check if it's copied correctly.")
        }
        configurePlaceholder(for: imageView, cornerRadius: cornerRadius)
        return imageView
    }
    
    private func configurePlaceholder(for imageView: NSImageView, cornerRadius: CGFloat) {
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = cornerRadius
        if imageView.image == nil {
            imageView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        }
    }
    
    private func createLabel(_ text: String, font: NSFont, color: NSColor = .labelColor) -> NSTextField {
        // ✨ FIXED: Corrected typo from NSTextFiel to NSTextField
        let label = NSTextField(labelWithString: text)
        configureLabel(label, font: font, color: color)
        return label
    }

    private func configureLabel(_ label: NSTextField, font: NSFont, color: NSColor = .labelColor) {
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
    }
    
    private func createIcon(systemName: String) -> NSImageView {
        let imageView = NSImageView(image: NSImage(systemSymbolName: systemName, accessibilityDescription: nil)!)
        imageView.symbolConfiguration = .init(pointSize: 16, weight: .regular)
        imageView.contentTintColor = .secondaryLabelColor
        return imageView
    }
    
    private func configurePreviewButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 4
        button.layer?.borderWidth = 1
        button.layer?.borderColor = NSColor.tertiaryLabelColor.cgColor
        button.contentTintColor = .secondaryLabelColor
        
        button.controlSize = .small
        button.heightAnchor.constraint(equalToConstant: 26).isActive = true
    }
}


class PreferencesViewController: NSViewController, NSTextFieldDelegate {

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
    
    private let backButton = NSButton()
    private let nextButton = NSButton()
    private let saveButton = NSButton()
    
    private var currentPage = 1
    
    private var pageContainerView: NSView!
    
    private var previewView: PreviewView!
    private var bottomButtonStack: NSStackView!
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 800))
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
        updatePreview()
    }
    
    private func setupUI() {
        let allTextFields = [activityNameField, refreshIntervalField, spotifyButtonField, appleMusicButtonField, songlinkButtonField, youtubeMusicButtonField, detailsStringField, stateStringField, largeImageTextField, smallImageTextField]
        allTextFields.forEach {
            $0.usesSingleLineMode = true
            $0.bezelStyle = .roundedBezel
            $0.delegate = self
        }
        
        let allSwitches = buttonSwitches + [autoLaunchSwitch]
        allSwitches.forEach { s in
            s.target = self
            s.action = #selector(controlDidChangeValue)
        }
        activityTypeDropdown.target = self; activityTypeDropdown.action = #selector(controlDidChangeValue)
        smallImageSourceDropdown.target = self; smallImageSourceDropdown.action = #selector(controlDidChangeValue)
        
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
        let divider1 = NSBox(); divider1.boxType = .separator
        
        let divider2 = NSBox(); divider2.boxType = .separator
        let previewHeader = createLabel("Preview", font: .systemFont(ofSize: 16, weight: .semibold))
        previewView = PreviewView()
        
        pageContainerView = NSView(); pageContainerView.wantsLayer = true

        let resetButton = NSButton(title: "Reset", target: self, action: #selector(resetSettings))
        let helpButton = NSButton(title: "?", target: self, action: #selector(showHelp))
        helpButton.bezelStyle = .helpButton
        
        backButton.title = "<"; backButton.target = self; backButton.action = #selector(showPreviousPage)
        nextButton.title = ">"; nextButton.target = self; nextButton.action = #selector(showNextPage)
        
        saveButton.title = "Save & Reopen"; saveButton.target = self; saveButton.action = #selector(saveSettings)
        saveButton.bezelStyle = .rounded; saveButton.keyEquivalent = "\r"
        
        bottomButtonStack = NSStackView(views: [resetButton, helpButton, NSView(), backButton, nextButton, saveButton])
        bottomButtonStack.orientation = .horizontal; bottomButtonStack.spacing = 12

        let mainStack = NSStackView(views: [
            titleLabel, subtitleLabel, divider1,
            pageContainerView,
            divider2,
            previewHeader,
            previewView,
            NSView(),
            bottomButtonStack
        ])
        mainStack.orientation = .vertical; mainStack.alignment = .leading; mainStack.spacing = 10
        mainStack.setCustomSpacing(20, after: subtitleLabel)
        mainStack.setCustomSpacing(20, after: pageContainerView)
        mainStack.setCustomSpacing(4, after: previewHeader)

        view.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        pageContainerView.addSubview(page1Stack)
        page1Stack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            divider1.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            divider2.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            pageContainerView.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            bottomButtonStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            previewView.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            
            page1Stack.topAnchor.constraint(equalTo: pageContainerView.topAnchor),
            page1Stack.bottomAnchor.constraint(equalTo: pageContainerView.bottomAnchor),
            page1Stack.leadingAnchor.constraint(equalTo: pageContainerView.leadingAnchor),
            page1Stack.trailingAnchor.constraint(equalTo: pageContainerView.trailingAnchor),
        ])
    }
    
    private func configurePageStack(_ stack: NSStackView) {
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10

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
    
    @objc private func showPreviousPage() {
        if currentPage > 1 {
            let oldPage = currentPage; currentPage -= 1
            transition(to: currentPage, from: oldPage); updatePageVisibility()
        }
    }
    
    @objc private func showNextPage() {
        if currentPage < 3 {
            let oldPage = currentPage; currentPage += 1
            transition(to: currentPage, from: oldPage); updatePageVisibility()
        }
    }
    
    private func stack(for page: Int) -> NSStackView? {
        switch page {
        case 1: return page1Stack; case 2: return page2Stack; case 3: return page3Stack
        default: return nil
        }
    }

    private func transition(to newPage: Int, from oldPage: Int) {
        guard let window = self.view.window,
              let fromView = stack(for: oldPage),
              let toView = stack(for: newPage) else { return }

        // Get the height of the content we are leaving
        let oldContentHeight = fromView.frame.height

        // Set up the page slide transition
        let slideTransition = CATransition()
        slideTransition.duration = 0.3
        slideTransition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        slideTransition.type = .push
        slideTransition.subtype = (newPage > oldPage) ? .fromRight : .fromLeft
        
        // Use an animation group to sync the window resize with the content slide
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = slideTransition.duration
            context.allowsImplicitAnimation = true
            
            // Add the slide animation to the container
            self.pageContainerView.layer?.add(slideTransition, forKey: "pageTransition")
            
            // Perform the view swap
            fromView.removeFromSuperview()
            pageContainerView.addSubview(toView)
            toView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                toView.topAnchor.constraint(equalTo: pageContainerView.topAnchor),
                toView.bottomAnchor.constraint(equalTo: pageContainerView.bottomAnchor),
                toView.leadingAnchor.constraint(equalTo: pageContainerView.leadingAnchor),
                toView.trailingAnchor.constraint(equalTo: pageContainerView.trailingAnchor)
            ])
            
            // Force the whole view controller to lay out immediately to get the new height
            self.view.layoutSubtreeIfNeeded()
            
            let newContentHeight = toView.frame.height
            let deltaHeight = newContentHeight - oldContentHeight

            // If there's a size difference, calculate the new window frame
            if abs(deltaHeight) > 1 {
                var newWindowFrame = window.frame
                newWindowFrame.size.height += deltaHeight
                // Adjust the origin to make the window resize from the top
                newWindowFrame.origin.y -= deltaHeight
                
                // Animate the window to its new frame
                window.animator().setFrame(newWindowFrame, display: true)
            }
        })
    }

    private func updatePageVisibility() {
        backButton.isEnabled = (currentPage != 1); nextButton.isEnabled = (currentPage != 3)
    }

    @objc private func showHelp() {
        let alert = NSAlert(); alert.messageText = "lorem ipsum dolor color amet"
        alert.informativeText = "lorem ipsum dolor color amet im still working on this"
        alert.addButton(withTitle: "OK"); alert.runModal()
    }

    private func loadSettings() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
            applySettings(Settings.defaultSettings()); return
        }
        applySettings(settings)
    }
    
    private func applySettings(_ settings: Settings) {
        activityNameField.stringValue = settings.activityName
        refreshIntervalField.integerValue = settings.refreshInterval
        spotifySwitch.state = settings.enableSpotifyButton ? .on : .off; spotifyButtonField.stringValue = settings.spotifyButtonLabel
        appleMusicSwitch.state = settings.enableAppleMusicButton ? .on : .off; appleMusicButtonField.stringValue = settings.appleMusicButtonLabel
        songlinkSwitch.state = settings.enableSonglinkButton ? .on : .off; songlinkButtonField.stringValue = settings.songlinkButtonLabel
        youtubeMusicSwitch.state = settings.enableYoutubeMusicButton ? .on : .off; youtubeMusicButtonField.stringValue = settings.youtubeMusicButtonLabel
        autoLaunchSwitch.state = settings.enableAutoLaunch ? .on : .off
        detailsStringField.stringValue = settings.detailsString; stateStringField.stringValue = settings.stateString
        largeImageTextField.stringValue = settings.largeImageText; smallImageTextField.stringValue = settings.smallImageText
        smallImageSourceDropdown.selectItem(at: settings.smallImageSource == "albumArt" ? 1 : 0)
        validateButtonSwitches(); updatePreview()
    }
    
    func controlTextDidChange(_ obj: Notification) { updatePreview() }
    @objc private func controlDidChangeValue() { validateButtonSwitches(); updatePreview() }
    
    private func updatePreview() {
        guard isViewLoaded, previewView != nil else { return }
        let currentSettings = captureCurrentSettings()
        let exampleData = (name: "Boom! Boom!", artist: "Roo", album: "Broken")
        previewView.update(with: currentSettings, example: exampleData)
    }
    
    @objc private func validateButtonSwitches() {
        let enabledCount = buttonSwitches.filter { $0.state == .on }.count
        if enabledCount >= 2 {
            for s in buttonSwitches where s.state == .off { s.isEnabled = false }
        } else {
            for s in buttonSwitches { s.isEnabled = true }
        }
    }
    
    private func captureCurrentSettings() -> Settings {
        var interval = refreshIntervalField.integerValue
        if interval < 1 { interval = 1 }; if interval > 15 { interval = 15 }
        return Settings(
            refreshInterval: interval, activityName: activityNameField.stringValue,
            enableSpotifyButton: spotifySwitch.state == .on, spotifyButtonLabel: spotifyButtonField.stringValue,
            enableAppleMusicButton: appleMusicSwitch.state == .on, appleMusicButtonLabel: appleMusicButtonField.stringValue,
            enableSonglinkButton: songlinkSwitch.state == .on, songlinkButtonLabel: songlinkButtonField.stringValue,
            enableYoutubeMusicButton: youtubeMusicSwitch.state == .on, youtubeMusicButtonLabel: youtubeMusicButtonField.stringValue,
            enableAutoLaunch: autoLaunchSwitch.state == .on, detailsString: detailsStringField.stringValue,
            stateString: stateStringField.stringValue, largeImageText: largeImageTextField.stringValue,
            smallImageText: smallImageTextField.stringValue,
            smallImageSource: smallImageSourceDropdown.indexOfSelectedItem == 1 ? "albumArt" : "default"
        )
    }

    @objc private func saveSettings() {
        let currentSettings = captureCurrentSettings()
        do {
            let data = try JSONEncoder().encode(currentSettings)
            try data.write(to: URL(fileURLWithPath: configPath))
            SMLoginItemSetEnabled(appBundleId, currentSettings.enableAutoLaunch)
            restartService(); self.view.window?.close()
        } catch {
            showAlert(title: "Error", text: "Could not save settings: \(error.localizedDescription)")
        }
    }
    
    @objc private func resetSettings() { applySettings(Settings.defaultSettings()) }
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
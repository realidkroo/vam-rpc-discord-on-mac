// PreferencesViewController.swift
import Cocoa
import ServiceManagement
import QuartzCore

// NOTE: struct Settings is in SettingsModel.swift

class CustomButton: NSControl {
    enum Style {
        case primary
        case secondary
        case text
        case circular
    }
    
    var title: String = "" {
        didSet { textLayer.string = title; updateLayer() }
    }
    
    var style: Style = .secondary {
        didSet { setupStyle() }
    }
    
    private let backgroundLayer = CALayer()
    private let textLayer = CATextLayer()
    
    override var isEnabled: Bool {
        didSet { alphaValue = isEnabled ? 1.0 : 0.5 }
    }
    
    override var intrinsicContentSize: NSSize {
        let width = style == .circular ? 24.0 : (textLayer.preferredFrameSize().width + 24)
        return NSSize(width: max(width, 30), height: 26)
    }
    
    init(title: String, style: Style = .secondary) {
        self.title = title
        self.style = style
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupView() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        backgroundLayer.cornerRadius = 6
        layer?.addSublayer(backgroundLayer)
        
        textLayer.string = title
        textLayer.fontSize = 13
        textLayer.alignmentMode = .center
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        textLayer.foregroundColor = NSColor.labelColor.cgColor
        layer?.addSublayer(textLayer)
        
        setupStyle()
        createTrackingArea()
    }
    
    private func setupStyle() {
        backgroundLayer.borderWidth = 1
        
        switch style {
        case .primary:
            backgroundLayer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
            backgroundLayer.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
            textLayer.foregroundColor = NSColor.white.cgColor
        case .secondary:
            backgroundLayer.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
            backgroundLayer.borderColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.3).cgColor
            textLayer.foregroundColor = NSColor.labelColor.cgColor
        case .text:
            backgroundLayer.backgroundColor = NSColor.clear.cgColor
            backgroundLayer.borderColor = NSColor.clear.cgColor
            textLayer.foregroundColor = NSColor.secondaryLabelColor.cgColor
        case .circular:
            backgroundLayer.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
            backgroundLayer.borderColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.3).cgColor
            backgroundLayer.cornerRadius = 12 // Half of intrinsic height roughly
            textLayer.foregroundColor = NSColor.labelColor.cgColor
        }
    }
    
    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
        
        let textHeight: CGFloat = 16
        let yPos = (bounds.height - textHeight) / 2 - 1 // slight adjust
        textLayer.frame = CGRect(x: 0, y: yPos, width: bounds.width, height: textHeight)
    }
    
    private func createTrackingArea() {
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
    }
    
    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            if style == .primary {
                backgroundLayer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
            } else if style != .text {
                backgroundLayer.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
            } else {
                 textLayer.foregroundColor = NSColor.labelColor.cgColor
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        guard isEnabled else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            setupStyle() // Reset to base
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        let originalTransform = layer?.transform ?? CATransform3DIdentity
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.05)
        layer?.transform = CATransform3DScale(originalTransform, 0.95, 0.95, 1.0)
        CATransaction.commit()
        
        // Wait for mouse up to fire action
        let window = self.window
        let eventMask: NSEvent.EventTypeMask = [.leftMouseUp]
        
        window?.trackEvents(matching: eventMask, timeout: 10.0, mode: .eventTracking) { event, stop in
            // Restore scale
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.1)
            self.layer?.transform = originalTransform
            CATransaction.commit()
            
            if let event = event, self.isMousePoint(self.convert(event.locationInWindow, from: nil), in: self.bounds) {
                self.sendAction(self.action, to: self.target)
            }
            stop.pointee = true
        }
    }
}

class CustomDropdown: NSControl {
    private let backgroundLayer = CALayer()
    private let textLayer = CATextLayer()
    private let arrowLayer = CAShapeLayer()
    private var items: [String] = []
    
    var selectedIndex: Int = 0 {
        didSet {
            if selectedIndex < items.count {
                textLayer.string = items[selectedIndex]
            }
        }
    }
    
    var selectedTitle: String? {
        if selectedIndex < items.count { return items[selectedIndex] }
        return nil
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: 140, height: 22)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func addItems(withTitles titles: [String]) {
        items.append(contentsOf: titles)
        if selectedIndex < items.count { textLayer.string = items[selectedIndex] }
    }
    
    func selectItem(at index: Int) {
        guard index >= 0 && index < items.count else { return }
        selectedIndex = index
    }
    
    var indexOfSelectedItem: Int {
        return selectedIndex
    }
    
    private func setupView() {
        wantsLayer = true
        backgroundLayer.cornerRadius = 5
        backgroundLayer.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
        backgroundLayer.borderColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.5).cgColor
        backgroundLayer.borderWidth = 1
        layer?.addSublayer(backgroundLayer)
        
        textLayer.fontSize = 12
        textLayer.foregroundColor = NSColor.labelColor.cgColor
        textLayer.alignmentMode = .left
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        layer?.addSublayer(textLayer)
        
        // Draw Arrow
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 4))
        path.addLine(to: CGPoint(x: 4, y: 0))
        path.addLine(to: CGPoint(x: 8, y: 4))
        
        arrowLayer.path = path
        arrowLayer.strokeColor = NSColor.secondaryLabelColor.cgColor
        arrowLayer.fillColor = nil
        arrowLayer.lineWidth = 1.5
        arrowLayer.lineCap = .round
        layer?.addSublayer(arrowLayer)
    }
    
    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
        textLayer.frame = CGRect(x: 8, y: (bounds.height - 14) / 2 - 1, width: bounds.width - 24, height: 15)
        arrowLayer.position = CGPoint(x: bounds.width - 14, y: bounds.height / 2 - 2)
    }
    
    override func mouseDown(with event: NSEvent) {
        guard isEnabled, !items.isEmpty else { return }
        
        let menu = NSMenu()
        for (index, item) in items.enumerated() {
            let menuItem = NSMenuItem(title: item, action: #selector(menuItemSelected(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = index
            menuItem.state = (index == selectedIndex) ? .on : .off
            menu.addItem(menuItem)
        }
        
        let location = NSPoint(x: 0, y: bounds.height)
        menu.popUp(positioning: menu.item(at: selectedIndex), at: location, in: self)
    }
    
    @objc private func menuItemSelected(_ sender: NSMenuItem) {
        selectedIndex = sender.tag
        sendAction(action, to: target)
    }
}

extension NSView {
    private static var isBlurredKey = "isBlurred"
    
    private var isBlurred: Bool {
        get { objc_getAssociatedObject(self, &Self.isBlurredKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &Self.isBlurredKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    func animateBlurIn(duration: TimeInterval = 0.10) { 
        guard !isBlurred else { return }
        isBlurred = true
        
        if !self.wantsLayer { self.wantsLayer = true }

        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        blurFilter.name = "blur"
        self.layer?.filters = [blurFilter]
        
        let blurAnimation = CABasicAnimation(keyPath: "filters.blur.inputRadius")
        blurAnimation.fromValue = 0
        blurAnimation.toValue = 4
        blurAnimation.duration = duration
        blurAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        blurAnimation.fillMode = .forwards
        blurAnimation.isRemovedOnCompletion = false
        
        self.layer?.add(blurAnimation, forKey: "blurIn")
    }

    func animateBlurOut(duration: TimeInterval = 0.3) {
        guard isBlurred else { return }
        isBlurred = false
        
        let blurAnimation = CABasicAnimation(keyPath: "filters.blur.inputRadius")
        blurAnimation.fromValue = 4
        blurAnimation.toValue = 0
        blurAnimation.duration = duration
        blurAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        blurAnimation.fillMode = .forwards
        blurAnimation.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            self.layer?.filters = nil
            self.layer?.removeAnimation(forKey: "blurIn")
            self.layer?.removeAnimation(forKey: "blurOut")
        }
        self.layer?.add(blurAnimation, forKey: "blurOut")
        CATransaction.commit()
    }
}

class CustomTextField: NSView, NSTextFieldDelegate {
    private let textField = NSTextField()
    
    var stringValue: String {
        get { textField.stringValue }
        set { textField.stringValue = newValue }
    }
    
    weak var delegate: NSTextFieldDelegate? {
        didSet {
            textField.delegate = self
        }
    }
    
    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: 22)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.5).cgColor
        layer?.borderWidth = 1
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
        
        textField.isBezeled = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func controlTextDidChange(_ obj: Notification) {
        let newNotification = Notification(name: obj.name, object: self, userInfo: obj.userInfo)
        delegate?.controlTextDidChange?(newNotification)
    }
}

class CustomSwitch: NSControl {
    var isOn: Bool = false {
        didSet {
            updateState(animated: true)
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            updateState(animated: true)
        }
    }
    
    override var intrinsicContentSize: NSSize { NSSize(width: 40, height: 24) }
    
    private let backgroundLayer = CALayer()
    private let thumbLayer = CALayer()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        
        backgroundLayer.cornerRadius = 12
        layer?.addSublayer(backgroundLayer)
        
        thumbLayer.cornerRadius = 10
        thumbLayer.backgroundColor = NSColor.white.cgColor
        thumbLayer.shadowColor = NSColor.black.cgColor
        thumbLayer.shadowOpacity = 0.2
        thumbLayer.shadowOffset = CGSize(width: 0, height: 1)
        thumbLayer.shadowRadius = 2
        layer?.addSublayer(thumbLayer)
        
        updateState(animated: false)
    }
    
    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
        updateState(animated: false)
    }
    
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        super.mouseDown(with: event)
        self.isOn.toggle()
        sendAction(action, to: target)
    }
    
    private func updateState(animated: Bool) {
        let duration = animated ? 0.2 : 0.0
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        
        let alpha: CGFloat = isEnabled ? 1.0 : 0.4
        
        if isOn {
            backgroundLayer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(alpha).cgColor
            thumbLayer.frame = CGRect(x: bounds.width - 22, y: 2, width: 20, height: 20)
        } else {
            backgroundLayer.backgroundColor = NSColor.systemRed.withAlphaComponent(isEnabled ? 0.6 : 0.3).cgColor
            thumbLayer.frame = CGRect(x: 2, y: 2, width: 20, height: 20)
        }
        thumbLayer.opacity = Float(alpha)
        
        CATransaction.commit()
    }
}

private class PreviewView: NSView {

    let activityLabel = NSTextField(labelWithString: "Listening to Apple Music")
    let songTitleLabel = NSTextField(labelWithString: "Boom! Boom!")
    let artistLabel = NSTextField(labelWithString: "By Roo")
    let albumLabel = NSTextField(labelWithString: "Broken")
    let timestampLabel = NSTextField(labelWithString: "0:01 / 3:45")
    
    let spotifyButton = NSButton()
    let appleMusicButton = NSButton()
    let songlinkButton = NSButton()
    let youtubeMusicButton = NSButton()

    let largeImageView = NSImageView()
    let smallImageView = NSImageView()
    
    private var previousSettings: Settings?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupPreviewUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func formatString(_ template: String, with example: (name: String, artist: String, album: String)) -> String {
        var result = template
        result = result.replacingOccurrences(of: "{name}", with: example.name)
        result = result.replacingOccurrences(of: "{artist}", with: example.artist)
        result = result.replacingOccurrences(of: "{album}", with: example.album)
        return result
    }
    
    func update(with settings: Settings, example: (name: String, artist: String, album: String)) {
        let didToggle = { (old: Bool?, new: Bool) in old != nil && old != new }
        
        activityLabel.stringValue = "Listening to \(formatString(settings.activityName, with: example))"
        songTitleLabel.stringValue = formatString(settings.detailsString, with: example)
        artistLabel.stringValue = "By \(formatString(settings.stateString, with: example))"
        albumLabel.stringValue = formatString(settings.largeImageText, with: example)
        largeImageView.toolTip = formatString(settings.largeImageText, with: example)
        smallImageView.toolTip = formatString(settings.smallImageText, with: example)
        
        if didToggle(previousSettings?.enableSpotifyButton, settings.enableSpotifyButton) {
            animateButtonToggle(button: spotifyButton, isVisible: settings.enableSpotifyButton)
        } else {
            spotifyButton.isHidden = !settings.enableSpotifyButton
        }
        spotifyButton.title = "  \(formatString(settings.spotifyButtonLabel, with: example))  "
        
        if didToggle(previousSettings?.enableAppleMusicButton, settings.enableAppleMusicButton) {
            animateButtonToggle(button: appleMusicButton, isVisible: settings.enableAppleMusicButton)
        } else {
            appleMusicButton.isHidden = !settings.enableAppleMusicButton
        }
        appleMusicButton.title = "  \(formatString(settings.appleMusicButtonLabel, with: example))  "

        if didToggle(previousSettings?.enableSonglinkButton, settings.enableSonglinkButton) {
            animateButtonToggle(button: songlinkButton, isVisible: settings.enableSonglinkButton)
        } else {
            songlinkButton.isHidden = !settings.enableSonglinkButton
        }
        songlinkButton.title = "  \(formatString(settings.songlinkButtonLabel, with: example))  "

        if didToggle(previousSettings?.enableYoutubeMusicButton, settings.enableYoutubeMusicButton) {
            animateButtonToggle(button: youtubeMusicButton, isVisible: settings.enableYoutubeMusicButton)
        } else {
            youtubeMusicButton.isHidden = !settings.enableYoutubeMusicButton
        }
        youtubeMusicButton.title = "  \(formatString(settings.youtubeMusicButtonLabel, with: example))  "

        // Small Image Logic Updated
        smallImageView.isHidden = (settings.smallImageSource == "default")
        
        // Reset styles
        smallImageView.layer?.backgroundColor = nil
        smallImageView.contentTintColor = nil
        smallImageView.layer?.borderWidth = 2
        smallImageView.layer?.cornerRadius = 14
        
        switch settings.smallImageSource {
        case "albumArt", "albumArtAnimated":
            smallImageView.image = NSImage(named: "roo.jpg") // Placeholder
        case "artistArt", "artistArtAnimated":
            smallImageView.image = NSImage(systemSymbolName: "person.crop.circle.fill", accessibilityDescription: nil)
            smallImageView.contentTintColor = .white
            smallImageView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
            smallImageView.layer?.borderWidth = 0
        case "playbackStatus":
            smallImageView.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Playing")
            smallImageView.contentTintColor = .white
            smallImageView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
            smallImageView.layer?.borderWidth = 0
        case "appIcon":
            smallImageView.image = NSImage(systemSymbolName: "applelogo", accessibilityDescription: "Apple Music")
            smallImageView.contentTintColor = .white
            smallImageView.layer?.backgroundColor = NSColor.systemRed.cgColor
            smallImageView.layer?.borderWidth = 0
        default:
            smallImageView.image = nil
        }
        
        self.previousSettings = settings
    }

    private func animateButtonToggle(button: NSButton, isVisible: Bool) {
        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        blurFilter.name = "blur"
        button.layer?.filters = [blurFilter]
        
        let startScale: CGFloat = isVisible ? 0.3 : 1.0
        let endScale: CGFloat = isVisible ? 1.0 : 0.3
        let startOpacity: Float = isVisible ? 0.0 : 1.0
        let endOpacity: Float = isVisible ? 1.0 : 0.0
        
        if isVisible {
            button.isHidden = false
            button.layer?.transform = CATransform3DMakeScale(startScale, startScale, 1)
            button.layer?.opacity = startOpacity
        }
        
        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.toValue = endScale
        
        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.toValue = endOpacity
        
        let blurAnim = CABasicAnimation(keyPath: "filters.blur.inputRadius")
        blurAnim.fromValue = 0
        blurAnim.toValue = 5
        blurAnim.autoreverses = true
        
        let group = CAAnimationGroup()
        group.animations = [scaleAnim, opacityAnim, blurAnim]
        group.duration = 0.30
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            button.layer?.removeAllAnimations()
            button.layer?.filters = nil
            button.layer?.transform = CATransform3DIdentity
            button.layer?.opacity = 1.0
            button.isHidden = !isVisible
        }
        
        button.layer?.add(group, forKey: "buttonToggle")
        CATransaction.commit()
    }

    private func setupPreviewUI() {
        
        let usernameLabel = createLabel("realidkroo", font: .systemFont(ofSize: 15, weight: .semibold))
        configureLabel(activityLabel, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        configureLabel(songTitleLabel, font: .systemFont(ofSize: 13, weight: .semibold))
        configureLabel(artistLabel, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        configureLabel(albumLabel, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        configureLabel(timestampLabel, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        
        activityLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        songTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        artistLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        albumLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        let userAvatar = createPlaceholderImageView(imageName: "roo.jpg", cornerRadius: 16)
        largeImageView.image = NSImage(named: "asltolfo.png")
        configurePlaceholder(for: largeImageView, cornerRadius: 8)
        
        smallImageView.image = NSImage(named: "roo.jpg")
        configurePlaceholder(for: smallImageView, cornerRadius: 12)
        smallImageView.layer?.borderWidth = 2
        smallImageView.layer?.borderColor = NSColor.black.withAlphaComponent(0.4).cgColor

        let micIcon = createIcon(systemName: "mic.fill")
        let headphonesIcon = createIcon(systemName: "headphones")
        let settingsIcon = createIcon(systemName: "gearshape.fill")
        
        spotifyButton.title = "  ♫ Find On Spotify  "
        appleMusicButton.title = "  ♫ Open on  Music  "
        songlinkButton.title = "  ♫ Find on Songlink  "
        youtubeMusicButton.title = "  ♫ Find on YT Music  "
        
        configurePreviewButton(spotifyButton)
        configurePreviewButton(appleMusicButton)
        configurePreviewButton(songlinkButton)
        configurePreviewButton(youtubeMusicButton)

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

        let topInfoStack = NSStackView(views: [usernameLabel, activityLabel])
        topInfoStack.orientation = .vertical; topInfoStack.alignment = .leading; topInfoStack.spacing = 2

        let iconsStack = NSStackView(views: [micIcon, headphonesIcon])
        
        let topSection = NSStackView(views: [userAvatar, topInfoStack, NSView(), iconsStack])
        topSection.spacing = 8; topSection.alignment = .top
        
        let buttonsOnlyStack = NSStackView(views: [appleMusicButton, spotifyButton, songlinkButton, youtubeMusicButton])
        buttonsOnlyStack.spacing = 8
        buttonsOnlyStack.distribution = .fillProportionally
        
        let leftSpacer = NSView()
        let rightSpacer = NSView()
        let centeredButtonContainer = NSStackView(views: [leftSpacer, buttonsOnlyStack, rightSpacer])
        centeredButtonContainer.distribution = .fill
        
        leftSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        rightSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        leftSpacer.widthAnchor.constraint(equalTo: rightSpacer.widthAnchor).isActive = true
        
        let songInfoStack = NSStackView(views: [songTitleLabel, artistLabel, albumLabel, progressStack, centeredButtonContainer])
        songInfoStack.orientation = .vertical; songInfoStack.alignment = .leading; songInfoStack.spacing = 2
        songInfoStack.setCustomSpacing(6, after: albumLabel)
        songInfoStack.setCustomSpacing(8, after: progressStack)
        
        let mainContentStack = NSStackView(views: [largeImageView, songInfoStack])
        mainContentStack.spacing = 10
        songInfoStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
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
        addSubview(smallImageView, positioned: .above, relativeTo: largeImageView)
        background.addSubview(settingsIcon)

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
            
            largeImageView.widthAnchor.constraint(equalToConstant: 100),
            largeImageView.heightAnchor.constraint(equalToConstant: 100),
            
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            progressFill.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressBar.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBar.bottomAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressBar.widthAnchor, multiplier: 0.1),
            
            smallImageView.widthAnchor.constraint(equalToConstant: 28),
            smallImageView.heightAnchor.constraint(equalToConstant: 28),
            smallImageView.trailingAnchor.constraint(equalTo: largeImageView.trailingAnchor, constant: 7),
            smallImageView.bottomAnchor.constraint(equalTo: largeImageView.bottomAnchor, constant: 7),

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
        let label = NSTextField(labelWithString: text)
        configureLabel(label, font: font, color: color)
        return label
    }

    private func configureLabel(_ label: NSTextField, font: NSFont, color: NSColor = .labelColor) {
        label.wantsLayer = true
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
        
        button.cell?.lineBreakMode = .byTruncatingTail
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
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
    
    private var typingDebounceTimer: Timer?
    private var sliderDebounceTimer: Timer?

    // Page 1
    private let activityTypeDropdown = CustomDropdown(frame: .zero)
    private let activityNameField = CustomTextField()
    private let refreshIntervalSlider = NSSlider(value: 5, minValue: 1, maxValue: 15, target: nil, action: nil)
    private let refreshIntervalValueLabel = NSTextField(labelWithString: "5s")
    private let spotifySwitch = CustomSwitch()
    private let spotifyButtonField = CustomTextField()
    private let appleMusicSwitch = CustomSwitch()
    private let appleMusicButtonField = CustomTextField()

    // Page 2
    private let songlinkSwitch = CustomSwitch()
    private let songlinkButtonField = CustomTextField()
    private let youtubeMusicSwitch = CustomSwitch()
    private let youtubeMusicButtonField = CustomTextField()
    private let autoLaunchSwitch = CustomSwitch()
    
    // Page 3
    private let detailsStringField = CustomTextField()
    private let stateStringField = CustomTextField()
    private let largeImageTextField = CustomTextField()
    private let smallImageTextField = CustomTextField()
    private let smallImageSourceDropdown = CustomDropdown(frame: .zero)

    private var buttonSwitches: [CustomSwitch] { [spotifySwitch, appleMusicSwitch, songlinkSwitch, youtubeMusicSwitch] }

    private var page1Stack: NSStackView!
    private var page2Stack: NSStackView!
    private var page3Stack: NSStackView!
    
    private let backButton = CustomButton(title: "<", style: .secondary)
    private let nextButton = CustomButton(title: ">", style: .secondary)
    private let saveButton = CustomButton(title: "Save & Reopen", style: .primary)
    
    private var currentPage = 1
    
    private var pageContainerView: NSView!
    
    private var previewView: PreviewView!
    private var bottomButtonStack: NSStackView!
    private var hasUISetup = false
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 400))
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12.0
        self.view = visualEffectView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.window?.alphaValue = 0
        setupUI()
        loadSettings()
        updatePageVisibility()
        updatePreview()
        
        view.layoutSubtreeIfNeeded()
        
        if let window = view.window {
            if let mainStack = view.subviews.first(where: { $0 is NSStackView }) as? NSStackView {
                let fittingSize = mainStack.fittingSize
                let requiredHeight = fittingSize.height + 40
                var newFrame = window.frame
                let oldHeight = newFrame.height
                newFrame.origin.y += (oldHeight - requiredHeight)
                newFrame.size.height = requiredHeight
                window.setFrame(newFrame, display: false)
                window.center()
            }
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if !hasUISetup {
            hasUISetup = true
            view.window?.alphaValue = 1
            view.window?.styleMask.remove(.resizable)
        }
    }
    
    private func setupUI() {
        let allTextFields: [CustomTextField] = [activityNameField, spotifyButtonField, appleMusicButtonField, songlinkButtonField, youtubeMusicButtonField, detailsStringField, stateStringField, largeImageTextField, smallImageTextField]
        allTextFields.forEach {
            $0.delegate = self
            $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        
        let allSwitches = buttonSwitches + [autoLaunchSwitch]
        allSwitches.forEach { s in
            s.target = self
            s.action = #selector(controlDidChangeValue(_:)) // UPDATED SELECTOR
        }
        activityTypeDropdown.target = self; activityTypeDropdown.action = #selector(controlDidChangeValue(_:)) // UPDATED SELECTOR
        smallImageSourceDropdown.target = self; smallImageSourceDropdown.action = #selector(controlDidChangeValue(_:)) // UPDATED SELECTOR
        
        page1Stack = NSStackView()
        let activityHeader = createLabel("Activity", font: .systemFont(ofSize: 16, weight: .semibold))
        let activitySubtitle = createLabel("Select the activity type, you can only choose 1 of 2", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        activityTypeDropdown.addItems(withTitles: ["Listening", " ( Coming Soon )"])
        let activityNameLabel = createLabel("Activity Name (This will be displayed after activity type)", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        let optionsHeader = createLabel("Options", font: .systemFont(ofSize: 16, weight: .semibold))
        let refreshLabel = createLabel("Refresh Interval (seconds)", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        refreshIntervalSlider.target = self
        refreshIntervalSlider.action = #selector(sliderDidChangeValue)
        refreshIntervalSlider.wantsLayer = true
        refreshIntervalValueLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        refreshIntervalValueLabel.textColor = .secondaryLabelColor
        refreshIntervalValueLabel.wantsLayer = true
        let sliderStack = NSStackView(views: [refreshIntervalSlider, refreshIntervalValueLabel])
        sliderStack.spacing = 8
        refreshIntervalValueLabel.widthAnchor.constraint(equalToConstant: 24).isActive = true
        let spotifyStack = createSwitchStack(label: "Enable find on spotify Button?", sublabel: "If Enabled, Set the Button Name", switchView: spotifySwitch, textField: spotifyButtonField)
        let appleMusicStack = createSwitchStack(label: "Enable Open On Apple Music Button?", sublabel: "If Enabled, Set the Button Name", switchView: appleMusicSwitch, textField: appleMusicButtonField)
        
        page1Stack.addArrangedSubview(activityHeader)
        page1Stack.addArrangedSubview(activitySubtitle)
        page1Stack.addArrangedSubview(activityTypeDropdown)
        page1Stack.addArrangedSubview(activityNameLabel)
        page1Stack.addArrangedSubview(activityNameField)
        activityNameField.widthAnchor.constraint(equalTo: page1Stack.widthAnchor).isActive = true
        page1Stack.addArrangedSubview(optionsHeader)
        page1Stack.addArrangedSubview(refreshLabel)
        page1Stack.addArrangedSubview(sliderStack)
        page1Stack.addArrangedSubview(spotifyStack)
        spotifyStack.widthAnchor.constraint(equalTo: page1Stack.widthAnchor).isActive = true
        page1Stack.addArrangedSubview(appleMusicStack)
        appleMusicStack.widthAnchor.constraint(equalTo: page1Stack.widthAnchor).isActive = true
        configurePageStack(page1Stack)

        page2Stack = NSStackView()
        let linksHeader = createLabel("Link Buttons", font: .systemFont(ofSize: 16, weight: .semibold))
        let songlinkStack = createSwitchStack(label: "Enable Open on Songlink Button?", sublabel: "If Enabled, Set the Button Name", switchView: songlinkSwitch, textField: songlinkButtonField)
        let youtubeMusicStack = createSwitchStack(label: "Enable Open On Youtube Music Button?", sublabel: "If Enabled, Set the Button Name", switchView: youtubeMusicSwitch, textField: youtubeMusicButtonField)
        let generalHeader = createLabel("General", font: .systemFont(ofSize: 16, weight: .semibold))
        let autoLaunchStack = createSwitchStack(label: "Enable Auto open app when Login?", sublabel: "Automatically starts VAM-RPC when you log in.", switchView: autoLaunchSwitch)
        
        page2Stack.addArrangedSubview(linksHeader)
        page2Stack.addArrangedSubview(songlinkStack)
        songlinkStack.widthAnchor.constraint(equalTo: page2Stack.widthAnchor).isActive = true
        page2Stack.addArrangedSubview(youtubeMusicStack)
        youtubeMusicStack.widthAnchor.constraint(equalTo: page2Stack.widthAnchor).isActive = true
        page2Stack.addArrangedSubview(generalHeader)
        page2Stack.addArrangedSubview(autoLaunchStack)
        autoLaunchStack.widthAnchor.constraint(equalTo: page2Stack.widthAnchor).isActive = true
        configurePageStack(page2Stack)
        
        page3Stack = NSStackView()
        let stringHeader = createLabel("String Customisations", font: .systemFont(ofSize: 16, weight: .semibold))
        let stringSublabel = createLabel("Use {name}, {artist}, and {album} as placeholders.", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        let imageHeader = createLabel("Image Customisations", font: .systemFont(ofSize: 16, weight: .semibold))
        
        smallImageSourceDropdown.addItems(withTitles: [
            "Turn It Off",
            "Use Music Artwork",
            "Use Artist Artwork",
            "Show Playback Status",
            "Show Apple Music Logo",
            "Artist Artwork (Experimental)",
            "Music Artwork (Experimental)"
        ])
        
        let detailsStack = createFieldStack(label: "Details String", textField: detailsStringField)
        let stateStack = createFieldStack(label: "State String", textField: stateStringField)
        let largeImageStack = createFieldStack(label: "Large Image Hover Text", textField: largeImageTextField)
        let smallImageStack = createFieldStack(label: "Small Image Hover Text", textField: smallImageTextField)
        let smallImageSourceStack = createFieldStack(label: "Small Image Source (Circle)", popup: smallImageSourceDropdown)
        
        page3Stack.addArrangedSubview(stringHeader)
        page3Stack.addArrangedSubview(stringSublabel)
        page3Stack.addArrangedSubview(detailsStack)
        detailsStack.widthAnchor.constraint(equalTo: page3Stack.widthAnchor).isActive = true
        page3Stack.addArrangedSubview(stateStack)
        stateStack.widthAnchor.constraint(equalTo: page3Stack.widthAnchor).isActive = true
        page3Stack.addArrangedSubview(largeImageStack)
        largeImageStack.widthAnchor.constraint(equalTo: page3Stack.widthAnchor).isActive = true
        page3Stack.addArrangedSubview(smallImageStack)
        smallImageStack.widthAnchor.constraint(equalTo: page3Stack.widthAnchor).isActive = true
        page3Stack.addArrangedSubview(imageHeader)
        page3Stack.addArrangedSubview(smallImageSourceStack)
        smallImageSourceStack.widthAnchor.constraint(equalTo: page3Stack.widthAnchor).isActive = true
        configurePageStack(page3Stack)

        let titleLabel = createLabel("Settings", font: .systemFont(ofSize: 28, weight: .bold))
        let subtitleLabel = createLabel("Apple music Listening status for your discord in your mac.", font: .systemFont(ofSize: 14), color: .secondaryLabelColor)
        let divider1 = NSBox(); divider1.boxType = .separator
        
        let divider2 = NSBox(); divider2.boxType = .separator
        let previewHeader = createLabel("Preview ( Beta )", font: .systemFont(ofSize: 16, weight: .semibold))
        previewView = PreviewView()
        
        pageContainerView = NSView()
        pageContainerView.wantsLayer = true
        
        let resetButton = CustomButton(title: "Reset", style: .text)
        resetButton.target = self
        resetButton.action = #selector(resetSettings)
        
        let helpButton = CustomButton(title: "?", style: .circular)
        helpButton.target = self
        helpButton.action = #selector(showHelp)
        
        backButton.target = self; backButton.action = #selector(showPreviousPage)
        nextButton.target = self; nextButton.action = #selector(showNextPage)
        
        saveButton.target = self; saveButton.action = #selector(saveSettings)
        
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
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 35),
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
            stack.setCustomSpacing(4, after: stack.arrangedSubviews[0]); stack.setCustomSpacing(12, after: stack.arrangedSubviews[1])
            stack.setCustomSpacing(4, after: stack.arrangedSubviews[2]); stack.setCustomSpacing(24, after: stack.arrangedSubviews[4])
            stack.setCustomSpacing(4, after: stack.arrangedSubviews[5]); stack.setCustomSpacing(12, after: stack.arrangedSubviews[6])
            stack.setCustomSpacing(24, after: stack.arrangedSubviews[7]); stack.setCustomSpacing(16, after: stack.arrangedSubviews[8])
        } else if stack === page2Stack {
            stack.setCustomSpacing(4, after: stack.arrangedSubviews[0]); stack.setCustomSpacing(24, after: stack.arrangedSubviews[2])
            stack.setCustomSpacing(4, after: stack.arrangedSubviews[3])
        } else if stack === page3Stack {
            stack.setCustomSpacing(4, after: stack.arrangedSubviews[0]); stack.setCustomSpacing(24, after: stack.arrangedSubviews[1])
            stack.setCustomSpacing(16, after: stack.arrangedSubviews[5])
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

        let oldContentHeight = fromView.frame.height
        let duration: TimeInterval = 0.30

        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        blurFilter.name = "blur"
        self.pageContainerView.layer?.filters = [blurFilter]

        let blurAnimation = CABasicAnimation(keyPath: "filters.blur.inputRadius")
        blurAnimation.fromValue = 0
        blurAnimation.toValue = 8
        blurAnimation.duration = duration
        blurAnimation.autoreverses = true
        blurAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let crossfadeTransition = CATransition()
        crossfadeTransition.duration = duration
        crossfadeTransition.type = .fade
        
        self.pageContainerView.layer?.shouldRasterize = true
        self.pageContainerView.layer?.rasterizationScale = window.backingScaleFactor
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.allowsImplicitAnimation = true
            
            self.pageContainerView.layer?.add(crossfadeTransition, forKey: "pageTransition")
            self.pageContainerView.layer?.add(blurAnimation, forKey: "blurTransition")
            
            fromView.removeFromSuperview()
            self.pageContainerView.addSubview(toView)
            toView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                toView.topAnchor.constraint(equalTo: self.pageContainerView.topAnchor),
                toView.bottomAnchor.constraint(equalTo: self.pageContainerView.bottomAnchor),
                toView.leadingAnchor.constraint(equalTo: self.pageContainerView.leadingAnchor),
                toView.trailingAnchor.constraint(equalTo: self.pageContainerView.trailingAnchor)
            ])
            
            self.view.layoutSubtreeIfNeeded()
            
            let newContentHeight = toView.frame.height
            let deltaHeight = newContentHeight - oldContentHeight

            if abs(deltaHeight) > 1 {
                var newWindowFrame = window.frame
                newWindowFrame.size.height += deltaHeight
                newWindowFrame.origin.y -= deltaHeight
                
                window.animator().setFrame(newWindowFrame, display: true)
            }
        }, completionHandler: {
            self.pageContainerView.layer?.filters = nil
            self.pageContainerView.layer?.shouldRasterize = false
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
            applySettings(Settings.defaultSettings())
            return
        }
        applySettings(settings)
    }
    
    private func applySettings(_ settings: Settings) {
        activityNameField.stringValue = settings.activityName
        refreshIntervalSlider.integerValue = settings.refreshInterval
        spotifySwitch.isOn = settings.enableSpotifyButton; spotifyButtonField.stringValue = settings.spotifyButtonLabel
        appleMusicSwitch.isOn = settings.enableAppleMusicButton; appleMusicButtonField.stringValue = settings.appleMusicButtonLabel
        songlinkSwitch.isOn = settings.enableSonglinkButton; songlinkButtonField.stringValue = settings.songlinkButtonLabel
        youtubeMusicSwitch.isOn = settings.enableYoutubeMusicButton; youtubeMusicButtonField.stringValue = settings.youtubeMusicButtonLabel
        autoLaunchSwitch.isOn = settings.enableAutoLaunch
        detailsStringField.stringValue = settings.detailsString; stateStringField.stringValue = settings.stateString
        largeImageTextField.stringValue = settings.largeImageText; smallImageTextField.stringValue = settings.smallImageText
        
        var index = 0
        if settings.smallImageSource == "albumArt" { index = 1 }
        else if settings.smallImageSource == "artistArt" { index = 2 }
        else if settings.smallImageSource == "playbackStatus" { index = 3 }
        else if settings.smallImageSource == "appIcon" { index = 4 }
        else if settings.smallImageSource == "artistArtAnimated" { index = 5 }
        else if settings.smallImageSource == "albumArtAnimated" { index = 6 }
        smallImageSourceDropdown.selectItem(at: index)
    }
    
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? CustomTextField, hasUISetup else { return }
        
        typingDebounceTimer?.invalidate()
        let exampleData = (name: "Boom! Boom!", artist: "Roo", album: "Broken")
        let targetView: NSView
        
        switch textField {
        case activityNameField:
            targetView = previewView.activityLabel
            previewView.activityLabel.stringValue = "Listening to \(previewView.formatString(textField.stringValue, with: exampleData))"
        case spotifyButtonField:
            targetView = previewView.spotifyButton
            previewView.spotifyButton.title = "  \(previewView.formatString(textField.stringValue, with: exampleData))  "
        case appleMusicButtonField:
            targetView = previewView.appleMusicButton
            previewView.appleMusicButton.title = "  \(previewView.formatString(textField.stringValue, with: exampleData))  "
        case songlinkButtonField:
            targetView = previewView.songlinkButton
            previewView.songlinkButton.title = "  \(previewView.formatString(textField.stringValue, with: exampleData))  "
        case youtubeMusicButtonField:
            targetView = previewView.youtubeMusicButton
            previewView.youtubeMusicButton.title = "  \(previewView.formatString(textField.stringValue, with: exampleData))  "
        case detailsStringField:
            targetView = previewView.songTitleLabel
            previewView.songTitleLabel.stringValue = previewView.formatString(textField.stringValue, with: exampleData)
        case stateStringField:
            targetView = previewView.artistLabel
            previewView.artistLabel.stringValue = "By \(previewView.formatString(textField.stringValue, with: exampleData))"
        case largeImageTextField:
            targetView = previewView.albumLabel
            let formattedText = previewView.formatString(textField.stringValue, with: exampleData)
            previewView.albumLabel.stringValue = formattedText
            previewView.largeImageView.toolTip = formattedText
        case smallImageTextField:
            targetView = previewView.smallImageView
            previewView.smallImageView.toolTip = previewView.formatString(textField.stringValue, with: exampleData)
        default:
            return
        }
        
        targetView.animateBlurIn()
        typingDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
            targetView.animateBlurOut()
        }
    }
    
    // WARNING UPDATED CONTROL DID CHANGE VALUE
    @objc private func controlDidChangeValue(_ sender: AnyObject?) {
        if let dropdown = sender as? CustomDropdown, dropdown === smallImageSourceDropdown {
            // 5 6 EXPERIMENTAL OPTIONS
            if [5, 6].contains(dropdown.indexOfSelectedItem) {
                showExperimentalWarning()
            }
        }
        
        validateButtonSwitches()
        updatePreview()
    }
    
    private func showExperimentalWarning() {
        let alert = NSAlert()
        alert.messageText = "Experimental Feature"
        alert.informativeText = "Warning: This can cause the RPC to crash or become unstable. You might need to add your own API."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Documentation")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            // GITHUB URL REPLACE IT FOR DOCS #1
            if let url = URL(string: "https://github.com/idkroo/VAM-RPC") { 
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc private func sliderDidChangeValue(_ sender: NSSlider) {
        sliderDebounceTimer?.invalidate()
        let roundedValue = round(sender.doubleValue)
        sender.doubleValue = roundedValue
        
        refreshIntervalValueLabel.stringValue = "\(sender.integerValue)s"
        refreshIntervalValueLabel.animateBlurIn()
        
        sliderDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in 
            self?.refreshIntervalValueLabel.animateBlurOut()
        }
    }
    
    private func updatePreview() {
        guard hasUISetup, previewView != nil else { return }
        let currentSettings = captureCurrentSettings()
        refreshIntervalValueLabel.stringValue = "\(currentSettings.refreshInterval)s"
        
        let exampleData = (name: "Boom! Boom!", artist: "Roo", album: "Broken")
        previewView.update(with: currentSettings, example: exampleData)
    }
    
    @objc private func validateButtonSwitches() {
        let enabledCount = buttonSwitches.filter { $0.isOn }.count
        if enabledCount >= 2 {
            for s in buttonSwitches where !s.isOn { s.isEnabled = false }
        } else {
            for s in buttonSwitches { s.isEnabled = true }
        }
    }
    
    private func captureCurrentSettings() -> Settings {
        let interval = refreshIntervalSlider.integerValue
        
        let sourceIndex = smallImageSourceDropdown.indexOfSelectedItem
        var sourceString = "default"
        if sourceIndex == 1 { sourceString = "albumArt" }
        else if sourceIndex == 2 { sourceString = "artistArt" }
        else if sourceIndex == 3 { sourceString = "playbackStatus" }
        else if sourceIndex == 4 { sourceString = "appIcon" }
        else if sourceIndex == 5 { sourceString = "artistArtAnimated" }
        else if sourceIndex == 6 { sourceString = "albumArtAnimated" }
        
        return Settings(
            refreshInterval: interval, activityName: activityNameField.stringValue,
            enableSpotifyButton: spotifySwitch.isOn, spotifyButtonLabel: spotifyButtonField.stringValue,
            enableAppleMusicButton: appleMusicSwitch.isOn, appleMusicButtonLabel: appleMusicButtonField.stringValue,
            enableSonglinkButton: songlinkSwitch.isOn, songlinkButtonLabel: songlinkButtonField.stringValue,
            enableYoutubeMusicButton: youtubeMusicSwitch.isOn, youtubeMusicButtonLabel: youtubeMusicButtonField.stringValue,
            enableAutoLaunch: autoLaunchSwitch.isOn,
            
            // NEW FIELDS (Defaults for Legacy)
            showWhenHovering: true, 
            
            detailsString: detailsStringField.stringValue,
            stateString: stateStringField.stringValue,
            largeImageText: largeImageTextField.stringValue,
            smallImageText: smallImageTextField.stringValue,
            
            // NEW FIELD
            thirdString: "{name}-{album}",
            
            smallImageSource: sourceString,
            
            // NEW FIELDS
            enableSmallImage: true,
            spinningSmallImage: false,
            bigImageType: "Album Art",
            enablePauseTimestamp: true,
            timestampType: "Elapsed",
            
            customSpinnerApiUrl: "https://able-pig-53.deno.dev"
        )
    }

    @objc private func saveSettings() {
        let currentSettings = captureCurrentSettings()
        do {
            let data = try JSONEncoder().encode(currentSettings)
            try data.write(to: URL(fileURLWithPath: configPath))
            if #available(macOS 13.0, *) {
                let service = SMAppService.agent(plistName: plistName)
                if currentSettings.enableAutoLaunch {
                    try? service.register()
                } else {
                    try? service.unregister()
                }
            } else {
                SMLoginItemSetEnabled(appBundleId as CFString, currentSettings.enableAutoLaunch)
            }
            
            restartService()
            self.view.window?.close()

        } catch {
            showAlert(title: "Error", text: "Could not save settings: \(error.localizedDescription)")
        }
    }
    
    @objc private func resetSettings() {
        applySettings(Settings.defaultSettings())
        updatePreview()
    }
    private func restartService() {
        _ = runShellCommand("/bin/launchctl", arguments: ["unload", plistPath])
        Thread.sleep(forTimeInterval: 0.1)
        _ = runShellCommand("/bin/launchctl", arguments: ["load", plistPath])
    }
    private func runShellCommand(_ command: String, arguments: [String]) -> String? { let task = Process(); task.executableURL = URL(fileURLWithPath: command); task.arguments = arguments; let pipe = Pipe(); task.standardOutput = pipe; try? task.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); return String(data: data, encoding: .utf8) }
    private func showAlert(title: String, text: String) { let alert = NSAlert(); alert.messageText = title; alert.informativeText = text; alert.runModal() }
    private func createLabel(_ text: String, font: NSFont, color: NSColor = .labelColor) -> NSTextField { let label = NSTextField(labelWithString: text); label.font = font; label.textColor = color; return label }
    
    private func createFieldStack(label: String, textField: CustomTextField) -> NSStackView {
        let labelView = createLabel(label, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        let stack = NSStackView(views: [labelView, textField]);
        stack.orientation = .vertical;
        stack.alignment = .leading;
        stack.spacing = 4
        textField.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }
    
    private func createFieldStack(label: String, popup: CustomDropdown) -> NSStackView {
        let labelView = createLabel(label, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        let stack = NSStackView(views: [labelView, popup]);
        stack.orientation = .vertical;
        stack.alignment = .leading;
        stack.spacing = 4
        return stack
    }

    private func createSwitchStack(label: String, sublabel: String, switchView: CustomSwitch, textField: CustomTextField? = nil) -> NSStackView {
        let labelView = createLabel(label, font: .systemFont(ofSize: 13, weight: .medium))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let headerStack = NSStackView(views: [labelView, spacer, switchView])
        headerStack.orientation = .horizontal
        
        let subLabelView = createLabel(sublabel, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        var views: [NSView] = [headerStack, subLabelView]
        if let textField = textField {
            views.append(textField)
        }
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.setCustomSpacing(8, after: headerStack)
        
        textField?.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        return stack
    }
}
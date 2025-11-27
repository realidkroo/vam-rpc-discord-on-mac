import Cocoa

protocol SidebarDelegate: AnyObject {
    func didSelectPage(index: Int)
    func openLegacy()
    func toggleCollapse()
}

// Helper class to force top-left coordinate system
class FlippedView: NSView {
    override var isFlipped: Bool { return true }
}

class SidebarView: NSView {
    
    weak var delegate: SidebarDelegate?
    private var isCollapsed = false
    
    // Force (0,0) to be Top-Left for the Sidebar itself
    override var isFlipped: Bool { return true }
    
    // --- UI Elements ---
    private let backgroundLayer = CALayer()
    private let indicatorLayer = CALayer()
    
    // Header
    private let appIcon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    
    // Navigation
    private let stackView = NSStackView()
    private let scroll = NSScrollView()
    private let documentContainer = FlippedView()
    
    // Bottom
    private let collapseBtn = NSButton()
    
    private var sectionHeaders: [SidebarSectionHeader] = []
    private var buttons: [SidebarButton] = []
    private var currentSelectedButton: SidebarButton?
    // Keep references to any manual spacers so we can hide them when collapsed
    private var sectionSpacers: [(view: NSView, height: NSLayoutConstraint, original: CGFloat)] = []
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        backgroundLayer.backgroundColor = NSColor(white: 0.10, alpha: 1.0).cgColor
        layer?.addSublayer(backgroundLayer)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
        
        // 1. Bottom Button (Pinned Bottom-Left)
        collapseBtn.frame = CGRect(x: 20, y: bounds.height - 50, width: 28, height: 28)
        
        // 2. Header Layout - EXACT FINDER POSITIONING
        // Finder uses 68pt from top for first item below traffic lights
        let headerY: CGFloat = 68
        
        if isCollapsed {
            // Center Icon
            appIcon.frame = CGRect(x: (bounds.width - 36)/2, y: headerY, width: 36, height: 36)
            titleLabel.alphaValue = 0
        } else {
            // Left Icon (20pt from left, matching Finder)
            appIcon.frame = CGRect(x: 20, y: headerY, width: 40, height: 40)
            
            // Title next to icon
            titleLabel.frame = CGRect(x: 70, y: headerY + 8, width: bounds.width - 90, height: 24)
            titleLabel.alphaValue = 1
        }
        
        // 3. Update Selection Indicator Frame
        if let btn = currentSelectedButton {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            indicatorLayer.frame = calculateIndicatorFrame(for: btn)
            CATransaction.commit()
        }
    }
    
    private func setupUI() {
        // Header
        appIcon.image = NSImage(named: "AppIcon") ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
        appIcon.wantsLayer = true
        
        titleLabel.stringValue = "VAM-RPC"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        
        addSubview(appIcon)
        addSubview(titleLabel)
        
        // --- Scroll & Stack Setup ---
        
        // Stack View
        // Controls vertical spacing between every arranged item.
        // Adjust `stackView.spacing` to change uniform spacing (e.g., 6).
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.wantsLayer = true
        
        // Indicator
        indicatorLayer.backgroundColor = NSColor(white: 0.25, alpha: 1.0).cgColor
        indicatorLayer.cornerRadius = 6
        stackView.layer?.insertSublayer(indicatorLayer, at: 0)
        
        // Document Container
        documentContainer.translatesAutoresizingMaskIntoConstraints = false
        documentContainer.addSubview(stackView)
        
        // Scroll View
        scroll.drawsBackground = false
        scroll.documentView = documentContainer
        scroll.hasVerticalScroller = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(scroll)
        
        // Collapse Button
        collapseBtn.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Collapse")
        collapseBtn.contentTintColor = .white
        collapseBtn.isBordered = false
        collapseBtn.bezelStyle = .regularSquare
        collapseBtn.target = self
        collapseBtn.action = #selector(onCollapse)
        addSubview(collapseBtn)
        
        // --- Constraints ---
        NSLayoutConstraint.activate([
            // Scroll starts below header with spacing
            scroll.topAnchor.constraint(equalTo: appIcon.bottomAnchor, constant: 24),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -70),
            
            // Stack pinned to top
            stackView.topAnchor.constraint(equalTo: documentContainer.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: documentContainer.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: documentContainer.trailingAnchor),
            
            // Container sizing
            documentContainer.widthAnchor.constraint(equalTo: scroll.widthAnchor),
            documentContainer.heightAnchor.constraint(equalTo: stackView.heightAnchor)
        ])
        
        // Populate
        // NOTE: to add a custom spacer before a specific section (for example
        // before "App Info"), insert an arranged spacer view like this:
        // let spacer = NSView()
        // spacer.translatesAutoresizingMaskIntoConstraints = false
        // spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        // stackView.addArrangedSubview(spacer)
        addSection("Looks & Home")
        addButton("Preview", icon: "eye.fill", index: 0)
        // spacer between header groups
        addSectionSpacer(42)

        addSection("Settings")
        addButton("App", icon: "gearshape.fill", index: 1)
        addButton("RPC Settings", icon: "slider.horizontal.3", index: 2)
        addButton("Buttons & Integrations", icon: "link", index: 3)
        addButton("Actions", icon: "command", index: 4)
        addButton("Experimental Settings", icon: "flask.fill", index: 5)
        addSectionSpacer(42)

        addSection("App Info")
        addButton("Credits", icon: "person.2.fill", index: 6)
        addButton("About app", icon: "info.circle", index: 7)
        addSectionSpacer(42)
        addSection("Misc")
        addLegacyButton()
        
        // Initial Selection
        if let first = buttons.first {
            currentSelectedButton = first
            DispatchQueue.main.async {
                self.indicatorLayer.frame = self.calculateIndicatorFrame(for: first)
            }
        }
    }
    
    // --- Indicator Logic ---
    
    private func calculateIndicatorFrame(for btn: SidebarButton) -> CGRect {
        let btnFrame = btn.frame
        
        if isCollapsed {
            // Square Centered
            let size: CGFloat = 36
            let x = (bounds.width - size) / 2
            let y = btnFrame.origin.y + (btnFrame.height - size) / 2
            return CGRect(x: x, y: y, width: size, height: size)
        } else {
            // Rectangle with Finder-style padding
            return CGRect(x: 12, y: btnFrame.origin.y + 2, width: bounds.width - 24, height: btnFrame.height - 4)
        }
    }
    
    private func moveIndicator(to btn: SidebarButton) {
        let newFrame = calculateIndicatorFrame(for: btn)
        
        let anim = CASpringAnimation(keyPath: "bounds")
        anim.damping = 16; anim.mass = 1; anim.stiffness = 150
        anim.duration = anim.settlingDuration
        
        let posAnim = CASpringAnimation(keyPath: "position")
        posAnim.damping = 16; posAnim.mass = 1; posAnim.stiffness = 150
        posAnim.duration = posAnim.settlingDuration
        
        indicatorLayer.frame = newFrame
        indicatorLayer.add(anim, forKey: "bounds")
        indicatorLayer.add(posAnim, forKey: "position")
    }
    
    // --- Item Helpers ---
    
    private func addSection(_ text: String) {
        let header = SidebarSectionHeader(text: text)
        stackView.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        sectionHeaders.append(header)
    }

    // Create a fixed-height spacer and keep a reference so we can hide it
    // when the sidebar is collapsed.
    private func addSectionSpacer(_ height: CGFloat) {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        let h = spacer.heightAnchor.constraint(equalToConstant: height)
        h.isActive = true
        stackView.addArrangedSubview(spacer)
        sectionSpacers.append((view: spacer, height: h, original: height))
    }
    
    private func addButton(_ text: String, icon: String, index: Int) {
        let btn = SidebarButton(title: text, icon: icon, index: index)
        btn.target = self
        btn.action = #selector(itemClicked(_:))
        stackView.addArrangedSubview(btn)
        btn.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        buttons.append(btn)
    }
    
    private func addLegacyButton() {
        let btn = SidebarButton(title: "Open Legacy Preferences", icon: "clock.arrow.circlepath", index: 99)
        btn.target = self
        btn.action = #selector(legacyClicked)
        stackView.addArrangedSubview(btn)
        btn.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        buttons.append(btn)
    }
    
    @objc private func itemClicked(_ sender: SidebarButton) {
        currentSelectedButton = sender
        moveIndicator(to: sender)
        delegate?.didSelectPage(index: sender.index)
    }
    
    @objc private func legacyClicked() { delegate?.openLegacy() }
    @objc private func onCollapse() { delegate?.toggleCollapse() }
    
    // --- Collapse Animation ---
    
    func updateCollapseState(_ collapsed: Bool) {
        self.isCollapsed = collapsed
        let iconName = collapsed ? "sidebar.right" : "sidebar.left"
        collapseBtn.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            stackView.animator().spacing = collapsed ? 10 : 0
        }
        
        if let btn = currentSelectedButton {
            let newFrame = calculateIndicatorFrame(for: btn)
            let anim = CABasicAnimation(keyPath: "frame")
            anim.duration = 0.3
            anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            indicatorLayer.frame = newFrame
            indicatorLayer.add(anim, forKey: "frame")
            
            let cornerAnim = CABasicAnimation(keyPath: "cornerRadius")
            cornerAnim.fromValue = indicatorLayer.cornerRadius
            cornerAnim.toValue = collapsed ? 8 : 6
            cornerAnim.duration = 0.3
            indicatorLayer.cornerRadius = collapsed ? 8 : 6
            indicatorLayer.add(cornerAnim, forKey: "cornerRadius")
        }
        
        if collapsed {
            self.titleLabel.alphaValue = 0
            self.buttons.forEach { $0.setTextVisible(false) }
            self.sectionHeaders.forEach { $0.setCollapsed(true) }
            // Hide any manual spacers when collapsed to remove extra gaps
            self.sectionSpacers.forEach { pair in
                pair.view.isHidden = true
                pair.height.constant = 0
            }
        } else {
            self.sectionHeaders.forEach { $0.setCollapsed(false) }
            self.titleLabel.alphaValue = 0
            self.buttons.forEach { $0.setTextVisible(false) }
            // Restore spacers when expanded
            self.sectionSpacers.forEach { pair in
                pair.view.isHidden = false
                pair.height.constant = pair.original
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.2
                    self.titleLabel.animator().alphaValue = 1
                    self.buttons.forEach { $0.setTextVisible(true, animate: true) }
                }
            }
        }
        needsLayout = true
    }
}

// --- Components ---

class SidebarSectionHeader: NSView {
    private let label = NSTextField(labelWithString: "")
    private let line = NSBox()
    
    init(text: String) {
        super.init(frame: .zero)
        // Section header height: controls the vertical space the header uses.
        // Reduce this (for example to 20) to bring the subtitle/header closer
        // to neighboring buttons.
        self.heightAnchor.constraint(equalToConstant: 28).isActive = true
        
        label.stringValue = text
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = NSColor(white: 0.5, alpha: 1.0)
        
        line.boxType = .separator
        line.alphaValue = 0
        
        addSubview(label)
        addSubview(line)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        line.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            line.centerYAnchor.constraint(equalTo: centerYAnchor),
            line.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            line.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func setCollapsed(_ collapsed: Bool) {
        label.alphaValue = collapsed ? 0 : 1
        line.alphaValue = collapsed ? 1 : 0
    }
}
//control for button size
class SidebarButton: NSControl {
    let index: Int
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    
    init(title: String, icon: String, index: Int) {
        self.index = index
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
        // Button height: controls vertical spacing for each button.
        // Change this value to adjust spacing between buttons and headers.
        self.heightAnchor.constraint(equalToConstant: 34).isActive = true
        //end
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        iconView.contentTintColor = .white
        
        label.stringValue = title
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.cell?.lineBreakMode = .byTruncatingTail
        
        addSubview(iconView)
        addSubview(label)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func setTextVisible(_ visible: Bool, animate: Bool = false) {
        if animate {
            label.animator().alphaValue = visible ? 1 : 0
        } else {
            label.alphaValue = visible ? 1 : 0
        }
    }
    
    override func layout() {
        super.layout()
        let isCompact = bounds.width < 100
        if isCompact {
            iconView.frame = CGRect(x: (bounds.width - 18)/2, y: 5, width: 18, height: 18)
            label.isHidden = true
        } else {
            iconView.frame = CGRect(x: 20, y: 5, width: 18, height: 18)
            label.frame = CGRect(x: 50, y: 6, width: bounds.width - 60, height: 16)
            label.isHidden = false
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        sendAction(action, to: target)
    }
}
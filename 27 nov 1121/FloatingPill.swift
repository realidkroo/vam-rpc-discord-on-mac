import Cocoa

class FloatingPill: NSView {
    
    var onHome: (() -> Void)?
    var onGithub: (() -> Void)?
    var onReset: (() -> Void)?
    var onKill: (() -> Void)?
    var onToggleSidebar: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.9).cgColor
        layer?.cornerRadius = 24
        layer?.borderColor = NSColor(white: 0.3, alpha: 0.5).cgColor
        layer?.borderWidth = 1
        
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 20
        stack.alignment = .centerY
        
        // Buttons based on your screenshot arrows
        // 1. Home (User Avatar)
        let homeBtn = createImgBtn("person.circle.fill", #selector(clickedHome))
        // 2. Github
        let gitBtn = createImgBtn("safari", #selector(clickedGit))
        // 3. Reset
        let resetBtn = createImgBtn("arrow.clockwise", #selector(clickedReset))
        // 4. Kill
        let killBtn = createImgBtn("xmark.circle", #selector(clickedKill))
        // 5. Sidebar Toggle
        let toggleBtn = createImgBtn("sidebar.left", #selector(clickedToggle))
        
        stack.addArrangedSubview(homeBtn)
        stack.addArrangedSubview(gitBtn)
        stack.addArrangedSubview(resetBtn)
        stack.addArrangedSubview(killBtn)
        stack.addArrangedSubview(toggleBtn)
        
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        stack.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func createImgBtn(_ icon: String, _ sel: Selector) -> NSButton {
        let btn = NSButton()
        btn.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.contentTintColor = .white
        btn.target = self
        btn.action = sel
        return btn
    }
    
    @objc func clickedHome() { onHome?() }
    @objc func clickedGit() { onGithub?() }
    @objc func clickedReset() { onReset?() }
    @objc func clickedKill() { onKill?() }
    @objc func clickedToggle() { onToggleSidebar?() }
    
    override var intrinsicContentSize: NSSize { NSSize(width: 220, height: 48) }
}
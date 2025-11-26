import Cocoa

class ModernTextField: NSView, NSTextFieldDelegate {
    var onTextChange: ((String) -> Void)?
    private let textField = NSTextField()
    private let bgLayer = CALayer()
    
    var stringValue: String {
        get { textField.stringValue }
        set { textField.stringValue = newValue }
    }
    
    // --- FIXED: Added placeholderString property ---
    var placeholderString: String? {
        get { textField.placeholderString }
        set { textField.placeholderString = newValue }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        
        // Dark gray background from screenshot
        bgLayer.backgroundColor = NSColor(white: 0.2, alpha: 1.0).cgColor 
        bgLayer.cornerRadius = 6
        layer?.addSublayer(bgLayer)
        
        textField.drawsBackground = false
        textField.isBezeled = false
        textField.isBordered = false
        textField.focusRingType = .none
        textField.delegate = self
        textField.font = .systemFont(ofSize: 12)
        textField.textColor = .white
        
        addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 18)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layout() {
        super.layout()
        bgLayer.frame = bounds
    }
    
    func controlTextDidChange(_ obj: Notification) {
        onTextChange?(textField.stringValue)
    }
    
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 32) }
}

class ModernToggle: NSControl {
    var isOn: Bool = false { didSet { updateState() } }
    var onToggle: ((Bool) -> Void)?
    private let bgLayer = CALayer()
    private let knobLayer = CALayer()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        
        bgLayer.cornerRadius = 10
        layer?.addSublayer(bgLayer)
        
        knobLayer.backgroundColor = NSColor.white.cgColor
        knobLayer.cornerRadius = 8
        layer?.addSublayer(knobLayer)
        updateState(animated: false)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layout() {
        super.layout()
        bgLayer.frame = bounds
        updateState(animated: false)
    }
    
    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
        onToggle?(isOn)
        sendAction(action, to: target)
    }
    
    func updateState(animated: Bool = true) {
        let targetX = isOn ? bounds.width - 18 : 2
        // Green color from screenshot
        let targetColor = isOn ? NSColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1.0).cgColor : NSColor(white: 0.3, alpha: 1.0).cgColor
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? 0.2 : 0)
        bgLayer.backgroundColor = targetColor
        knobLayer.frame = CGRect(x: targetX, y: 2, width: 16, height: 16)
        CATransaction.commit()
    }
    
    override var intrinsicContentSize: NSSize { NSSize(width: 36, height: 20) }
}

class ModernSectionHeader: NSTextField {
    init(text: String) {
        super.init(frame: .zero)
        self.stringValue = text
        self.font = .systemFont(ofSize: 18, weight: .bold)
        self.textColor = .white
        self.drawsBackground = false
        self.isBezeled = false
        self.isEditable = false
        self.isSelectable = false
    }
    required init?(coder: NSCoder) { fatalError() }
}
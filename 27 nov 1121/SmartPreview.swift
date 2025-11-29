import Cocoa

enum HighlightTarget {
    case none, activity, details, state, largeImage, smallImage
}

class SmartPreviewView: NSView {
    
    private let variant: Int
    private let bgLayer = CALayer()
    
    // UI Elements
    let activityLabel = NSTextField(labelWithString: "Listening to Apple Music")
    let detailsLabel = NSTextField(labelWithString: "Details")
    let stateLabel = NSTextField(labelWithString: "State")
    let largeImage = NSImageView()
    let smallImage = NSImageView()
    
    init(variant: Int) {
        self.variant = variant
        super.init(frame: .zero)
        self.wantsLayer = true
        setupView()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupView() {
        // Base Card
        bgLayer.backgroundColor = NSColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1.0).cgColor
        bgLayer.cornerRadius = 8
        layer?.addSublayer(bgLayer)
        
        // Apply variant styles
        if variant == 1 { bgLayer.backgroundColor = NSColor(white: 0.15, alpha: 1.0).cgColor }
        if variant == 2 { bgLayer.opacity = 0.8 }
        
        // Images
        largeImage.image = NSImage(named: "asltolfo.png") ?? NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        largeImage.wantsLayer = true
        largeImage.layer?.cornerRadius = 8
        largeImage.layer?.masksToBounds = true
        largeImage.imageScaling = .scaleAxesIndependently
        
        smallImage.image = NSImage(named: "roo.jpg") ?? NSImage(systemSymbolName: "person.circle", accessibilityDescription: nil)
        smallImage.wantsLayer = true
        smallImage.layer?.cornerRadius = 10
        smallImage.layer?.masksToBounds = true
        smallImage.layer?.borderWidth = 2
        smallImage.layer?.borderColor = bgLayer.backgroundColor
        smallImage.imageScaling = .scaleAxesIndependently
        
        // Text Styling
        styleText(activityLabel, size: 11, color: .gray)
        styleText(detailsLabel, size: 13, color: .white, bold: true)
        styleText(stateLabel, size: 12, color: .white)
        
        addSubview(largeImage)
        addSubview(smallImage)
        addSubview(activityLabel)
        addSubview(detailsLabel)
        addSubview(stateLabel)
    }
    
    private func styleText(_ label: NSTextField, size: CGFloat, color: NSColor, bold: Bool = false) {
        label.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        label.textColor = color
        label.drawsBackground = false
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
    }
    
    override func layout() {
        super.layout()
        bgLayer.frame = bounds
        
        // Manual Frame Layout for precision
        let h = bounds.height
        let imgSize: CGFloat = 60
        
        largeImage.frame = CGRect(x: 12, y: h - 12 - imgSize, width: imgSize, height: imgSize)
        smallImage.frame = CGRect(x: 12 + imgSize - 20, y: h - 12 - imgSize, width: 24, height: 24)
        
        let textX = 12 + imgSize + 12
        let textW = bounds.width - textX - 10
        
        activityLabel.frame = CGRect(x: 12, y: h - 20, width: 200, height: 14)
        detailsLabel.frame = CGRect(x: textX, y: h - 32, width: textW, height: 16)
        stateLabel.frame = CGRect(x: textX, y: h - 48, width: textW, height: 14)
    }
    
    func update(with settings: Settings) {
        // Replace placeholders with dummy data for preview
        let demoData: [String: String] = [
            "{name}": "No Way",
            "{artist}": "Roo",
            "{album}": "Broken"
        ]
        
        func process(_ str: String) -> String {
            var res = str
            for (k, v) in demoData { res = res.replacingOccurrences(of: k, with: v) }
            return res
        }
        
        activityLabel.stringValue = "Listening to \(settings.activityName)"
        detailsLabel.stringValue = process(settings.detailsString)
        stateLabel.stringValue = process(settings.stateString)
    }
    
    func highlight(_ target: HighlightTarget) {
        // Implementation for white background highlight (optional for now, let's get it visible first)
    }
}
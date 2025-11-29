import Cocoa

class RPCSettingsViewController: NSViewController {
    
    private let scrollView = NSScrollView()
    private let documentView = NSView() // Container for the stack
    private let stack = NSStackView()
    
    // Horizontal scroll for previews
    private let previewScroll = NSScrollView()
    private let previewStack = NSStackView()
    private var previews: [SmartPreviewView] = []
    
    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupContent()
        loadValues()
    }
    
    private func setupScrollView() {
        // 1. Scroll View spans entire page
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        view.addSubview(scrollView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // 2. Document View (The long vertical strip)
        scrollView.documentView = documentView
        documentView.translatesAutoresizingMaskIntoConstraints = false
        
        // Pin Document View to Scroll View edges
        NSLayoutConstraint.activate([
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            // WIDTH MUST MATCH SCROLLVIEW FOR VERTICAL SCROLLING
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        
        // 3. Stack View inside Document View
        documentView.addSubview(stack)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 24
        stack.edgeInsets = NSEdgeInsets(top: 40, left: 40, bottom: 100, right: 40)
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: documentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor) // Pushes document height
        ])
    }
    
    private func setupContent() {
        // Header
        let title = NSTextField(labelWithString: "Rpc Settings")
        title.font = .systemFont(ofSize: 32, weight: .bold)
        title.textColor = .white
        stack.addArrangedSubview(title)
        
        let subtitle = NSTextField(labelWithString: "This is the place where you customize your discord status!")
        subtitle.textColor = .gray
        stack.addArrangedSubview(subtitle)
        
        stack.addArrangedSubview(NSBox().then { $0.boxType = .separator; $0.alphaValue = 0 }) // Spacer
        
        // --- PREVIEWS SECTION ---
        let pTitle = NSTextField(labelWithString: "Previews")
        pTitle.font = .systemFont(ofSize: 18, weight: .bold)
        pTitle.textColor = .white
        stack.addArrangedSubview(pTitle)
        
        setupHorizontalPreviews()
        
        // --- INPUTS SECTION ---
        addInput(label: "RPC Status Tag", key: \.activityName, placeholder: "Apple Music")
        addInput(label: "Detail String", key: \.detailsString, placeholder: "{name}")
        addInput(label: "State String", key: \.stateString, placeholder: "by {artist}")
        addInput(label: "Large Image Text", key: \.largeImageText, placeholder: "{album}")
    }
    
    private func setupHorizontalPreviews() {
        previewScroll.drawsBackground = false
        previewScroll.hasHorizontalScroller = true
        previewScroll.autohidesScrollers = true
        
        // Horizontal stack
        previewStack.orientation = .horizontal
        previewStack.spacing = 16
        previewScroll.documentView = previewStack
        
        // Create 5 variants
        for i in 0..<5 {
            let card = SmartPreviewView(variant: i)
            card.translatesAutoresizingMaskIntoConstraints = false
            card.widthAnchor.constraint(equalToConstant: 280).isActive = true
            card.heightAnchor.constraint(equalToConstant: 110).isActive = true
            previewStack.addArrangedSubview(card)
            previews.append(card)
        }
        
        stack.addArrangedSubview(previewScroll)
        previewScroll.translatesAutoresizingMaskIntoConstraints = false
        previewScroll.heightAnchor.constraint(equalToConstant: 130).isActive = true
        previewScroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -80).isActive = true
    }
    
    private func addInput(label: String, key: WritableKeyPath<Settings, String>, placeholder: String) {
        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 13, weight: .bold)
        lbl.textColor = .white
        
        let field = ModernTextField()
        field.stringValue = ConfigManager.shared.settings[keyPath: key]
        field.placeholderString = placeholder
        
        // Save on change
        field.onTextChange = { [weak self] newVal in
            ConfigManager.shared.settings[keyPath: key] = newVal
            ConfigManager.shared.save()
            self?.refreshPreviews()
        }
        
        stack.addArrangedSubview(lbl)
        stack.addArrangedSubview(field)
        
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -80).isActive = true
        field.heightAnchor.constraint(equalToConstant: 32).isActive = true
    }
    
    private func loadValues() {
        refreshPreviews()
    }
    
    private func refreshPreviews() {
        let s = ConfigManager.shared.settings
        previews.forEach { $0.update(with: s) }
    }
}

extension NSBox {
    func then(_ closure: (NSBox) -> Void) -> NSBox {
        closure(self)
        return self
    }
}
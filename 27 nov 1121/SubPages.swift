// SubPages.swift
import Cocoa

// MARK: - RPC Settings (Scrollable with 5 Previews)
class RPCSettingsViewController: NSViewController {
    
    private let scrollView = NSScrollView()
    private let mainStack = NSStackView()
    private let previewStack = NSStackView() // Horizontal stack for 5 variants
    
    // Inputs
    private let detailsInput = ModernTextField()
    private let stateInput = ModernTextField()
    
    override func loadView() {
        self.view = NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup ScrollView
        scrollView.documentView = mainStack
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        view.addSubview(scrollView)
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.width, .height]
        
        mainStack.orientation = .vertical
        mainStack.spacing = 20
        mainStack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        // Title (Non scrollable? Actually standard macOS scroll keeps title separate usually, 
        // but user asked for content scrollable, title not. 
        // We would put title OUTSIDE scrollview in parent, but for now putting inside top.)
        
        setupPreviews()
        setupInputs()
    }
    
    private func setupPreviews() {
        // "5 different preview and all changed when you entering/changing smth"
        previewStack.orientation = .horizontal
        previewStack.spacing = 15
        
        for i in 0..<5 {
            let p = SmartPreviewView(frame: CGRect(x: 0, y: 0, width: 280, height: 120))
            // Variant logic here (different opacities, sizes, etc)
            previewStack.addArrangedSubview(p)
        }
        
        let container = NSScrollView() // Horizontal scroll for previews
        container.documentView = previewStack
        container.heightAnchor.constraint(equalToConstant: 140).isActive = true
        mainStack.addArrangedSubview(container)
    }
    
    private func setupInputs() {
        let label = NSTextField(labelWithString: "Details String")
        label.textColor = .white
        mainStack.addArrangedSubview(label)
        
        detailsInput.stringValue = "{name}"
        detailsInput.onFocus = {
            // Trigger Highlight in previews
            self.highlightPreviews(.song)
        }
        mainStack.addArrangedSubview(detailsInput)
        
        // Add more inputs...
    }
    
    private func highlightPreviews(_ target: HighlightTarget) {
        previewStack.arrangedSubviews.compactMap { $0 as? SmartPreviewView }.forEach {
            $0.highlight(target)
        }
    }
}

// MARK: - Experimental Settings
class ExperimentalViewController: NSViewController {
    
    private let stack = NSStackView()
    
    override func loadView() {
        self.view = NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(stack)
        stack.orientation = .vertical
        stack.center(in: view)
        
        let title = NSTextField(labelWithString: "Experimental")
        title.font = .systemFont(ofSize: 24, weight: .bold)
        stack.addArrangedSubview(title)
        
        let spinToggle = ModernToggle()
        stack.addArrangedSubview(createRow(label: "Enable Spinning Art", control: spinToggle))
        
        let apiInput = ModernTextField()
        apiInput.stringValue = "https://able-pig-53.deno.dev"
        stack.addArrangedSubview(createRow(label: "Custom API URL", control: apiInput))
        
        let fileBtn = CustomButton(title: "Pick Custom Large Image", style: .secondary) // reusing old button class or new one
        // Add action to open NSOpenPanel
        stack.addArrangedSubview(fileBtn)
    }
    
    func createRow(label: String, control: NSView) -> NSView {
        let hStack = NSStackView(views: [NSTextField(labelWithString: label), control])
        hStack.spacing = 20
        return hStack
    }
}
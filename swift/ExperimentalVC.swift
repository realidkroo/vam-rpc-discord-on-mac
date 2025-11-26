import Cocoa

class ExperimentalViewController: NSViewController {
    
    private let stack = NSStackView()
    private let spinnerTypeDropdown = NSPopUpButton()
    private let apiUrlInput = ModernTextField()
    
    override func loadView() {
        self.view = NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 20
        stack.edgeInsets = NSEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        let title = NSTextField(labelWithString: "Experimental Settings")
        title.font = .boldSystemFont(ofSize: 24)
        title.textColor = .white
        stack.addArrangedSubview(title)
        
        // Spinner Config
        stack.addArrangedSubview(NSTextField(labelWithString: "Spinner Animation Type"))
        spinnerTypeDropdown.addItems(withTitles: ["None", "Artist Art Spin", "Album Art Spin"])
        stack.addArrangedSubview(spinnerTypeDropdown)
        
        stack.addArrangedSubview(NSTextField(labelWithString: "Custom API URL (Fallback)"))
        apiUrlInput.stringValue = "https://able-pig-53.deno.dev"
        stack.addArrangedSubview(apiUrlInput)
        apiUrlInput.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -80).isActive = true
        
        // File Pickers
        addFilePicker(label: "Custom Large Image", key: "large")
        addFilePicker(label: "Custom Small Image", key: "small")
    }
    
    private func addFilePicker(label: String, key: String) {
        let lbl = NSTextField(labelWithString: label)
        lbl.textColor = .white
        
        let btn = NSButton(title: "Choose File...", target: self, action: #selector(pickFile))
        btn.bezelStyle = .rounded
        
        let hStack = NSStackView(views: [lbl, btn])
        hStack.spacing = 20
        stack.addArrangedSubview(hStack)
    }
    
    @objc private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["png", "jpg", "gif"]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                print("Selected: \(url.path)")
                // Save logic here...
            }
        }
    }
}
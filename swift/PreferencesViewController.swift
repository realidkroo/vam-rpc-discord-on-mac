// PreferencesViewController.swift to windows
import Cocoa

class PreferencesViewController: NSViewController {

    private let supportDir = NSString(string: "~/Library/Application Support/VAM-RPC").expandingTildeInPath
    private let configPath = NSString(string: "~/Library/Application Support/VAM-RPC/config.json").expandingTildeInPath
    private let refreshIntervalField = NSTextField()
    //private let refreshIntervalField = NSTextField()


    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 280))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSettings() //loadchangedone
    }

    private func setupUI() {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.material = .sidebar
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(visualEffectView)

        let titleLabel = NSTextField(labelWithString: "Preferences")
        titleLabel.font = NSFont.systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = .labelColor

        let subtitleLabel = NSTextField(labelWithString: "More options coming soon.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        
        let refreshLabel = NSTextField(labelWithString: "Refresh Interval (seconds):")
        let saveButton = NSButton(title: "Save and Restart Service", target: self, action: #selector(saveSettings))
        saveButton.bezelStyle = .rounded

        let footerLabel = NSTextField(labelWithString: "Version ALPHA 01-A Made with Love by Realidkroo")
        footerLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        footerLabel.textColor = .tertiaryLabelColor
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let contentStack = NSStackView(views: [refreshLabel, refreshIntervalField])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 8

        let mainStack = NSStackView(views: [titleLabel, subtitleLabel, contentStack, saveButton])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 16
        mainStack.setCustomSpacing(24, after: subtitleLabel)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(mainStack)
        view.addSubview(footerLabel)
        
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            footerLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            footerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func loadSettings() {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let interval = json["refreshInterval"] as? Int {
            refreshIntervalField.integerValue = interval
        } else {
            refreshIntervalField.integerValue = 5
        }
    }

    @objc private func saveSettings() {
        let config: [String: Any] = [ "refreshInterval": max(1, refreshIntervalField.integerValue), "detailsString": "by {artist}", "stateString": "on {album}" ]
        do {
            try FileManager.default.createDirectory(atPath: supportDir, withIntermediateDirectories: true, attributes: nil)
            let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
            try data.write(to: URL(fileURLWithPath: configPath))
            restartService()
            self.view.window?.close()
        } catch {
            let alert = NSAlert(); alert.messageText = "Error"; alert.informativeText = "Could not save settings: \(error.localizedDescription)"; alert.runModal()
        }
    }
    
    private func restartService() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["kickstart", "gui/\(getuid())/com.vam-rpc.agent"]
        try? task.run()
    }
}
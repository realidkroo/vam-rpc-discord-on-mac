import Cocoa

class ModernPreferencesViewController: NSViewController, SidebarDelegate {
    
    private let sidebar = SidebarView()
    private let contentArea = NSView()
    private let floatingPill = FloatingPill()
    
    // Child VCs
    private lazy var homeVC = HomeViewController()
    private lazy var rpcVC = RPCSettingsViewController()
    private lazy var expVC = ExperimentalViewController()
    
    private var sidebarWidthConstraint: NSLayoutConstraint!
    
    override func loadView() {
        let visual = NSVisualEffectView()
        visual.material = .underWindowBackground
        visual.state = .active
        visual.wantsLayer = true
        // Darker, more transparent
        visual.layer?.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 0.75).cgColor
        self.view = visual
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        // Force layout before window appears
        view.layoutSubtreeIfNeeded()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Ensure layout is correct after appearing
        view.layoutSubtreeIfNeeded()
    }
    
    private func setupLayout() {
        sidebar.delegate = self
        
        view.addSubview(sidebar)
        view.addSubview(contentArea)
        view.addSubview(floatingPill)
        
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        contentArea.translatesAutoresizingMaskIntoConstraints = false
        floatingPill.translatesAutoresizingMaskIntoConstraints = false
        
        // Sidebar: 280px wide (matching image 2)
        sidebarWidthConstraint = sidebar.widthAnchor.constraint(equalToConstant: 280)
        
        NSLayoutConstraint.activate([
            sidebar.topAnchor.constraint(equalTo: view.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebarWidthConstraint,
            
            // Content area with proper side padding (50pt each side like image 2)
            contentArea.topAnchor.constraint(equalTo: view.topAnchor),
            contentArea.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentArea.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 50),
            contentArea.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
            
            floatingPill.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30),
            floatingPill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            floatingPill.heightAnchor.constraint(equalToConstant: 50),
            floatingPill.widthAnchor.constraint(equalToConstant: 240)
        ])
        
        floatingPill.onHome = { self.loadPage(self.homeVC) }
        floatingPill.onToggleSidebar = { self.toggleCollapse() }
        floatingPill.onKill = { NSApp.terminate(nil) }
        
        // Load initial page
        loadPage(homeVC)
        
        // Force immediate layout
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }
    
    // SidebarDelegate
    func toggleCollapse() {
        let isCollapsed = (sidebarWidthConstraint.constant < 150)
        let targetWidth: CGFloat = isCollapsed ? 280 : 75
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            sidebarWidthConstraint.animator().constant = targetWidth
        }
        
        sidebar.updateCollapseState(!isCollapsed)
    }
    
    func didSelectPage(index: Int) {
        switch index {
        case 0: loadPage(homeVC)
        case 2: loadPage(rpcVC)
        case 5: loadPage(expVC)
        default: print("Page \(index) placeholder")
        }
    }
    
    func openLegacy() {
        (NSApp.delegate as? AppDelegate)?.openLegacySettings()
    }
    
    private func loadPage(_ vc: NSViewController) {
        contentArea.subviews.forEach { $0.removeFromSuperview() }
        children.forEach { $0.removeFromParent() }
        addChild(vc)
        contentArea.addSubview(vc.view)
        
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            vc.view.topAnchor.constraint(equalTo: contentArea.topAnchor),
            vc.view.bottomAnchor.constraint(equalTo: contentArea.bottomAnchor),
            vc.view.leadingAnchor.constraint(equalTo: contentArea.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: contentArea.trailingAnchor)
        ])
        
        // Force layout after loading page
        vc.view.layoutSubtreeIfNeeded()
    }
}
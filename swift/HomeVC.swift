import Cocoa

class HomeViewController: NSViewController {
    
    override func loadView() {
        self.view = NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // --- Header ---
        let title = NSTextField(labelWithString: "Home")
        title.font = .systemFont(ofSize: 32, weight: .bold)
        title.textColor = .white
        
        let subtitle = NSTextField(labelWithString: "This is my discord btw... you can imagine how it looks with your discord profile.")
        subtitle.textColor = .gray
        
        // --- Profile Card ---
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0).cgColor
        card.layer?.cornerRadius = 8
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor(white: 0.2, alpha: 1.0).cgColor
        
        // 1. Banner (Pink)
        let banner = NSView()
        banner.wantsLayer = true
        banner.layer?.backgroundColor = NSColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0).cgColor // Pink
        banner.layer?.cornerRadius = 8
        // Mask bottom corners to square so it looks like a banner
        if #available(macOS 11.0, *) {
            banner.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        
        // 2. Avatar (With green dot)
        let avatarContainer = NSView()
        avatarContainer.wantsLayer = true
        avatarContainer.layer?.cornerRadius = 40
        avatarContainer.layer?.backgroundColor = card.layer?.backgroundColor // border color match card
        
        let avatarImg = NSImageView(image: NSImage(named: "roo.jpg") ?? NSImage(systemSymbolName: "person.circle", accessibilityDescription: nil)!)
        avatarImg.wantsLayer = true
        avatarImg.layer?.cornerRadius = 34
        avatarImg.layer?.masksToBounds = true
        
        let statusDot = NSView()
        statusDot.wantsLayer = true
        statusDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        statusDot.layer?.cornerRadius = 8
        statusDot.layer?.borderWidth = 3
        statusDot.layer?.borderColor = card.layer?.backgroundColor
        
        // 3. Text Content
        let name = NSTextField(labelWithString: "Keikosama")
        name.font = .boldSystemFont(ofSize: 20)
        name.textColor = .white
        
        let tags = NSTextField(labelWithString: "idkbran • he/r/uno/16")
        tags.font = .systemFont(ofSize: 12)
        tags.textColor = .gray
        
        // 4. Activity Box
        let activityBox = NSView()
        activityBox.wantsLayer = true
        activityBox.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1.0).cgColor
        activityBox.layer?.cornerRadius = 6
        
        let actTitle = NSTextField(labelWithString: "Listening to Apple Music")
        actTitle.font = .boldSystemFont(ofSize: 11)
        actTitle.textColor = .white
        
        let albumArt = NSImageView(image: NSImage(named: "asltolfo.png") ?? NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!)
        albumArt.wantsLayer = true; albumArt.layer?.cornerRadius = 6; albumArt.layer?.masksToBounds = true
        
        let song = NSTextField(labelWithString: "No Way"); song.font = .boldSystemFont(ofSize: 13); song.textColor = .white
        let artist = NSTextField(labelWithString: "By roo"); artist.font = .systemFont(ofSize: 12); artist.textColor = .lightGray
        let time = NSTextField(labelWithString: "01:11 — 02:23"); time.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular); time.textColor = .lightGray
        
        // Assemble Hierarchy
        activityBox.addSubview(actTitle)
        activityBox.addSubview(albumArt)
        activityBox.addSubview(song)
        activityBox.addSubview(artist)
        activityBox.addSubview(time)
        
        card.addSubview(banner)
        card.addSubview(avatarContainer)
        avatarContainer.addSubview(avatarImg)
        card.addSubview(statusDot)
        card.addSubview(name)
        card.addSubview(tags)
        card.addSubview(activityBox)
        
        view.addSubview(title)
        view.addSubview(subtitle)
        view.addSubview(card)
        
        // Layout Constraints for Main Elements
        title.translatesAutoresizingMaskIntoConstraints = false
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        card.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 5),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            
            card.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 30),
            card.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            card.heightAnchor.constraint(equalToConstant: 300)
        ])
        
        // Manual Layout inside Card (for precision 1:1 match)
        // We use LayoutSubviews equivalent logic
        
        // Banner: Top 100px
        banner.frame = CGRect(x: 0, y: 180, width: 600, height: 120) // Will resize in layout
        banner.autoresizingMask = [.width, .minYMargin]
        
        // Avatar: Overlaps banner
        avatarContainer.frame = CGRect(x: 20, y: 150, width: 80, height: 80)
        avatarImg.frame = CGRect(x: 6, y: 6, width: 68, height: 68)
        statusDot.frame = CGRect(x: 80, y: 155, width: 16, height: 16)
        
        name.frame = CGRect(x: 20, y: 115, width: 200, height: 24)
        tags.frame = CGRect(x: 20, y: 95, width: 200, height: 16)
        
        // Activity Box: Bottom Right
        activityBox.frame = CGRect(x: 300, y: 20, width: 280, height: 100) // Position placeholder
        activityBox.autoresizingMask = [.minXMargin, .maxYMargin] // Stick to right
        
        // Activity Internals
        actTitle.frame = CGRect(x: 10, y: 75, width: 200, height: 16)
        albumArt.frame = CGRect(x: 10, y: 10, width: 60, height: 60)
        song.frame = CGRect(x: 80, y: 50, width: 180, height: 16)
        artist.frame = CGRect(x: 80, y: 35, width: 180, height: 14)
        time.frame = CGRect(x: 80, y: 15, width: 180, height: 14)
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        // Resize banner to match card width
        if let card = view.subviews.last, let banner = card.subviews.first {
            banner.frame = CGRect(x: 0, y: card.bounds.height - 100, width: card.bounds.width, height: 100)
            
            // Fix Activity Box position
            if let act = card.subviews.last {
                act.frame = CGRect(x: card.bounds.width - 300, y: 20, width: 280, height: 100)
            }
        }
    }
}
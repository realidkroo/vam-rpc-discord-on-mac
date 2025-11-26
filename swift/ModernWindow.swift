// Adjusts the button position safely
    private func adjustTrafficLights() {
        // 1. STOP if in Fullscreen. The system handles buttons there.
        if self.styleMask.contains(.fullScreen) {
            return
        }
        
        // 2. Get the Close button (Red) and its Container
        guard let closeButton = self.standardWindowButton(.closeButton),
              let container = closeButton.superview else { return }
        
        // 3. Finder-style positioning
        // Standard macOS positioning: 13px from top, 20px from left
        let targetTopMargin: CGFloat = 13.0 
        let targetLeftMargin: CGFloat = 20.0
        
        // Calculate Y in flipped coordinates (0,0 at top-left)
        // In NSWindow coordinates, Y=0 is bottom, so we need contentView height - container height - margin
        let contentHeight = self.contentView?.frame.height ?? self.frame.height
        let newY = contentHeight - container.frame.height - targetTopMargin
        
        // 4. Apply only if different (prevents jitter)
        if abs(container.frame.origin.y - newY) > 0.5 || abs(container.frame.origin.x - targetLeftMargin) > 0.5 {
            
            // Disable animation for position updates during resize for snap-feel
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0
                context.allowsImplicitAnimation = false
                
                var newFrame = container.frame
                newFrame.origin.y = newY
                newFrame.origin.x = targetLeftMargin
                container.frame = newFrame
            })
        }
    }
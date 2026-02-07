import AppKit

/// Transparent, click-through overlay window covering the entire screen for rain rendering
public class RainOverlayWindow: NSPanel {
    
    public init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isReleasedWhenClosed = false
        
        configureWindow()
    }
    
    private func configureWindow() {
        // backgroundColor = NSColor.red.withAlphaComponent(0.3)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        
        // Window level: try statusBar level (lower than floating, might have better permissions)
        level = .mainMenu + 1
        
        // Ensure it doesn't take focus unless needed
        becomesKeyOnlyIfNeeded = true
        
        // Collection behavior for proper screen handling
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        
        // Allow clicks to pass through
        ignoresMouseEvents = true
        
        // styleMask.insert(.nonactivatingPanel) -- already in init
        
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        
        print("🪟 Window configured with level: \(level.rawValue), frame: \(frame)")
    }
    
    // Prevent the window from becoming key
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}

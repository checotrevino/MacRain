import AppKit

/// Detects the dock position and bounds on screen
public class DockDetector {
    
    public struct DockInfo {
        public let position: DockPosition
        public let frame: CGRect
    }
    
    public enum DockPosition {
        case bottom
        case left
        case right
        case hidden
    }
    
    public init() {}
    
    /// Returns current dock information for the main screen
    public func detectDock() -> DockInfo {
        guard let screen = NSScreen.main else {
            return DockInfo(position: .hidden, frame: .zero)
        }
        
        let fullFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        
        // 1. Determine general dock position (bottom, left, right)
        let bottomDiff = visibleFrame.minY - fullFrame.minY
        let leftDiff = visibleFrame.minX - fullFrame.minX
        let rightDiff = fullFrame.maxX - visibleFrame.maxX
        
        var position: DockPosition = .hidden
        if bottomDiff > 10 { position = .bottom }
        else if leftDiff > 10 { position = .left }
        else if rightDiff > 10 { position = .right }
        
        guard position != .hidden else {
            return DockInfo(position: .hidden, frame: .zero)
        }
        
        // 2. Find the actual Dock window to get its precise horizontal bounds (if position is bottom)
        // or vertical bounds (if position is left/right)
        let options: CGWindowListOption = [.optionOnScreenOnly]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return fallbackDockInfo(position: position, fullFrame: fullFrame, bottomDiff: bottomDiff, leftDiff: leftDiff, rightDiff: rightDiff)
        }
        
        var narrowestDockFrame: CGRect?
        var minDimension: CGFloat = CGFloat.infinity
        
        for info in windowList {
            guard let ownerName = info[kCGWindowOwnerName as String] as? String,
                  ownerName == "Dock" else {
                continue
            }
            
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat else {
                continue
            }
            
            let dockScreenY = fullFrame.height - (y + height)
            
            // Validate it's in the expected dock area based on general position
            let isInArea: Bool
            switch position {
            case .bottom: isInArea = dockScreenY < 120
            case .left: isInArea = x < 120
            case .right: isInArea = x > (fullFrame.width - 200)
            case .hidden: isInArea = false
            }
            
            if isInArea {
                // We want the narrowest window (bottom dock) or shortest window (side dock)
                // This typically corresponds to the icon bar itself.
                let relevantDimension = (position == .bottom) ? width : height
                
                // On macOS, the Dock has a transparent background window that is usually full-screen width.
                // We want to specifically find the window that is narrower (the icons).
                // Use a 95% threshold to ensure we skip the backdrop.
                let isNarrowEnough = (position == .bottom && width < fullFrame.width * 0.95) || 
                                    ((position == .left || position == .right) && height < fullFrame.height * 0.95)
                
                if isNarrowEnough {
                    if relevantDimension < minDimension && relevantDimension > 40 {
                        minDimension = relevantDimension
                        narrowestDockFrame = CGRect(x: x, y: dockScreenY, width: width, height: height)
                    }
                }
            }
        }
        
        if let frame = narrowestDockFrame {
            print("🎯 Precise Dock icon bar found width: \(frame.width) at x: \(frame.minX)")
            return DockInfo(position: position, frame: frame)
        }
        
        // 3. Last Resort Fallback: If no narrow window found, use a centered estimate (60% width)
        // instead of the full screen width to be more realistic.
        let fullWidthInfo = fallbackDockInfo(position: position, fullFrame: fullFrame, bottomDiff: bottomDiff, leftDiff: leftDiff, rightDiff: rightDiff)
        var estimatedFrame = fullWidthInfo.frame
        
        if position == .bottom {
            let estimatedWidth = fullFrame.width * 0.6 // Heuristic: average dock size
            estimatedFrame = CGRect(
                x: fullFrame.midX - (estimatedWidth / 2),
                y: estimatedFrame.minY,
                width: estimatedWidth,
                height: estimatedFrame.height
            )
        }
        
        print("⚠️ No narrow Dock window found, using centered estimate: \(estimatedFrame)")
        return DockInfo(position: position, frame: estimatedFrame)
    }
    
    private func fallbackDockInfo(position: DockPosition, fullFrame: CGRect, bottomDiff: CGFloat, leftDiff: CGFloat, rightDiff: CGFloat) -> DockInfo {
        switch position {
        case .bottom:
            return DockInfo(position: .bottom, frame: CGRect(x: fullFrame.minX, y: fullFrame.minY, width: fullFrame.width, height: bottomDiff))
        case .left:
            return DockInfo(position: .left, frame: CGRect(x: fullFrame.minX, y: fullFrame.minY, width: leftDiff, height: fullFrame.height))
        case .right:
            return DockInfo(position: .right, frame: CGRect(x: fullFrame.maxX - rightDiff, y: fullFrame.minY, width: rightDiff, height: fullFrame.height))
        case .hidden:
            return DockInfo(position: .hidden, frame: .zero)
        }
    }
    
    /// Convert screen coordinates (origin at bottom-left) to view coordinates (origin at top-left)
    public func dockFrameInViewCoordinates(screenHeight: CGFloat) -> CGRect {
        let dockInfo = detectDock()
        guard dockInfo.position != .hidden else { return .zero }
        
        let screenFrame = dockInfo.frame
        
        // Convert from screen coordinates (bottom-left origin) to view coordinates (top-left origin)
        return CGRect(
            x: screenFrame.minX,
            y: screenHeight - screenFrame.maxY,
            width: screenFrame.width,
            height: screenFrame.height
        )
    }
}

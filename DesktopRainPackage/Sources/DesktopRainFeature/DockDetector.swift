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
        
        // Calculate dock position based on difference between full and visible frame
        let bottomDiff = visibleFrame.minY - fullFrame.minY
        let topDiff = fullFrame.maxY - visibleFrame.maxY
        let leftDiff = visibleFrame.minX - fullFrame.minX
        let rightDiff = fullFrame.maxX - visibleFrame.maxX
        
        // Menu bar is typically at top, so account for that (~25 pts)
        let menuBarHeight: CGFloat = 25
        let adjustedTopDiff = topDiff - menuBarHeight
        
        // Determine where the dock is based on which side has the largest difference
        if bottomDiff > 10 {
            // Dock at bottom
            let dockFrame = CGRect(
                x: fullFrame.minX,
                y: fullFrame.minY,
                width: fullFrame.width,
                height: bottomDiff
            )
            return DockInfo(position: .bottom, frame: dockFrame)
        } else if leftDiff > 10 {
            // Dock at left
            let dockFrame = CGRect(
                x: fullFrame.minX,
                y: fullFrame.minY,
                width: leftDiff,
                height: fullFrame.height
            )
            return DockInfo(position: .left, frame: dockFrame)
        } else if rightDiff > 10 {
            // Dock at right
            let dockFrame = CGRect(
                x: fullFrame.maxX - rightDiff,
                y: fullFrame.minY,
                width: rightDiff,
                height: fullFrame.height
            )
            return DockInfo(position: .right, frame: dockFrame)
        } else if adjustedTopDiff > 10 {
            // Dock somehow at top (unusual but possible)
            let dockFrame = CGRect(
                x: fullFrame.minX,
                y: fullFrame.maxY - topDiff,
                width: fullFrame.width,
                height: topDiff - menuBarHeight
            )
            return DockInfo(position: .bottom, frame: dockFrame) // Treat as bottom for physics
        }
        
        // Dock is hidden or auto-hide is enabled
        return DockInfo(position: .hidden, frame: .zero)
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

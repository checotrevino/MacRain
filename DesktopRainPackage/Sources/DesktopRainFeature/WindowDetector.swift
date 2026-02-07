import AppKit
import CoreGraphics

/// Utility to detect and provide frames of visible windows on the screen
public class WindowDetector {
    
    public init() {}
    
    /// Returns a list of visible window frames in view coordinates (origin at top-left)
    /// - Parameter screenHeight: The height of the screen to convert coordinates
    /// - Returns: Array of CGRects representing window frames
    public func detectVisibleWindows(screenHeight: CGFloat) -> [CGRect] {
        // CGWindowListOptions to get on-screen, non-system windows
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        var windowFrames: [CGRect] = []
        
        for info in windowList {
            // Filter by window level (we only want regular windows, not desktop/status bar)
            guard let level = info[kCGWindowLayer as String] as? Int,
                  level == 0 else { // kCGNormalWindowLevel is 0
                continue
            }
            
            // Filter by owner name (avoid our own app and system UI)
            guard let ownerName = info[kCGWindowOwnerName as String] as? String,
                  ownerName != "DesktopRain",
                  ownerName != "Window Server",
                  ownerName != "ControlCenter",
                  ownerName != "Notification Center",
                  ownerName != "Dock" else { // Dock managed separately
                continue
            }
            
            // Filter by window name (ignore empty or system-sounding ones)
            if let windowName = info[kCGWindowName as String] as? String {
                if windowName.isEmpty || windowName == "Focus Proxy" {
                    continue
                }
            }
            
            // Get bounds
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat else {
                continue
            }
            
            // CGWindowList returns coordinates with origin at top-left of the coordinate space
            // which usually matches our view coordinate system.
            let frame = CGRect(x: x, y: y, width: width, height: height)
            
            // Minimal size check to avoid utility windows/tooltips
            if width > 50 && height > 50 {
                windowFrames.append(frame)
            }
        }
        
        return windowFrames
    }
}

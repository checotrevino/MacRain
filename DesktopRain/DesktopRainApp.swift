import SwiftUI
import DesktopRainFeature

@main
struct DesktopRainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Empty Settings scene - we use the menu bar item instead
        Settings {
            EmptyView()
        }
    }
}

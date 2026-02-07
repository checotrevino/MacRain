import Foundation
import CoreGraphics

/// Model for user-configurable rain settings
public final class RainSettings: @unchecked Sendable {
    public static let shared = RainSettings()
    
    private let lock = NSLock()
    
    private var _intensity: Float = 1.0
    public var intensity: Float {
        get { lock.lock(); defer { lock.unlock() }; return _intensity }
        set { lock.lock(); defer { lock.unlock() }; _intensity = newValue }
    }
    
    private var _direction: Float = 0
    public var direction: Float {
        get { lock.lock(); defer { lock.unlock() }; return _direction }
        set { lock.lock(); defer { lock.unlock() }; _direction = newValue }
    }
    
    private var _bounceIntensity: Float = 1.0
    public var bounceIntensity: Float {
        get { lock.lock(); defer { lock.unlock() }; return _bounceIntensity }
        set { lock.lock(); defer { lock.unlock() }; _bounceIntensity = newValue }
    }
    
    private init() {}
    
    /// Convert direction degrees to horizontal velocity component range
    public var horizontalWindVelocity: CGFloat {
        return CGFloat(direction) * 10.0
    }
}

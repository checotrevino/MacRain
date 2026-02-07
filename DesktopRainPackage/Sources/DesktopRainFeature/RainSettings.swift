import Foundation
import CoreGraphics

/// Model for user-configurable rain settings
public final class RainSettings: @unchecked Sendable {
    public static let shared = RainSettings()
    
    private let lock = NSLock()
    
    private var _intensity: Float = 1.0
    public var intensity: Float {
        get { lock.lock(); defer { lock.unlock() }; return _intensity }
        set { 
            lock.lock(); _intensity = newValue; lock.unlock()
            AudioManager.shared.updateFromSettings()
        }
    }
    
    private var _direction: Float = 0
    public var direction: Float {
        get { lock.lock(); defer { lock.unlock() }; return _direction }
        set { 
            lock.lock(); _direction = newValue; lock.unlock()
            AudioManager.shared.updateFromSettings()
        }
    }
    
    private var _bounceIntensity: Float = 1.0
    public var bounceIntensity: Float {
        get { lock.lock(); defer { lock.unlock() }; return _bounceIntensity }
        set { 
            lock.lock(); _bounceIntensity = newValue; lock.unlock()
            AudioManager.shared.updateFromSettings()
        }
    }
    
    private var _isSoundEnabled: Bool = false
    public var isSoundEnabled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _isSoundEnabled }
        set { 
            lock.lock(); _isSoundEnabled = newValue; lock.unlock()
            if newValue { AudioManager.shared.start() }
            AudioManager.shared.updateFromSettings()
        }
    }
    
    private init() {}
    
    /// Real-life inspired rain presets
    public enum RainPreset: String, CaseIterable {
        case gentleMist = "Gentle Mist"
        case springDrizzle = "Spring Drizzle"
        case tropicalDownpour = "Tropical Downpour"
        case windyStorm = "Windy Storm"
        case zenGarden = "Zen Garden"
    }
    
    /// Distinct audio profiles
    public enum SoundProfile: String, CaseIterable {
        case mist = "Mist"
        case drizzle = "Drizzle"
        case downpour = "Downpour"
        case storm = "Storm"
        case zen = "Zen"
    }
    
    /// Apply a preset to the current settings
    public func applyPreset(_ preset: RainPreset) {
        switch preset {
        case .gentleMist:
            intensity = 0.5
            direction = 0
            bounceIntensity = 0.5
            soundProfile = .mist
        case .springDrizzle:
            intensity = 1.0
            direction = 15 // Subtle from left
            bounceIntensity = 1.0
            soundProfile = .drizzle
        case .tropicalDownpour:
            intensity = 4.0 // Extreme
            direction = 0
            bounceIntensity = 0.5 // Heavy rain splats more
            soundProfile = .downpour
        case .windyStorm:
            intensity = 2.0 // Heavy
            direction = -15 // Subtle from right
            bounceIntensity = 1.0
            soundProfile = .storm
        case .zenGarden:
            intensity = 0.5
            direction = 0
            bounceIntensity = 0 // No bounce
            soundProfile = .zen
        }
    }
    
    private var _soundProfile: SoundProfile = .drizzle
    public var soundProfile: SoundProfile {
        get { lock.lock(); defer { lock.unlock() }; return _soundProfile }
        set { 
            lock.lock(); _soundProfile = newValue; lock.unlock()
            AudioManager.shared.updateFromSettings()
        }
    }
    
    /// Convert direction degrees to horizontal velocity component range
    public var horizontalWindVelocity: CGFloat {
        return CGFloat(direction) * 10.0
    }
}

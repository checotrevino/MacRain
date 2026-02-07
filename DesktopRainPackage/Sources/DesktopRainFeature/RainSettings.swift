import Foundation
import CoreGraphics

/// Model for user-configurable rain settings
public final class RainSettings: @unchecked Sendable {
    public static let shared = RainSettings()
    
    private let lock = NSLock()
    
    private var _intensity: Float = 1.5 // Gentle Mist default
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
    
    private var _bounceIntensity: Float = 0.2 // Gentle Mist default
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
    
    private var _isThunderEnabled: Bool = true
    public var isThunderEnabled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _isThunderEnabled }
        set { lock.lock(); _isThunderEnabled = newValue; lock.unlock() }
    }
    
    private var _thunderProbability: Double = 0.0001 // Gentle Mist default
    public var thunderProbability: Double {
        get { lock.lock(); defer { lock.unlock() }; return _thunderProbability }
        set { lock.lock(); _thunderProbability = newValue; lock.unlock() }
    }
    
    private var _dropSizeMultiplier: Float = 0.3 // Gentle Mist default
    public var dropSizeMultiplier: Float {
        get { lock.lock(); defer { lock.unlock() }; return _dropSizeMultiplier }
        set { lock.lock(); _dropSizeMultiplier = newValue; lock.unlock() }
    }
    
    private var _dropSpeedMultiplier: Float = 0.4 // Gentle Mist default
    public var dropSpeedMultiplier: Float {
        get { lock.lock(); defer { lock.unlock() }; return _dropSpeedMultiplier }
        set { lock.lock(); _dropSpeedMultiplier = newValue; lock.unlock() }
    }
    
    private var _soundProfile: SoundProfile = .mist // Gentle Mist default
    public var soundProfile: SoundProfile {
        get { lock.lock(); defer { lock.unlock() }; return _soundProfile }
        set { 
            lock.lock(); _soundProfile = newValue; lock.unlock()
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
            intensity = 1.5 // More particles but tiny
            direction = 0
            bounceIntensity = 0.2
            soundProfile = .mist
            thunderProbability = 0.0001
            dropSizeMultiplier = 0.3
            dropSpeedMultiplier = 0.4
        case .springDrizzle:
            intensity = 1.0
            direction = 15 // Subtle from left
            bounceIntensity = 1.0
            soundProfile = .drizzle
            thunderProbability = 0.0003
            dropSizeMultiplier = 1.0
            dropSpeedMultiplier = 1.0
        case .tropicalDownpour:
            intensity = 4.0 // Extreme
            direction = 0
            bounceIntensity = 0.5 // Heavy rain splats more
            soundProfile = .downpour
            thunderProbability = 0.001
            dropSizeMultiplier = 1.2
            dropSpeedMultiplier = 1.2
        case .windyStorm:
            intensity = 2.0 // Heavy
            direction = -15 // Subtle from right
            bounceIntensity = 1.0
            soundProfile = .storm
            thunderProbability = 0.002
            dropSizeMultiplier = 1.0
            dropSpeedMultiplier = 1.1
        case .zenGarden:
            intensity = 0.5
            direction = 0
            bounceIntensity = 0 // No bounce
            soundProfile = .zen
            thunderProbability = 0
            dropSizeMultiplier = 0.8
            dropSpeedMultiplier = 0.7
        }
    }
    
    /// Convert direction degrees to horizontal velocity component range
    public var horizontalWindVelocity: CGFloat {
        return CGFloat(direction) * 10.0
    }
}

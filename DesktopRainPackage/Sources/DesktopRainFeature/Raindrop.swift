import Foundation
import CoreGraphics

/// Represents a single raindrop particle with physics properties
public struct Raindrop {
    /// Current position
    public var x: CGFloat
    public var y: CGFloat
    
    /// Velocity (points per second)
    public var vx: CGFloat
    public var vy: CGFloat
    
    /// Visual properties
    public var width: CGFloat
    public var length: CGFloat
    public var opacity: Float
    
    /// Lifecycle state
    public var isActive: Bool
    public var bounceCount: Int
    
    /// Creates a new raindrop at the given position
    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
        
        let settings = RainSettings.shared
        let sizeMult = CGFloat(settings.dropSizeMultiplier)
        let speedMult = CGFloat(settings.dropSpeedMultiplier)
        
        // Base horizontal drift + user wind setting
        let wind = settings.horizontalWindVelocity
        self.vx = wind + CGFloat.random(in: -20...20)
        
        // Strong downward velocity (800-1200 pts/s)
        self.vy = CGFloat.random(in: 800...1200) * speedMult
        
        // Varying sizes
        self.width = CGFloat.random(in: 1.5...3.0) * sizeMult
        self.length = CGFloat.random(in: 15...40) * sizeMult
        
        self.opacity = Float.random(in: 0.4...0.8)
        self.isActive = true
        self.bounceCount = 0
    }
    
    /// Reset raindrop to spawn at top of screen
    public mutating func respawn(screenWidth: CGFloat, screenHeight: CGFloat) {
        let settings = RainSettings.shared
        let sizeMult = CGFloat(settings.dropSizeMultiplier)
        let speedMult = CGFloat(settings.dropSpeedMultiplier)

        x = CGFloat.random(in: -100...(screenWidth + 100))
        y = -length
        
        let wind = settings.horizontalWindVelocity
        vx = wind + CGFloat.random(in: -20...20)
        vy = CGFloat.random(in: 800...1200) * speedMult
        
        width = CGFloat.random(in: 1.5...3.0) * sizeMult
        length = CGFloat.random(in: 15...40) * sizeMult
        opacity = Float.random(in: 0.4...0.8)
        
        isActive = true
        bounceCount = 0
    }
}

/// Represents a splash particle created when raindrop hits the dock
public struct SplashParticle {
    public var x: CGFloat
    public var y: CGFloat
    public var vx: CGFloat
    public var vy: CGFloat
    public var radius: CGFloat
    public var opacity: Float
    public var lifetime: CGFloat
    public var maxLifetime: CGFloat
    public var isActive: Bool
    
    /// Creates a splash particle from an impact point
    public init(impactX: CGFloat, impactY: CGFloat) {
        self.x = impactX
        self.y = impactY
        
        // Radial explosion pattern
        let angle = CGFloat.random(in: -CGFloat.pi...(-0.1)) // Upward arc
        let speed = CGFloat.random(in: 100...300)
        self.vx = cos(angle) * speed
        self.vy = -sin(angle) * speed // Negative because y increases downward in our model
        
        let settings = RainSettings.shared
        let sizeMult = CGFloat(settings.dropSizeMultiplier)
        
        self.radius = CGFloat.random(in: 1.0...3.0) * sizeMult
        self.opacity = Float.random(in: 0.5...0.9)
        self.maxLifetime = CGFloat.random(in: 0.2...0.5)
        self.lifetime = maxLifetime
        self.isActive = true
    }
}

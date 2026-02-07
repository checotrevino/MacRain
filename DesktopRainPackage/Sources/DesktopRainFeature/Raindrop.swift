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
        
        // Slight horizontal drift (-30 to 30 pts/s)
        self.vx = CGFloat.random(in: -30...30)
        
        // Strong downward velocity (800-1200 pts/s for realistic fast rain)
        self.vy = CGFloat.random(in: 800...1200)
        
        // Varying sizes for depth perception
        self.width = CGFloat.random(in: 1.5...3.0)
        self.length = CGFloat.random(in: 15...35)
        
        // Slight opacity variation
        self.opacity = Float.random(in: 0.4...0.8)
        
        self.isActive = true
        self.bounceCount = 0
    }
    
    /// Reset raindrop to spawn at top of screen
    public mutating func respawn(screenWidth: CGFloat, screenHeight: CGFloat) {
        x = CGFloat.random(in: 0...screenWidth)
        y = -length // Start just above top of screen
        
        vx = CGFloat.random(in: -30...30)
        vy = CGFloat.random(in: 800...1200)
        
        width = CGFloat.random(in: 1.5...3.0)
        length = CGFloat.random(in: 15...35)
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
        
        self.radius = CGFloat.random(in: 1.0...3.0)
        self.opacity = Float.random(in: 0.5...0.9)
        self.maxLifetime = CGFloat.random(in: 0.2...0.5)
        self.lifetime = maxLifetime
        self.isActive = true
    }
}

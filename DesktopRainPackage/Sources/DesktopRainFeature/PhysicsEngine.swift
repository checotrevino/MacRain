import Foundation
import CoreGraphics

/// Physics engine for realistic raindrop simulation with dock bouncing
public class PhysicsEngine {
    
    // MARK: - Physics Constants
    
    /// Gravity acceleration (points per second²)
    private let gravity: CGFloat = 980
    
    /// Terminal velocity for raindrops (points per second)
    private let terminalVelocity: CGFloat = 1500
    
    /// Coefficient of restitution for water (lower is more 'splat', less 'bounce')
    private let restitution: CGFloat = 0.15
    
    /// Friction coefficient for horizontal velocity on bounce
    private let friction: CGFloat = 0.5
    
    /// Minimum velocity to continue bouncing (below this, drop dies)
    private let minBounceVelocity: CGFloat = 100
    
    /// Maximum bounces before drop is deactivated
    private let maxBounces = 1
    
    // MARK: - State
    
    private let dockDetector = DockDetector()
    private let windowDetector = WindowDetector()
    private var screenWidth: CGFloat = 0
    private var screenHeight: CGFloat = 0
    private var dockFrame: CGRect = .zero
    private var windowFrames: [CGRect] = []
    
    public init() {}
    
    /// Update screen dimensions and dock position
    public func updateScreenInfo(width: CGFloat, height: CGFloat) {
        screenWidth = width
        screenHeight = height
        dockFrame = dockDetector.dockFrameInViewCoordinates(screenHeight: height)
    }

    /// Refresh current window list
    public func updateWindowInfo() {
        windowFrames = windowDetector.detectVisibleWindows(screenHeight: screenHeight)
    }
    
    /// Update a raindrop's physics for one frame
    /// - Parameters:
    ///   - drop: The raindrop to update
    ///   - deltaTime: Time since last update in seconds
    /// - Returns: Array of splash particles if collision occurred
    public func update(drop: inout Raindrop, deltaTime: CGFloat) -> [SplashParticle] {
        guard drop.isActive else { return [] }
        
        var splashes: [SplashParticle] = []
        
        // Apply gravity
        drop.vy += gravity * deltaTime
        
        // Clamp to terminal velocity
        if drop.vy > terminalVelocity {
            drop.vy = terminalVelocity
        }
        
        // Update position
        drop.x += drop.vx * deltaTime
        drop.y += drop.vy * deltaTime
        
        // Check window collisions
        for window in windowFrames {
            if checkCollision(drop: &drop, surface: window, isDock: false, splashes: &splashes) {
                return splashes // Return early if hitting a window to avoid passing through
            }
        }

        // Check dock collision
        if !dockFrame.isEmpty {
            _ = checkCollision(drop: &drop, surface: dockFrame, isDock: true, splashes: &splashes)
        }
        
        // Check if drop went off screen
        if drop.y > screenHeight + 50 || drop.x < -50 || drop.x > screenWidth + 50 {
            drop.isActive = false
        }
        
        return splashes
    }
    
    /// Check and handle collision with a surface
    private func checkCollision(drop: inout Raindrop, surface: CGRect, isDock: Bool, splashes: inout [SplashParticle]) -> Bool {
        let surfaceTop = surface.minY
        let dropBottom = drop.y + drop.length
        
        // Detect impact with top edge - use a tighter threshold for points (e.g., 5-10 pts)
        if dropBottom >= surfaceTop && drop.y < surfaceTop + 10 {
            if drop.x >= surface.minX && drop.x <= surface.maxX {
                // Collision!
                splashes.append(contentsOf: handleCollision(drop: &drop, surfaceTop: surfaceTop, isDock: isDock))
                return true
            }
        }
        return false
    }

    /// Handle collision with a surface, applying bounce/drip physics
    private func handleCollision(drop: inout Raindrop, surfaceTop: CGFloat, isDock: Bool) -> [SplashParticle] {
        drop.bounceCount += 1
        
        // Position correction - place drop on top of surface
        drop.y = surfaceTop - drop.length
        
        // Apply bounce/splat physics
        // Scale restitution by user setting
        let activeRestitution = CGFloat(0.15 * RainSettings.shared.bounceIntensity)
        drop.vy = -drop.vy * activeRestitution
        
        // Apply friction and wind drift from settings
        drop.vx *= friction
        let windDrift = RainSettings.shared.horizontalWindVelocity
        drop.vx += windDrift * 0.1 + CGFloat.random(in: -10...10)
        
        // Reduce opacity and size significantly on first hit
        drop.opacity *= 0.5
        drop.length *= 0.4
        drop.width *= 1.2 // Flatten it out
        
        // Check if drop should die (splat)
        if abs(drop.vy) < minBounceVelocity || drop.bounceCount >= maxBounces {
            drop.isActive = false
        }
        
        // Generate splash particles - reduced count for realism
        return generateSplash(at: drop.x, y: surfaceTop, intensity: isDock ? 0.8 : 0.6)
    }
    
    /// Generate splash particles at impact point
    private func generateSplash(at x: CGFloat, y: CGFloat, intensity: CGFloat) -> [SplashParticle] {
        // Reduced base particle count (2-4 instead of 3-6)
        let particleCount = Int(CGFloat.random(in: 2...4) * intensity)
        var particles: [SplashParticle] = []
        
        for _ in 0..<particleCount {
            particles.append(SplashParticle(impactX: x, impactY: y))
        }
        
        return particles
    }
    
    /// Update a splash particle's physics
    public func update(splash: inout SplashParticle, deltaTime: CGFloat) {
        guard splash.isActive else { return }
        
        // Apply gravity (weaker for tiny droplets)
        splash.vy += gravity * 0.5 * deltaTime
        
        // Update position
        splash.x += splash.vx * deltaTime
        splash.y += splash.vy * deltaTime
        
        // Update lifetime
        splash.lifetime -= deltaTime
        splash.opacity = Float(splash.lifetime / splash.maxLifetime) * 0.8
        
        // Deactivate if lifetime expired or off screen
        if splash.lifetime <= 0 || splash.y > screenHeight + 10 {
            splash.isActive = false
        }
    }
}

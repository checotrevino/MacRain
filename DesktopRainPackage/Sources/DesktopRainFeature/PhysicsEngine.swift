import Foundation
import CoreGraphics

/// Physics engine for realistic raindrop simulation with dock bouncing
public class PhysicsEngine {
    
    // MARK: - Physics Constants
    
    /// Gravity acceleration (points per second²)
    private let gravity: CGFloat = 980
    
    /// Terminal velocity for raindrops (points per second)
    private let terminalVelocity: CGFloat = 1500
    
    /// Coefficient of restitution for water bouncing off the dock (0.3-0.5 for realistic water)
    private let restitution: CGFloat = 0.35
    
    /// Friction coefficient for horizontal velocity on bounce
    private let friction: CGFloat = 0.7
    
    /// Minimum velocity to continue bouncing (below this, drop dies)
    private let minBounceVelocity: CGFloat = 50
    
    /// Maximum bounces before drop is deactivated
    private let maxBounces = 2
    
    // MARK: - State
    
    private let dockDetector = DockDetector()
    private var screenWidth: CGFloat = 0
    private var screenHeight: CGFloat = 0
    private var dockFrame: CGRect = .zero
    
    public init() {}
    
    /// Update screen dimensions and dock position
    public func updateScreenInfo(width: CGFloat, height: CGFloat) {
        screenWidth = width
        screenHeight = height
        dockFrame = dockDetector.dockFrameInViewCoordinates(screenHeight: height)
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
        
        // Check dock collision
        if !dockFrame.isEmpty {
            let dockTop = dockFrame.minY
            let dropBottom = drop.y + drop.length
            
            // Check if drop hit the dock
            if dropBottom >= dockTop && drop.y < dockTop + dockFrame.height {
                if drop.x >= dockFrame.minX && drop.x <= dockFrame.maxX {
                    // Collision with dock!
                    splashes = handleDockCollision(drop: &drop, dockTop: dockTop)
                }
            }
        }
        
        // Check if drop went off screen
        if drop.y > screenHeight + 50 || drop.x < -50 || drop.x > screenWidth + 50 {
            drop.isActive = false
        }
        
        return splashes
    }
    
    /// Handle collision with dock, applying bounce physics
    private func handleDockCollision(drop: inout Raindrop, dockTop: CGFloat) -> [SplashParticle] {
        drop.bounceCount += 1
        
        // Position correction - place drop on top of dock
        drop.y = dockTop - drop.length
        
        // Apply bounce physics
        // Reverse vertical velocity with energy loss
        drop.vy = -drop.vy * restitution
        
        // Apply friction to horizontal velocity
        drop.vx *= friction
        
        // Add some randomness to make it look more natural
        drop.vx += CGFloat.random(in: -20...20)
        
        // Reduce opacity after bounce
        drop.opacity *= 0.7
        
        // Shorten the drop after impact (it's breaking up)
        drop.length *= 0.6
        drop.width *= 0.8
        
        // Check if drop should die
        if abs(drop.vy) < minBounceVelocity || drop.bounceCount >= maxBounces {
            drop.isActive = false
        }
        
        // Generate splash particles
        return generateSplash(at: drop.x, y: dockTop, intensity: drop.bounceCount == 1 ? 1.0 : 0.5)
    }
    
    /// Generate splash particles at impact point
    private func generateSplash(at x: CGFloat, y: CGFloat, intensity: CGFloat) -> [SplashParticle] {
        let particleCount = Int(CGFloat.random(in: 3...6) * intensity)
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

import Foundation
import Metal
import MetalKit
import simd

/// Metal-based renderer for hyper-realistic rain effects
public class RainRenderer: NSObject, MTKViewDelegate {
    
    // MARK: - Metal Objects
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var raindropPipeline: MTLRenderPipelineState!
    private var splashPipeline: MTLRenderPipelineState!
    
    // MARK: - Particle System
    
    private var raindrops: [Raindrop] = []
    private var splashParticles: [SplashParticle] = []
    private let physicsEngine = PhysicsEngine()
    
    /// Number of active raindrops
    private let raindropCount = 1200
    
    /// Maximum splash particles
    private let maxSplashParticles = 500
    
    // MARK: - Timing
    
    private var lastUpdateTime: CFTimeInterval = 0
    
    // MARK: - Screen Info
    
    private var screenWidth: CGFloat = 0
    private var screenHeight: CGFloat = 0
    
    // MARK: - Initialization
    
    public init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        super.init()
        
        setupPipelines()
    }
    
    private func setupPipelines() {
        // Create shader library from source
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct RaindropVertex {
            float2 position [[position]];
            float opacity;
            float2 uv;
        };
        
        struct RaindropInstance {
            float2 position;
            float2 size;  // width, length
            float opacity;
        };
        
        struct SplashInstance {
            float2 position;
            float radius;
            float opacity;
        };
        
        // Raindrop vertex shader
        vertex RaindropVertex raindrop_vertex(
            uint vertexID [[vertex_id]],
            uint instanceID [[instance_id]],
            constant RaindropInstance *instances [[buffer(0)]],
            constant float2 &screenSize [[buffer(1)]]
        ) {
            RaindropInstance inst = instances[instanceID];
            
            // Quad vertices (2 triangles)
            float2 positions[6] = {
                float2(-0.5, 0), float2(0.5, 0), float2(-0.5, 1),
                float2(0.5, 0), float2(0.5, 1), float2(-0.5, 1)
            };
            float2 uvs[6] = {
                float2(0, 0), float2(1, 0), float2(0, 1),
                float2(1, 0), float2(1, 1), float2(0, 1)
            };
            
            float2 pos = positions[vertexID];
            
            // Scale by instance size
            pos.x *= inst.size.x;
            pos.y *= inst.size.y;
            
            // Translate to instance position
            pos += inst.position;
            
            // Convert to normalized device coordinates
            pos = (pos / screenSize) * 2.0 - 1.0;
            pos.y = -pos.y;  // Flip Y for Metal coordinate system
            
            RaindropVertex out;
            out.position = float4(pos, 0, 1);
            out.opacity = inst.opacity;
            out.uv = uvs[vertexID];
            
            return out;
        }
        
        // Raindrop fragment shader - creates realistic rain streak
        fragment float4 raindrop_fragment(RaindropVertex in [[stage_in]]) {
            // Create gradient for motion blur effect
            float gradient = 1.0 - in.uv.y;
            gradient = pow(gradient, 0.5);  // Soften the gradient
            
            // Horizontal falloff for round edges
            float centerDist = abs(in.uv.x - 0.5) * 2.0;
            float edgeFade = 1.0 - pow(centerDist, 2.0);
            
            // Combine for final alpha
            float alpha = gradient * edgeFade * in.opacity;
            
            // Slight blue tint for water
            float3 rainColor = float3(0.7, 0.8, 1.0);
            
            return float4(rainColor, alpha);
        }
        
        // Splash vertex shader
        vertex RaindropVertex splash_vertex(
            uint vertexID [[vertex_id]],
            uint instanceID [[instance_id]],
            constant SplashInstance *instances [[buffer(0)]],
            constant float2 &screenSize [[buffer(1)]]
        ) {
            SplashInstance inst = instances[instanceID];
            
            // Quad vertices for circle
            float2 positions[6] = {
                float2(-1, -1), float2(1, -1), float2(-1, 1),
                float2(1, -1), float2(1, 1), float2(-1, 1)
            };
            float2 uvs[6] = {
                float2(0, 0), float2(1, 0), float2(0, 1),
                float2(1, 0), float2(1, 1), float2(0, 1)
            };
            
            float2 pos = positions[vertexID] * inst.radius + inst.position;
            
            pos = (pos / screenSize) * 2.0 - 1.0;
            pos.y = -pos.y;
            
            RaindropVertex out;
            out.position = float4(pos, 0, 1);
            out.opacity = inst.opacity;
            out.uv = uvs[vertexID];
            
            return out;
        }
        
        // Splash fragment shader - circular droplet
        fragment float4 splash_fragment(RaindropVertex in [[stage_in]]) {
            float2 centered = in.uv * 2.0 - 1.0;
            float dist = length(centered);
            
            // Soft circle
            float alpha = 1.0 - smoothstep(0.5, 1.0, dist);
            alpha *= in.opacity;
            
            float3 splashColor = float3(0.75, 0.85, 1.0);
            
            return float4(splashColor, alpha);
        }
        """
        
        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            
            // Raindrop pipeline
            let raindropDesc = MTLRenderPipelineDescriptor()
            raindropDesc.vertexFunction = library.makeFunction(name: "raindrop_vertex")
            raindropDesc.fragmentFunction = library.makeFunction(name: "raindrop_fragment")
            raindropDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
            raindropDesc.colorAttachments[0].isBlendingEnabled = true
            raindropDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            raindropDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            raindropDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
            raindropDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            raindropPipeline = try device.makeRenderPipelineState(descriptor: raindropDesc)
            
            // Splash pipeline (same shaders structure, different functions)
            let splashDesc = MTLRenderPipelineDescriptor()
            splashDesc.vertexFunction = library.makeFunction(name: "splash_vertex")
            splashDesc.fragmentFunction = library.makeFunction(name: "splash_fragment")
            splashDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
            splashDesc.colorAttachments[0].isBlendingEnabled = true
            splashDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            splashDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            splashDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
            splashDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            splashPipeline = try device.makeRenderPipelineState(descriptor: splashDesc)
            
        } catch {
            print("Failed to create pipeline: \(error)")
        }
    }
    
    // MARK: - Particle Management
    
    private func initializeRaindrops() {
        raindrops.removeAll()
        
        for _ in 0..<raindropCount {
            // Distribute drops across screen with random Y positions for staggered start
            let x = CGFloat.random(in: 0...screenWidth)
            let y = CGFloat.random(in: -screenHeight...screenHeight)
            raindrops.append(Raindrop(x: x, y: y))
        }
    }
    
    // MARK: - MTKViewDelegate
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        screenWidth = size.width
        screenHeight = size.height
        physicsEngine.updateScreenInfo(width: screenWidth, height: screenHeight)
        
        if raindrops.isEmpty {
            initializeRaindrops()
        }
    }
    
    public func draw(in view: MTKView) {
        // Calculate delta time
        let currentTime = CACurrentMediaTime()
        let deltaTime = lastUpdateTime > 0 ? CGFloat(currentTime - lastUpdateTime) : 1.0/60.0
        lastUpdateTime = currentTime
        
        // Cap delta time to prevent huge jumps
        let clampedDelta = min(deltaTime, 1.0/30.0)
        
        // Update physics
        updatePhysics(deltaTime: clampedDelta)
        
        // Render
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Render raindrops
        renderRaindrops(encoder: renderEncoder)
        
        // Render splash particles
        renderSplashes(encoder: renderEncoder)
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func updatePhysics(deltaTime: CGFloat) {
        // Update raindrops
        for i in 0..<raindrops.count {
            if raindrops[i].isActive {
                let splashes = physicsEngine.update(drop: &raindrops[i], deltaTime: deltaTime)
                
                // Add new splash particles
                for splash in splashes {
                    if splashParticles.count < maxSplashParticles {
                        splashParticles.append(splash)
                    } else {
                        // Recycle inactive splash particle
                        if let inactiveIndex = splashParticles.firstIndex(where: { !$0.isActive }) {
                            splashParticles[inactiveIndex] = splash
                        }
                    }
                }
            } else {
                // Respawn inactive drop at top
                raindrops[i].respawn(screenWidth: screenWidth, screenHeight: screenHeight)
            }
        }
        
        // Update splash particles
        for i in 0..<splashParticles.count {
            if splashParticles[i].isActive {
                physicsEngine.update(splash: &splashParticles[i], deltaTime: deltaTime)
            }
        }
        
        // Clean up dead splash particles periodically
        splashParticles.removeAll { !$0.isActive }
    }
    
    private func renderRaindrops(encoder: MTLRenderCommandEncoder) {
        guard !raindrops.isEmpty else { return }
        
        encoder.setRenderPipelineState(raindropPipeline)
        
        // Prepare instance data
        struct RaindropInstance {
            var position: SIMD2<Float>
            var size: SIMD2<Float>
            var opacity: Float
            var padding: Float = 0 // Align to 16 bytes
        }
        
        let activeDrops = raindrops.filter { $0.isActive }
        var instances = activeDrops.map { drop in
            RaindropInstance(
                position: SIMD2<Float>(Float(drop.x), Float(drop.y)),
                size: SIMD2<Float>(Float(drop.width), Float(drop.length)),
                opacity: drop.opacity
            )
        }
        
        guard !instances.isEmpty else { return }
        
        var screenSize = SIMD2<Float>(Float(screenWidth), Float(screenHeight))
        
        encoder.setVertexBytes(&instances, length: instances.count * MemoryLayout<RaindropInstance>.stride, index: 0)
        encoder.setVertexBytes(&screenSize, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: instances.count)
    }
    
    private func renderSplashes(encoder: MTLRenderCommandEncoder) {
        let activeSplashes = splashParticles.filter { $0.isActive }
        guard !activeSplashes.isEmpty else { return }
        
        encoder.setRenderPipelineState(splashPipeline)
        
        struct SplashInstance {
            var position: SIMD2<Float>
            var radius: Float
            var opacity: Float
        }
        
        var instances = activeSplashes.map { splash in
            SplashInstance(
                position: SIMD2<Float>(Float(splash.x), Float(splash.y)),
                radius: Float(splash.radius),
                opacity: splash.opacity
            )
        }
        
        var screenSize = SIMD2<Float>(Float(screenWidth), Float(screenHeight))
        
        encoder.setVertexBytes(&instances, length: instances.count * MemoryLayout<SplashInstance>.stride, index: 0)
        encoder.setVertexBytes(&screenSize, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: instances.count)
    }
}

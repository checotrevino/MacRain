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
    private var raindropBuffer: MTLBuffer?
    private var splashBuffer: MTLBuffer?
    
    // MARK: - Particle System
    
    private var raindrops: [Raindrop] = []
    private var splashParticles: [SplashParticle] = []
    private let physicsEngine = PhysicsEngine()
    
    /// Base number of raindrops (Medium intensity)
    private let baseRaindropCount = 1200
    
    /// Target number of raindrops based on settings
    private var targetRaindropCount: Int {
        Int(Float(baseRaindropCount) * RainSettings.shared.intensity)
    }
    
    /// Maximum possible raindrops for buffer allocation
    private let maxRaindropCount = 5000
    
    /// Maximum splash particles
    private let maxSplashParticles = 500
    
    // MARK: - Timing
    
    private var lastUpdateTime: CFTimeInterval = 0
    private var lastWindowUpdateTime: CFTimeInterval = 0
    
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
            float4 position [[position]];
            float opacity;
            float2 uv;
        };
        
        struct RaindropInstance {
            float2 position;
            float2 size;  // width, length
            float opacity;
            float padding; // Alignment to 24 bytes
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
        
        // Raindrop fragment shader - creates realistic teardrop/streak
        fragment float4 raindrop_fragment(RaindropVertex in [[stage_in]]) {
            // Teardrop shape: bulbous at the bottom (uv.y near 1.0), tapering at top
            // Horizontal falloff that narrows towards the top
            float xOffset = abs(in.uv.x - 0.5) * 2.0;
            
            // Width varies with y: wider at bottom (1.0), narrower at top (0.0)
            float widthAtY = mix(0.3, 1.0, in.uv.y);
            float edgeFade = 1.0 - smoothstep(widthAtY - 0.1, widthAtY + 0.1, xOffset);
            
            // Motion blur tail: brighter at bottom, fades out towards top
            float verticalFade = pow(in.uv.y, 1.5);
            
            // Combine for final alpha
            float alpha = verticalFade * edgeFade * in.opacity;
            
            // Cooler water color with slight translucency
            float3 rainColor = float3(0.8, 0.9, 1.0);
            
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
        
        // Splash fragment shader - more realistic water burst
        fragment float4 splash_fragment(RaindropVertex in [[stage_in]]) {
            float2 centered = in.uv * 2.0 - 1.0;
            float dist = length(centered);
            
            // Create a ring effect for some splashes
            float circle = 1.0 - smoothstep(0.4, 0.7, dist);
            float ring = smoothstep(0.2, 0.5, dist) * (1.0 - smoothstep(0.5, 0.8, dist));
            
            float alpha = mix(circle, ring, 0.3) * in.opacity;
            
            float3 splashColor = float3(0.85, 0.92, 1.0);
            
            return float4(splashColor, alpha);
        }
        """
        
        do {
            print("🔧 Creating Metal shader library...")
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            print("✅ Shader library created successfully")
            
            // Raindrop pipeline
            let raindropDesc = MTLRenderPipelineDescriptor()
            raindropDesc.vertexFunction = library.makeFunction(name: "raindrop_vertex")
            raindropDesc.fragmentFunction = library.makeFunction(name: "raindrop_fragment")
            
            if raindropDesc.vertexFunction == nil {
                print("❌ Failed to find raindrop_vertex function")
            }
            if raindropDesc.fragmentFunction == nil {
                print("❌ Failed to find raindrop_fragment function")
            }
            
            raindropDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
            raindropDesc.colorAttachments[0].isBlendingEnabled = true
            raindropDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            raindropDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            raindropDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
            raindropDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            print("🔧 Creating raindrop pipeline...")
            raindropPipeline = try device.makeRenderPipelineState(descriptor: raindropDesc)
            print("✅ Raindrop pipeline created successfully")
            
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
            
            print("🔧 Creating splash pipeline...")
            splashPipeline = try device.makeRenderPipelineState(descriptor: splashDesc)
            print("✅ Splash pipeline created successfully")
            
            // Pre-allocate buffers
            setupBuffers()
            
        } catch {
            print("❌ Failed to create pipeline: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
        }
    }
    
    private func setupBuffers() {
        let raindropBufferSize = maxRaindropCount * 24 // Pre-allocate for max intensity
        raindropBuffer = device.makeBuffer(length: raindropBufferSize, options: .storageModeShared)
        
        let splashBufferSize = maxSplashParticles * 16 // 16 bytes per instance
        splashBuffer = device.makeBuffer(length: splashBufferSize, options: .storageModeShared)
        
        print("📦 Metal buffers allocated (Max support). Raindrop: \(raindropBufferSize) bytes, Splash: \(splashBufferSize) bytes")
    }
    
    // MARK: - Particle Management
    
    private func initializeRaindrops() {
        raindrops.removeAll()
        
        for _ in 0..<maxRaindropCount {
            // Distribute drops across screen with random Y positions for staggered start
            let x = CGFloat.random(in: 0...screenWidth)
            let y = CGFloat.random(in: -screenHeight...screenHeight)
            raindrops.append(Raindrop(x: x, y: y))
        }
    }
    
    // MARK: - MTKViewDelegate
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // We standardize on point-based coordinates for physics and rendering to match macOS APIs
        let pointSize = view.bounds.size
        print("📐 View size (points): \(pointSize), Drawable size (pixels): \(size)")
        
        screenWidth = pointSize.width
        screenHeight = pointSize.height
        physicsEngine.updateScreenInfo(width: screenWidth, height: screenHeight)
        
        if raindrops.isEmpty {
            print("🌧️ Initializing \(maxRaindropCount) raindrops for buffer pool")
            initializeRaindrops()
        }
    }
    
    public func draw(in view: MTKView) {
        // Auto-initialize if needed (fallback if drawableSizeWillChange wasn't called)
        if raindrops.isEmpty && screenWidth > 0 && screenHeight > 0 {
            initializeRaindrops()
        }
        
        // Calculate delta time
        let currentTime = CACurrentMediaTime()
        let deltaTime = lastUpdateTime > 0 ? CGFloat(currentTime - lastUpdateTime) : 1.0/60.0
        lastUpdateTime = currentTime
        
        // Cap delta time to prevent huge jumps
        let clampedDelta = min(deltaTime, 1.0/30.0)
        
        // Update physics
        updatePhysics(deltaTime: clampedDelta)
        
        // Update windows periodically (every 0.1 seconds)
        if currentTime - lastWindowUpdateTime > 0.1 {
            physicsEngine.updateWindowInfo()
            lastWindowUpdateTime = currentTime
        }
        
        // Check if pipelines are valid
        if raindropPipeline == nil {
            print("❌ Raindrop pipeline is nil, cannot render")
            return
        }
        
        // Render
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("❌ Failed to get drawable or create command buffer")
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
        guard !raindrops.isEmpty, let buffer = raindropBuffer else { return }
        
        encoder.setRenderPipelineState(raindropPipeline)
        
        // Prepare instance data
        struct RaindropInstance {
            var position: SIMD2<Float>
            var size: SIMD2<Float>
            var opacity: Float
            var padding: Float = 0
        }
        
        let count = targetRaindropCount
        let activeDrops = raindrops.prefix(count)
        guard count > 0 else { return }
        
        // Update buffer contents safely
        let contents = buffer.contents().bindMemory(to: RaindropInstance.self, capacity: count)
        for i in 0..<count {
            let drop = activeDrops[i]
            contents[i] = RaindropInstance(
                position: SIMD2<Float>(Float(drop.x), Float(drop.y)),
                size: SIMD2<Float>(Float(drop.width), Float(drop.length)),
                opacity: drop.opacity
            )
        }
        
        var screenSize = SIMD2<Float>(Float(screenWidth), Float(screenHeight))
        
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setVertexBytes(&screenSize, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: count)
    }
    
    private func renderSplashes(encoder: MTLRenderCommandEncoder) {
        let activeSplashes = splashParticles.filter { $0.isActive }
        let count = min(activeSplashes.count, maxSplashParticles)
        guard count > 0, let buffer = splashBuffer else { return }
        
        encoder.setRenderPipelineState(splashPipeline)
        
        struct SplashInstance {
            var position: SIMD2<Float>
            var radius: Float
            var opacity: Float
        }
        
        // Update buffer contents safely
        let contents = buffer.contents().bindMemory(to: SplashInstance.self, capacity: count)
        for i in 0..<count {
            let splash = activeSplashes[i]
            contents[i] = SplashInstance(
                position: SIMD2<Float>(Float(splash.x), Float(splash.y)),
                radius: Float(splash.radius),
                opacity: splash.opacity
            )
        }
        
        var screenSize = SIMD2<Float>(Float(screenWidth), Float(screenHeight))
        
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setVertexBytes(&screenSize, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: count)
    }
}

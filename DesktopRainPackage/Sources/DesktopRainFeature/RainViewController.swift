import AppKit
import MetalKit

/// View controller hosting the Metal-rendered rain overlay
public class RainViewController: NSViewController {
    
    private var mtkView: MTKView!
    private var renderer: RainRenderer?
    private let screenFrame: CGRect
    
    public init(screenFrame: CGRect) {
        self.screenFrame = screenFrame
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadView() {
        // Create MTKView as the main view
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        print("✅ Metal device created: \(device.name)")
        
        // Initialize MTKView with proper frame
        mtkView = MTKView(frame: screenFrame)
        mtkView.device = device
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.layer?.isOpaque = false
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 60
        
        // Ensure the layer is transparent
        mtkView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Create renderer
        renderer = RainRenderer(device: device)
        if renderer == nil {
            print("❌ Failed to create RainRenderer")
        } else {
            print("✅ RainRenderer created successfully")
        }
        mtkView.delegate = renderer
        
        self.view = mtkView
        
        // Manually trigger initial size in renderer using points
        renderer?.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        
        print("✅ MTKView configured with size: \(mtkView.frame.size), drawable: \(mtkView.drawableSize)")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    public override func viewDidAppear() {
        super.viewDidAppear()
        // Force a draw
        mtkView.setNeedsDisplay(mtkView.bounds)
        print("👁️ viewDidAppear called, forced setNeedsDisplay")
    }
}

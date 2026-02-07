import AppKit
import MetalKit

/// View controller hosting the Metal-rendered rain overlay
public class RainViewController: NSViewController {
    
    private var mtkView: MTKView!
    private var renderer: RainRenderer?
    
    public override func loadView() {
        // Create MTKView as the main view
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        mtkView = MTKView()
        mtkView.device = device
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.layer?.isOpaque = false
        mtkView.preferredFramesPerSecond = 60
        
        // Create renderer
        renderer = RainRenderer(device: device)
        mtkView.delegate = renderer
        
        self.view = mtkView
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    public override func viewDidLayout() {
        super.viewDidLayout()
        // MTKView will call mtkView(_:drawableSizeDidChange:) automatically
    }
}

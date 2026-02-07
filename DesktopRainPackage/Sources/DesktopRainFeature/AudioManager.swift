import Foundation
import AVFoundation

/// Procedural audio manager for synthesizing rain sounds
public final class AudioManager: @unchecked Sendable {
    public static let shared = AudioManager()
    
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private let noiseSource = AVAudioSourceNode { _, _, frameCount, audioBufferList in
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        for frame in 0..<Int(frameCount) {
            let sample = (Float.random(in: -1...1))
            for buffer in ablPointer {
                let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                buf[frame] = sample
            }
        }
        return noErr
    }
    
    private let lowPassFilter = AVAudioUnitEQ(numberOfBands: 1)
    private let mainMixer: AVAudioMixerNode
    
    private var _isRunning = false
    private var isRunning: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _isRunning }
        set { lock.lock(); defer { lock.unlock() }; _isRunning = newValue }
    }
    
    private init() {
        mainMixer = engine.mainMixerNode
        setupEngine()
    }
    
    private func setupEngine() {
        let format = mainMixer.outputFormat(forBus: 0)
        engine.attach(noiseSource)
        engine.attach(lowPassFilter)
        
        let filterBand = lowPassFilter.bands[0]
        filterBand.filterType = .lowPass
        filterBand.frequency = 2000
        filterBand.bypass = false
        
        engine.connect(noiseSource, to: lowPassFilter, format: format)
        engine.connect(lowPassFilter, to: mainMixer, format: format)
        
        mainMixer.outputVolume = 0
    }
    
    public func start() {
        guard !isRunning else { return }
        do {
            try engine.start()
            isRunning = true
            updateFromSettings()
        } catch {
            print("❌ AudioManager failed to start: \(error)")
        }
    }
    
    public func stop() {
        engine.stop()
        isRunning = false
    }
    
    public func updateFromSettings() {
        guard isRunning else { return }
        
        let settings = RainSettings.shared
        let isEnabled = settings.isSoundEnabled
        
        // Target volume based on intensity (logarithmic-ish)
        let targetVolume = isEnabled ? min(1.0, settings.intensity * 0.2) : 0
        
        // Target frequency based on intensity (brighter for heavy rain)
        // Light rain: 1000Hz, Heavy: 4000Hz
        let targetFreq = 1000 + (settings.intensity * 800)
        
        // Smoothly update parameters
        mainMixer.outputVolume = targetVolume
        lowPassFilter.bands[0].frequency = min(8000, targetFreq)
        
        print("🔊 Audio Update: Vol \(targetVolume), Freq \(targetFreq)")
    }
}

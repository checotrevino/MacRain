import Foundation
import AVFoundation

/// Procedural audio manager for synthesizing rain sounds
public final class AudioManager: @unchecked Sendable {
    public static let shared = AudioManager()
    
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    
    // Pink Noise State (Voss-McCartney approximation)
    private var pinkRows = [Float](repeating: 0, count: 12)
    private var pinkIndex: Int = 0
    private var pinkSum: Float = 0
    
    // LFO State
    private var lfoTheta: Float = 0
    private var currentLFOValue: Float = 0
    
    private lazy var noiseSource = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
        guard let self = self else { return noErr }
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        
        for frame in 0..<Int(frameCount) {
            // Pink Noise Logic
            self.lock.lock()
            let white = Float.random(in: -1...1)
            var i = 0
            var mask = 1
            while (self.pinkIndex & mask) != 0 && i < self.pinkRows.count {
                mask <<= 1
                i += 1
            }
            if i < self.pinkRows.count {
                self.pinkSum -= self.pinkRows[i]
                let r = Float.random(in: -1...1) / Float(self.pinkRows.count)
                self.pinkRows[i] = r
                self.pinkSum += r
            }
            let sample = (white * 0.1 + self.pinkSum) * 2.0 // Boost and mix
            self.pinkIndex = (self.pinkIndex + 1) & 0x0FFF
            
            // LFO for modulation
            self.lfoTheta += 0.0001 // Slow modulation
            self.currentLFOValue = sin(self.lfoTheta)
            self.lock.unlock()
            
            for buffer in ablPointer {
                let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                buf[frame] = sample
            }
        }
        return noErr
    }
    
    private var thunderEnvelope: Float = 0
    private lazy var thunderSource = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
        guard let self = self else { return noErr }
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        
        for frame in 0..<Int(frameCount) {
            self.lock.lock()
            let env = self.thunderEnvelope
            if self.thunderEnvelope > 0 {
                self.thunderEnvelope -= 0.00002 // Slow decay
            }
            self.lock.unlock()
            
            let white = Float.random(in: -1...1)
            let sample = white * env * 0.5
            
            for buffer in ablPointer {
                let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                buf[frame] += sample // Mix with main noise
            }
        }
        return noErr
    }
    
    private let lowPassFilter = AVAudioUnitEQ(numberOfBands: 1)
    private let thunderFilter = AVAudioUnitEQ(numberOfBands: 1)
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
        engine.attach(thunderSource)
        engine.attach(thunderFilter)
        
        let filterBand = lowPassFilter.bands[0]
        filterBand.filterType = .lowPass
        filterBand.frequency = 2000
        filterBand.bypass = false
        
        let tBand = thunderFilter.bands[0]
        tBand.filterType = .lowPass
        tBand.frequency = 100 // Deep rumble
        tBand.bypass = false
        
        engine.connect(noiseSource, to: lowPassFilter, format: format)
        engine.connect(lowPassFilter, to: mainMixer, format: format)
        
        engine.connect(thunderSource, to: thunderFilter, format: format)
        engine.connect(thunderFilter, to: mainMixer, format: format)
        
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
    
    public func playThunder() {
        lock.lock()
        thunderEnvelope = 1.0
        lock.unlock()
        print("⛈️ Thunder Triggered")
    }
    
    public func updateFromSettings() {
        guard isRunning else { return }
        
        let settings = RainSettings.shared
        let isEnabled = settings.isSoundEnabled
        let profile = settings.soundProfile
        
        var baseVolume: Float = 0
        var baseFreq: Float = 2000
        
        switch profile {
        case .mist:
            baseVolume = 0.15
            baseFreq = 800
        case .drizzle:
            baseVolume = 0.3
            baseFreq = 1500
        case .downpour:
            baseVolume = 0.7
            baseFreq = 3500
        case .storm:
            baseVolume = 0.6
            baseFreq = 2500 // Windy texture will be added via LFO in future or just frequency
        case .zen:
            baseVolume = 0.1
            baseFreq = 600
        }
        
        // Intensity multiplier
        let intensityScale = min(1.5, settings.intensity)
        let targetVolume = isEnabled ? baseVolume * intensityScale : 0
        
        // Smoothly update parameters
        mainMixer.outputVolume = targetVolume
        lowPassFilter.bands[0].frequency = baseFreq
        
        print("🔊 Audio Profile: \(profile.rawValue), Vol \(targetVolume), Freq \(baseFreq)")
    }
}

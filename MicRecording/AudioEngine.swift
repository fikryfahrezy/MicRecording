import AVFAudio
import OSLog
import Combine

@MainActor
class AudioEngine: NSObject, ObservableObject {
    private let logger = Logger()
    
    @Published private(set) var state = AudioControllerState.stopped

    private let powerMeter = PowerMeter()
    @Published private(set) var audioLevels = AudioLevels.zero
    private var audioMeterCancellable: AnyCancellable?
    
    private var audioEngine: AVAudioEngine
    private let audioNodeBus: AVAudioNodeBus = 0
    
    override init() {
        self.audioEngine = AVAudioEngine()
    }
    
    private func startAudioMetering() {
        audioMeterCancellable = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self else { return }
            self.audioLevels = self.powerMeter.levels
        }
    }
    
    func startStreaming() {
        do {
            self.state = .playing
            self.audioEngine.inputNode.installTap(onBus: audioNodeBus, bufferSize: 8192, format: nil, block: { buffer, _ in
                self.powerMeter.process(buffer: buffer)
            })
            try self.audioEngine.start()
            self.startAudioMetering()
        } catch {
            logger.error("Error start streaming: \(error.localizedDescription)")
            self.state = .stopped
        }
    }
    
    func stopStreaming() {
        self.audioMeterCancellable?.cancel()
        self.audioEngine.inputNode.removeTap(onBus: audioNodeBus)
        self.audioEngine.stop()
        self.powerMeter.processSilence()
        self.state = .stopped
    }
}

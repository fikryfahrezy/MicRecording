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
    
    private var audioFile: AVAudioFile?
    private let audioEngine: AVAudioEngine
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
            self.state = .recording
            
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            let fileURL = tempDir.appendingPathComponent("recording-from-streaming.wav")
            
            let audioFormat =  self.audioEngine.inputNode.inputFormat(forBus: audioNodeBus)
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: audioFormat.settings)
            
            self.audioEngine.inputNode.installTap(onBus: audioNodeBus, bufferSize: 4096 , format: audioFormat, block: { [weak self] buffer, _ in
                guard let self = self else { return }
                self.powerMeter.process(buffer: buffer)
                do {
                    try audioFile.write(from: buffer)
                } catch {
                    self.logger.error("Error write buffer to file: \(error.localizedDescription)")
                }
            })
            
            try self.audioEngine.start()
            
            self.audioFile = audioFile
            self.startAudioMetering()
        } catch {
            logger.error("Error start streaming: \(error.localizedDescription)")
            self.state = .stopped
        }
    }
    
    func stopStreaming() {
        self.audioFile?.close()
        self.audioMeterCancellable?.cancel()
        self.audioEngine.inputNode.removeTap(onBus: audioNodeBus)
        self.audioEngine.stop()
        self.powerMeter.processSilence()
        self.state = .stopped
    }
}

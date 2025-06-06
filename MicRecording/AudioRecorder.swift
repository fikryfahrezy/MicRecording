import Foundation
import AVFoundation
import SwiftUI
import CoreGraphics
import Combine

enum AudioControllerState {
    case stopped
    case recording
}

@MainActor
class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    
    @Published private(set) var state = AudioControllerState.stopped
    @Published private(set) var audioLevels = AudioLevels.zero
    
    private var recorder: AVAudioRecorder!
    private var audioMeterCancellable: AnyCancellable?
    
    private var meterTableAverage = MeterTable()
    private var meterTablePeak = MeterTable()
    
    override init() {
        super.init()
        setupRecorder()
    }
    
    // MARK: - Audio Recording and Playback
    func setupRecorder() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = tempDir.appendingPathComponent("recording.wav")
        
        do {
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVLinearPCMIsNonInterleaved: false,
                AVSampleRateKey: 44_100.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16
            ]
            debugPrint(fileURL)
            self.recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        } catch {
            fatalError("Unable to create audio recorder: \(error.localizedDescription)")
        }
        
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
    }
    
    func record() {
        audioMeterCancellable = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self else { return }
            self.recorder.updateMeters()
            
            let channel = 0
            let averagePower = self.recorder.averagePower(forChannel: channel)
            let peakPower = self.recorder.peakPower(forChannel: channel)
            
            self.audioLevels = AudioLevels(level: meterTableAverage.valueForPower(averagePower),
                                           peakLevel: meterTablePeak.valueForPower(peakPower))
        }
        recorder.record()
        state = .recording
    }
    
    func stopRecording() {
        audioMeterCancellable?.cancel()
        recorder.stop()
        state = .stopped
    }
}

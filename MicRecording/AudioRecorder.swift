import Foundation
import AVFoundation
import SwiftUI
import CoreGraphics
import Combine

struct AudioLevels {
    static let zero = AudioLevels(average: 0, peak: 0)
    let average: Float
    let peak: Float
}

enum AudioControllerState {
    case stopped
    case playing
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
            
            self.audioLevels = AudioLevels(average: meterTableAverage.valueForPower(averagePower),
                                           peak: meterTablePeak.valueForPower(peakPower))
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

private struct MeterTable {
    
    // The decibel value of the minimum displayed amplitude.
    private let kMinDB: Float = -60.0
    
    // The table needs to be large enough so that there are no large gaps in the response.
    private let tableSize = 300
    
    private let scaleFactor: Float
    private var meterTable = [Float]()
    
    init() {
        let dbResolution = kMinDB / Float(tableSize - 1)
        scaleFactor = 1.0 / dbResolution
        
        // This controls the curvature of the response.
        // 2.0 is the square root, 3.0 is the cube root.
        let root: Float = 2.0
        
        let rroot = 1.0 / root
        let minAmp = dbToAmp(dBValue: kMinDB)
        let ampRange = 1.0 - minAmp
        let invAmpRange = 1.0 / ampRange
        
        for index in 0..<tableSize {
            let decibels = Float(index) * dbResolution
            let amp = dbToAmp(dBValue: decibels)
            let adjAmp = (amp - minAmp) * invAmpRange
            meterTable.append(powf(adjAmp, rroot))
        }
    }
    
    private func dbToAmp(dBValue: Float) -> Float {
        return powf(10.0, 0.05 * dBValue)
    }
    
    func valueForPower(_ power: Float) -> Float {
        if power < kMinDB {
            return 0.0
        } else if power >= 0.0 {
            return 1.0
        } else {
            let index = Int(power) * Int(scaleFactor)
            return meterTable[index]
        }
    }
}

import Foundation
import AVFoundation
import SwiftUI
import OSLog

@MainActor
class AudioCapture: NSObject, ObservableObject {
    private let logger = Logger()
    
    @Published private(set) var state = AudioControllerState.stopped
    @Published private(set) var audioLevels = AudioLevels.zero
    
    private let captureSession = AVCaptureSession()
    private var fileOutput: AVCaptureAudioFileOutput?
    
    private var assetWriter: SampleBufferWriter?
    private var audioOutput = AVCaptureAudioDataOutput()
    
    private var meterTableAverage = MeterTable()
    private var meterTablePeak = MeterTable()
    
    func setupCapture(audioDevice: AVCaptureDevice) async throws -> Void {
        self.captureSession.inputs.forEach { captureSession.removeInput($0) }
        
        // Wrap the audio device in a capture device input.
        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
        // If the input can be added, add it to the session.
        if self.captureSession.canAddInput(audioInput) {
            self.captureSession.addInput(audioInput)
        }
    }
    
    func startStream(audioDevice: AVCaptureDevice) async {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = tempDir.appendingPathComponent("recording-from-streaming-capture.wav")
        
        self.state = .recording
        do {
            try await self.setupCapture(audioDevice: audioDevice)
            self.captureSession.startRunning()
            
            // Create audio output
            let audioQueue = DispatchQueue(label: "com.fikryfahrezy.MicRecording.AudioStreamingQueue")
            audioOutput.setSampleBufferDelegate(self, queue: audioQueue)
            
            if captureSession.canAddOutput(audioOutput) {
                captureSession.addOutput(audioOutput)
            }
            
            self.assetWriter = SampleBufferWriter(url: fileURL)
        } catch {
            // Configuration failed. Handle error.
            self.logger.error("Failed to start capture: \(error.localizedDescription)")
            self.state = .stopped
        }
    }
    
    func stopStreaming() {
        self.assetWriter?.finishWriting { error in
            if let error = error {
                self.logger.error("Failed to finish streaming: \(error.localizedDescription)")
            } else {
                self.logger.info("Finish to finish streaming")
            }
        }
        self.captureSession.stopRunning()
        self.state = .stopped
    }
    
    func startRecording(audioDevice: AVCaptureDevice) async {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = tempDir.appendingPathComponent("recording-from-capture.wav")
        
        self.state = .recording
        do {
            try await self.setupCapture(audioDevice: audioDevice)
            
            let fileOutput = AVCaptureAudioFileOutput()
            if self.captureSession.canAddOutput(fileOutput) {
                self.captureSession.addOutput(fileOutput)
            }
            
            // Create audio output
            let audioQueue = DispatchQueue(label: "com.fikryfahrezy.MicRecording.AudioRecordingQueue")
            audioOutput.setSampleBufferDelegate(self, queue: audioQueue)
            
            if captureSession.canAddOutput(audioOutput) {
                captureSession.addOutput(audioOutput)
            }
            
            self.captureSession.startRunning()
            debugPrint(fileURL)
            fileOutput.startRecording(to: fileURL, outputFileType: .wav, recordingDelegate: self)
            self.fileOutput = fileOutput
        } catch {
            // Configuration failed. Handle error.
            self.logger.error("Failed to start capture: \(error.localizedDescription)")
            self.state = .stopped
        }
    }
    
    func stopRecording() {
        self.fileOutput?.stopRecording()
        self.captureSession.stopRunning()
        self.state = .stopped
    }
}

extension AudioCapture: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Error)?) {
        debugPrint("Finish Output")
    }
}

extension AudioCapture: AVCaptureAudioDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput: CMSampleBuffer, from: AVCaptureConnection) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(didOutput) else { return }
        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        
        guard let streamDescription = audioStreamBasicDescription?.pointee else { return }
        
        // Get audio buffer
        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
        
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            didOutput,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        
        // Calculate RMS level
        let audioBuffer = audioBufferList.mBuffers
        let samples = audioBuffer.mData?.assumingMemoryBound(to: Float32.self)
        let sampleCount = Int(audioBuffer.mDataByteSize) / MemoryLayout<Float32>.size
        
        guard let sampleData = samples else { return }
        
        var sum: Float = 0.0
        for i in 0..<sampleCount {
            let sample = sampleData[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(sampleCount))
        let db = 20 * log10(rms)
        
        // Convert dB to 0-1 range (assuming -60dB to 0dB range)
        let normalizedLevel = max(0.0, min(1.0, (db + 60.0) / 60.0))
        
        let averagePower = didOutput.toDBFS()
        let peakPower = didOutput.toPeakDBFS()
        
        // Update level meter on main queue
        DispatchQueue.main.async {
            self.audioLevels = AudioLevels(level: self.meterTableAverage.valueForPower(averagePower ?? .zero),
                                           peakLevel: self.meterTablePeak.valueForPower(peakPower ?? .zero))
        }
        
        Task { @MainActor in
            do {
                try self.assetWriter?.writeSampleBuffer(didOutput)
            } catch {
                self.logger.error("Error write buffer to file: \(error.localizedDescription)")
            }
        }
    }
}

import AVFoundation

class SampleBufferWriter {
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    
    private let url : URL
    private var isWriting = false
    
    init(url: URL) {
        self.url = url
    }
    
    func setupWriter(sampleBuffer: CMSampleBuffer) throws {
        // Remove existing file
        try? FileManager.default.removeItem(at: self.url)
        
        // Create asset writer
        assetWriter = try AVAssetWriter(outputURL: self.url, fileType: .wav)
        
        // Get format description
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            throw NSError(domain: "WriterError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No format description"])
        }
        
        // Create asset writer input
        assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: formatDescription)
        assetWriterInput?.expectsMediaDataInRealTime = false
        
        // Add input to writer
        guard let input = assetWriterInput, assetWriter?.canAdd(input) == true else {
            throw NSError(domain: "WriterError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot add input"])
        }
        
        assetWriter?.add(input)
        
        // Start writing
        guard assetWriter?.startWriting() == true else {
            throw NSError(domain: "WriterError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot start writing"])
        }
        
        assetWriter?.startSession(atSourceTime: CMTime.zero)
    }
    
    func writeSampleBuffer(_ sampleBuffer: CMSampleBuffer) throws {
        if !self.isWriting  {
            try self.setupWriter(sampleBuffer: sampleBuffer)
            self.isWriting = true
            return
        }
        
        guard let input = assetWriterInput, input.isReadyForMoreMediaData else {
            return
        }

        input.append(sampleBuffer)
    }
    
    func finishWriting(completion: @escaping (Error?) -> Void) {
        assetWriterInput?.markAsFinished()
        assetWriter?.finishWriting { [weak self] in
            completion(self?.assetWriter?.error)
        }
    }
}

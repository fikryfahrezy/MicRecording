import AVFoundation
import Accelerate

extension CMSampleBuffer {
    
    /// Converts CMSampleBuffer to dBFS using RMS calculation
    /// - Returns: dBFS value, or nil if conversion fails
    func toDBFS() -> Float? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(self) else {
            return nil
        }
        
        // Get audio format description
        guard let formatDescription = CMSampleBufferGetFormatDescription(self) else {
            return nil
        }
        
        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        guard let asbd = audioStreamBasicDescription else {
            return nil
        }
        
        // Get audio data
        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
        
        guard status == noErr, let data = dataPointer else {
            return nil
        }
        
        // Calculate number of samples
        let bytesPerSample = Int(asbd.pointee.mBitsPerChannel / 8)
        let channelCount = Int(asbd.pointee.mChannelsPerFrame)
        let sampleCount = length / (bytesPerSample * channelCount)
        
        // Convert based on bit depth
        switch asbd.pointee.mBitsPerChannel {
        case 16:
            return calculateDBFS16Bit(data: data, sampleCount: sampleCount, channelCount: channelCount)
        case 32:
            if asbd.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
                return calculateDBFS32BitFloat(data: data, sampleCount: sampleCount, channelCount: channelCount)
            } else {
                return calculateDBFS32BitInt(data: data, sampleCount: sampleCount, channelCount: channelCount)
            }
        default:
            return nil
        }
    }
    
    /// Calculate dBFS for 16-bit integer samples
    private func calculateDBFS16Bit(data: UnsafeMutablePointer<Int8>, sampleCount: Int, channelCount: Int) -> Float {
        let samples = data.withMemoryRebound(to: Int16.self, capacity: sampleCount * channelCount) { pointer in
            return pointer
        }
        
        var sum: Float = 0.0
        let totalSamples = sampleCount * channelCount
        
        for i in 0..<totalSamples {
            let sample = Float(samples[i]) / Float(Int16.max)
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(totalSamples))
        return rms > 0 ? 20.0 * log10(rms) : -Float.infinity
    }
    
    /// Calculate dBFS for 32-bit float samples
    private func calculateDBFS32BitFloat(data: UnsafeMutablePointer<Int8>, sampleCount: Int, channelCount: Int) -> Float {
        let samples = data.withMemoryRebound(to: Float32.self, capacity: sampleCount * channelCount) { pointer in
            return pointer
        }
        
        var sum: Float = 0.0
        let totalSamples = sampleCount * channelCount
        
        for i in 0..<totalSamples {
            let sample = samples[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(totalSamples))
        return rms > 0 ? 20.0 * log10(rms) : -Float.infinity
    }
    
    /// Calculate dBFS for 32-bit integer samples
    private func calculateDBFS32BitInt(data: UnsafeMutablePointer<Int8>, sampleCount: Int, channelCount: Int) -> Float {
        let samples = data.withMemoryRebound(to: Int32.self, capacity: sampleCount * channelCount) { pointer in
            return pointer
        }
        
        var sum: Float = 0.0
        let totalSamples = sampleCount * channelCount
        
        for i in 0..<totalSamples {
            let sample = Float(samples[i]) / Float(Int32.max)
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(totalSamples))
        return rms > 0 ? 20.0 * log10(rms) : -Float.infinity
    }
}

// MARK: - Peak dBFS Alternative

extension CMSampleBuffer {
    
    /// Converts CMSampleBuffer to peak dBFS (maximum amplitude)
    /// - Returns: Peak dBFS value, or nil if conversion fails
    func toPeakDBFS() -> Float? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(self) else {
            return nil
        }
        
        guard let formatDescription = CMSampleBufferGetFormatDescription(self) else {
            return nil
        }
        
        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        guard let asbd = audioStreamBasicDescription else {
            return nil
        }
        
        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
        
        guard status == noErr, let data = dataPointer else {
            return nil
        }
        
        let bytesPerSample = Int(asbd.pointee.mBitsPerChannel / 8)
        let channelCount = Int(asbd.pointee.mChannelsPerFrame)
        let sampleCount = length / (bytesPerSample * channelCount)
        
        switch asbd.pointee.mBitsPerChannel {
        case 16:
            return calculatePeakDBFS16Bit(data: data, sampleCount: sampleCount, channelCount: channelCount)
        case 32:
            if asbd.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
                return calculatePeakDBFS32BitFloat(data: data, sampleCount: sampleCount, channelCount: channelCount)
            } else {
                return calculatePeakDBFS32BitInt(data: data, sampleCount: sampleCount, channelCount: channelCount)
            }
        default:
            return nil
        }
    }
    
    private func calculatePeakDBFS16Bit(data: UnsafeMutablePointer<Int8>, sampleCount: Int, channelCount: Int) -> Float {
        let samples = data.withMemoryRebound(to: Int16.self, capacity: sampleCount * channelCount) { pointer in
            return pointer
        }
        
        var maxAmplitude: Float = 0.0
        let totalSamples = sampleCount * channelCount
        
        for i in 0..<totalSamples {
            let sample = abs(Float(samples[i]) / Float(Int16.max))
            maxAmplitude = max(maxAmplitude, sample)
        }
        
        return maxAmplitude > 0 ? 20.0 * log10(maxAmplitude) : -Float.infinity
    }
    
    private func calculatePeakDBFS32BitFloat(data: UnsafeMutablePointer<Int8>, sampleCount: Int, channelCount: Int) -> Float {
        let samples = data.withMemoryRebound(to: Float32.self, capacity: sampleCount * channelCount) { pointer in
            return pointer
        }
        
        var maxAmplitude: Float = 0.0
        let totalSamples = sampleCount * channelCount
        
        for i in 0..<totalSamples {
            let sample = abs(samples[i])
            maxAmplitude = max(maxAmplitude, sample)
        }
        
        return maxAmplitude > 0 ? 20.0 * log10(maxAmplitude) : -Float.infinity
    }
    
    private func calculatePeakDBFS32BitInt(data: UnsafeMutablePointer<Int8>, sampleCount: Int, channelCount: Int) -> Float {
        let samples = data.withMemoryRebound(to: Int32.self, capacity: sampleCount * channelCount) { pointer in
            return pointer
        }
        
        var maxAmplitude: Float = 0.0
        let totalSamples = sampleCount * channelCount
        
        for i in 0..<totalSamples {
            let sample = abs(Float(samples[i]) / Float(Int32.max))
            maxAmplitude = max(maxAmplitude, sample)
        }
        
        return maxAmplitude > 0 ? 20.0 * log10(maxAmplitude) : -Float.infinity
    }
}


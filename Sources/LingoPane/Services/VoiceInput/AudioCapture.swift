@preconcurrency import AVFoundation
import Foundation

/// Thread-safe container for captured microphone audio.
///
/// Samples are ingested on the audio render thread while the menu bar
/// waveform reads levels and `drainSamples()` runs on the main actor,
/// so every access is guarded by a lock.
final class AudioCaptureBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var monoSamples: [Float] = []
    private var latestRawLevel: Float = 0
    private var lastSmoothedLevel: Float = 0

    /// Sample rate of the input node, recorded when a capture session starts.
    private(set) var sampleRate: Double = 0

    /// Normalization ceiling: speech RMS above this maps to a full-height bar.
    private static let levelCeiling: Float = 0.20
    /// Safety cap (~35 s at 48 kHz) in case the release event never arrives.
    private static let maximumSampleCount = 48_000 * 35

    func reset(sampleRate: Double) {
        lock.lock()
        defer { lock.unlock() }
        monoSamples = []
        latestRawLevel = 0
        lastSmoothedLevel = 0
        self.sampleRate = sampleRate
    }

    func ingest(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }
        let channelCount = Int(buffer.format.channelCount)
        guard channelCount > 0 else { return }

        var mono = [Float](repeating: 0, count: frameCount)
        var energy = 0.0
        for frame in 0..<frameCount {
            var sum: Float = 0
            for channel in 0..<channelCount { sum += channelData[channel][frame] }
            let value = sum / Float(channelCount)
            mono[frame] = value
            energy += Double(value * value)
        }
        let rms = Float(sqrt(energy / Double(frameCount)))
        let normalized = min(rms / Self.levelCeiling, 1)
        // Smooth toward the raw level so short gaps between buffers do not
        // make the waveform collapse to zero between updates.
        let smoothed = Swift.max(normalized, lastSmoothedLevel * 0.78)

        lock.lock()
        defer { lock.unlock() }
        latestRawLevel = smoothed
        lastSmoothedLevel = smoothed
        if monoSamples.count < Self.maximumSampleCount {
            monoSamples.append(contentsOf: mono)
        }
    }

    /// Latest normalized level (0...1) for the menu bar waveform.
    var latestLevel: Float {
        lock.lock()
        defer { lock.unlock() }
        return latestRawLevel
    }

    /// Returns and clears the captured mono samples plus their sample rate.
    func drainSamples() -> (samples: [Float], sampleRate: Double) {
        lock.lock()
        defer { lock.unlock() }
        let drained = (monoSamples, sampleRate)
        monoSamples = []
        return drained
    }
}

/// Converts captured float samples into a 16 kHz mono 16-bit WAV payload —
/// the format Ollama's audio path accepts (RIFF header, 16 kHz, mono).
enum WAVEncoder {
    static let targetSampleRate: Double = 16_000

    static func encode(samples: [Float], sampleRate: Double) -> Data {
        wavData(pcm: resample(samples, from: sampleRate))
    }

    /// Box-average resampling: each output frame averages the source frames
    /// that fall into its slot, which also acts as a simple anti-aliasing
    /// low-pass when downsampling speech.
    static func resample(_ samples: [Float], from sourceRate: Double, to targetRate: Double = targetSampleRate) -> [Int16] {
        guard !samples.isEmpty, sourceRate > 0, targetRate > 0 else { return [] }
        if sourceRate == targetRate { return samples.map(int16) }

        let ratio = sourceRate / targetRate
        let outputCount = Int(Double(samples.count) / ratio)
        var output = [Int16]()
        output.reserveCapacity(outputCount)
        for index in 0..<outputCount {
            let start = Int(Double(index) * ratio)
            guard start < samples.count else { break }
            let end = Swift.min(Swift.max(Int(Double(index + 1) * ratio), start + 1), samples.count)
            let mean = samples[start..<end].reduce(Float(0), +) / Float(end - start)
            output.append(int16(mean))
        }
        return output
    }

    static func wavData(pcm: [Int16]) -> Data {
        var payload = Data(count: pcm.count * 2)
        payload.withUnsafeMutableBytes { raw in
            let destination = raw.bindMemory(to: Int16.self)
            for (index, sample) in pcm.enumerated() { destination[index] = sample }
        }

        var header = [UInt8]()
        header.reserveCapacity(44)
        header.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + payload.count), to: &header)
        header.append(contentsOf: Array("WAVE".utf8))
        header.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16), to: &header)            // PCM header size
        append(UInt16(1), to: &header)             // PCM format
        append(UInt16(1), to: &header)             // mono
        append(UInt32(targetSampleRate), to: &header)
        append(UInt32(targetSampleRate * 2), to: &header) // byte rate
        append(UInt16(2), to: &header)             // block align
        append(UInt16(16), to: &header)            // bits per sample
        header.append(contentsOf: Array("data".utf8))
        append(UInt32(payload.count), to: &header)

        var data = Data(header)
        data.append(payload)
        return data
    }

    private static func int16(_ sample: Float) -> Int16 {
        let clamped = Swift.max(-1, Swift.min(1, sample))
        return Int16(clamped * 32767)
    }

    private static func append(_ value: UInt16, to header: inout [UInt8]) {
        header.append(UInt8(truncatingIfNeeded: value))
        header.append(UInt8(truncatingIfNeeded: value >> 8))
    }

    private static func append(_ value: UInt32, to header: inout [UInt8]) {
        header.append(UInt8(truncatingIfNeeded: value))
        header.append(UInt8(truncatingIfNeeded: value >> 8))
        header.append(UInt8(truncatingIfNeeded: value >> 16))
        header.append(UInt8(truncatingIfNeeded: value >> 24))
    }
}

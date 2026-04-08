import Foundation
import AVFoundation

/// Audio recording format.
public enum AudioRecordingFormat: Sendable {
    case aac
    case wav
}

/// Protocol for audio recording.
public protocol AudioRecorderProtocol: Sendable {
    func start(format: AudioRecordingFormat) throws -> AsyncStream<Data>
    func stop()
    var isRecording: Bool { get }
}

/// AVAudioEngine-based audio recorder.
/// Records audio and streams chunks as Data.
public final class AudioRecorder: AudioRecorderProtocol, @unchecked Sendable {
    private var audioEngine: AVAudioEngine?
    private var continuation: AsyncStream<Data>.Continuation?
    private var _isRecording = false

    public var isRecording: Bool { _isRecording }

    public init() {}

    public func start(format: AudioRecordingFormat) throws -> AsyncStream<Data> {
        let engine = AVAudioEngine()
        self.audioEngine = engine

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        let stream = AsyncStream<Data> { continuation in
            self.continuation = continuation

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { buffer, _ in
                guard let channelData = buffer.floatChannelData else { return }
                let frameCount = Int(buffer.frameLength)
                let data = Data(bytes: channelData[0], count: frameCount * MemoryLayout<Float>.size)
                continuation.yield(data)
            }
        }

        try engine.start()
        _isRecording = true
        return stream
    }

    public func stop() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        continuation?.finish()
        continuation = nil
        _isRecording = false
    }
}

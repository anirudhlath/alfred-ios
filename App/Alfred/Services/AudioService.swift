import Foundation
import AVFoundation
import AlfredKit

@MainActor
final class AudioService {
    let recorder: AudioRecorder
    let player: AudioPlayer

    init() {
        self.recorder = AudioRecorder()
        self.player = AudioPlayer()
    }

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
    }
}

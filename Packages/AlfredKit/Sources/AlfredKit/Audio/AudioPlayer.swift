import Foundation
import AVFoundation

/// Protocol for audio playback.
public protocol AudioPlayerProtocol: Sendable {
    func play(_ data: Data) async
    func stop()
    var isPlaying: Bool { get }
}

/// AVAudioPlayer-based audio player with queue support.
public final class AudioPlayer: NSObject, AudioPlayerProtocol, @unchecked Sendable {
    private var player: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?
    private var _isPlaying = false

    public var isPlaying: Bool { _isPlaying }

    public override init() {
        super.init()
    }

    public func play(_ data: Data) async {
        stop()
        do {
            let audioPlayer = try AVAudioPlayer(data: data)
            self.player = audioPlayer
            audioPlayer.delegate = self
            _isPlaying = true

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                self.playbackContinuation = continuation
                audioPlayer.play()
            }
        } catch {
            _isPlaying = false
        }
    }

    public func stop() {
        player?.stop()
        player = nil
        _isPlaying = false
        playbackContinuation?.resume()
        playbackContinuation = nil
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        _isPlaying = false
        playbackContinuation?.resume()
        playbackContinuation = nil
    }
}

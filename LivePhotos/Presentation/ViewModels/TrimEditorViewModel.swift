import AVFoundation
import Combine
import SwiftUI

@MainActor
final class TrimEditorViewModel: ObservableObject {
    let asset: LocalVideoAsset
    let player: AVPlayer

    @Published var trimStart: Double = 0
    @Published var trimEnd: Double = 3.0
    @Published var currentTime: Double = 0
    @Published var isPlaying: Bool = false

    private var timeObserver: Any?

    var trimRange: TrimRange { TrimRange(start: trimStart, end: trimEnd) }
    var trimDuration: Double { trimEnd - trimStart }
    var isValidTrim: Bool {
        trimDuration >= 1.0 && trimDuration <= 5.0 && trimStart >= 0 && trimEnd <= asset.duration
    }

    init(asset: LocalVideoAsset) {
        self.asset = asset
        self.player = AVPlayer(url: asset.sourceURL)
        self.trimEnd = min(3.0, asset.duration)
        setupTimeObserver()
    }

    deinit {
        player.pause()
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }

            let seconds = CMTimeGetSeconds(time)
            self.currentTime = seconds

            guard self.isPlaying, seconds >= self.trimEnd else { return }
            self.pause()
            self.currentTime = self.trimEnd
            self.player.seek(to: CMTime(seconds: self.trimEnd, preferredTimescale: 600))
        }
    }

    func play() {
        player.seek(to: CMTime(seconds: trimStart, preferredTimescale: 600))
        currentTime = trimStart
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func seek(to time: Double) {
        let clampedTime = max(trimStart, min(time, trimEnd))
        currentTime = clampedTime
        player.seek(to: CMTime(seconds: clampedTime, preferredTimescale: 600))
    }

    /// Seek to any position in the full video (not limited to trim range)
    func seekGlobal(to time: Double) {
        let clamped = max(0, min(time, asset.duration))
        currentTime = clamped
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
    }

    /// Set trim start at the current playback position, with trimEnd = start + defaultDuration
    func setTrimStartAtCurrentTime(defaultDuration: Double = 3.0) {
        let newStart = max(0, currentTime)
        let newEnd = min(newStart + defaultDuration, asset.duration)
        // Ensure at least 1 second
        guard newEnd - newStart >= 1.0 else { return }
        trimStart = newStart
        trimEnd = newEnd
    }
}

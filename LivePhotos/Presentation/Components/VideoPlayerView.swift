import AVKit
import SwiftUI

struct VideoPlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.player = AVPlayer(url: url)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        let currentURL = (controller.player?.currentItem?.asset as? AVURLAsset)?.url

        guard currentURL != url else {
            return
        }

        let playerItem = AVPlayerItem(url: url)

        if let player = controller.player {
            player.replaceCurrentItem(with: playerItem)
        } else {
            controller.player = AVPlayer(playerItem: playerItem)
        }
    }
}

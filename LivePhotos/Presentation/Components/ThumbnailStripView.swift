import AVFoundation
import SwiftUI
import UIKit

struct ThumbnailStripView: View {
    let videoURL: URL
    let thumbnailCount: Int

    @State private var thumbnails: [UIImage] = []

    init(videoURL: URL, thumbnailCount: Int = 12) {
        self.videoURL = videoURL
        self.thumbnailCount = thumbnailCount
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if thumbnails.isEmpty {
                    ForEach(0..<thumbnailCount, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: geometry.size.width / CGFloat(thumbnailCount))
                    }
                } else {
                    ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width / CGFloat(thumbnails.count),
                                   height: geometry.size.height)
                            .clipped()
                    }
                }
            }
        }
        .task {
            await generateThumbnails()
        }
    }

    private func generateThumbnails() async {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 120, height: 120)

        guard let duration = try? await asset.load(.duration) else { return }
        let totalSeconds = CMTimeGetSeconds(duration)
        guard totalSeconds > 0 else { return }

        var images: [UIImage] = []
        for i in 0..<thumbnailCount {
            let time = CMTime(seconds: totalSeconds * Double(i) / Double(thumbnailCount),
                              preferredTimescale: 600)
            do {
                let (cgImage, _) = try await generator.image(at: time)
                images.append(UIImage(cgImage: cgImage))
            } catch {
                images.append(UIImage())
            }
        }

        await MainActor.run {
            thumbnails = images
        }
    }
}

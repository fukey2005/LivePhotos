import AVFoundation
import SwiftUI
import UIKit

/// A full-video seek bar with thumbnails. Shows current position and trim range overlay.
/// Tap or drag to seek to any position in the video.
struct VideoSeekBarView: View {
    let videoURL: URL
    let duration: Double
    let currentTime: Double
    let trimStart: Double
    let trimEnd: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .leading) {
                // Thumbnail strip (full video)
                ThumbnailStripView(videoURL: videoURL, thumbnailCount: 16)

                // Dim everything outside the trim range
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: xPosition(for: trimStart, in: width))

                    Spacer()

                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: width - xPosition(for: trimEnd, in: width))
                }

                // Trim range highlight border
                let startX = xPosition(for: trimStart, in: width)
                let endX = xPosition(for: trimEnd, in: width)
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 2)
                    .frame(width: endX - startX)
                    .offset(x: startX)

                // Current position indicator
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 3, height: geometry.size.height)
                    .shadow(color: .black.opacity(0.5), radius: 1)
                    .offset(x: xPosition(for: currentTime, in: width) - 1.5)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let time = timeFromX(value.location.x, in: width)
                        onSeek(time)
                    }
            )
        }
    }

    private func xPosition(for time: Double, in width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(time / duration) * width
    }

    private func timeFromX(_ x: CGFloat, in width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        let ratio = max(0, min(1, Double(x / width)))
        return ratio * duration
    }
}

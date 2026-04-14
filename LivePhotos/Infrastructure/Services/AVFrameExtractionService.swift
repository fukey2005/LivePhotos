import AVFoundation
import UIKit

struct AVFrameExtractionService: FrameExtracting {
    func thumbnails(from videoURL: URL, range: TrimRange, count: Int) async throws -> [FrameCandidate] {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 200, height: 200)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

        var candidates: [FrameCandidate] = []
        let step = range.duration / Double(count)

        for i in 0..<count {
            let time = range.start + step * (Double(i) + 0.5)
            let cmTime = CMTime(seconds: time, preferredTimescale: 600)
            do {
                let (cgImage, _) = try await generator.image(at: cmTime)
                let candidate = FrameCandidate(
                    id: UUID(),
                    time: time,
                    image: UIImage(cgImage: cgImage)
                )
                candidates.append(candidate)
            } catch {
                // Skip failed frames
                continue
            }
        }

        guard !candidates.isEmpty else {
            throw AppError.frameExtractionFailed
        }

        return candidates
    }

    func highQualityFrame(from videoURL: URL, at time: Double) async throws -> UIImage {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: cmTime)
            return UIImage(cgImage: cgImage)
        } catch {
            throw AppError.frameExtractionFailed
        }
    }
}

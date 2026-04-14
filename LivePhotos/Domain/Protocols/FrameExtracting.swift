import UIKit

protocol FrameExtracting: Sendable {
    func thumbnails(from videoURL: URL, range: TrimRange, count: Int) async throws -> [FrameCandidate]
    func highQualityFrame(from videoURL: URL, at time: Double) async throws -> UIImage
}

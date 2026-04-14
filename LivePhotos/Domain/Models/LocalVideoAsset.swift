import CoreGraphics
import Foundation

struct LocalVideoAsset: Sendable {
    let sourceURL: URL
    let duration: Double
    let naturalSize: CGSize
}

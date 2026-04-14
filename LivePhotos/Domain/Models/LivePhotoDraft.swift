import Foundation

struct LivePhotoDraft: Sendable {
    let assetIdentifier: String
    let photoURL: URL
    let pairedVideoURL: URL
    let stillFrameTime: Double
}

import UIKit

protocol LivePhotoBuilding: Sendable {
    func build(stillImage: UIImage, clipURL: URL, stillTime: Double) async throws -> LivePhotoDraft
}

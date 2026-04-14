import PhotosUI
import SwiftUI

protocol VideoImporting: Sendable {
    func importVideo(_ item: PhotosPickerItem) async throws -> LocalVideoAsset
}

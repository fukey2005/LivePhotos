import Photos
import UIKit

struct PhotoLibrarySaveService: PhotoLibrarySaving {
    func save(draft: LivePhotoDraft) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw AppError.photoLibraryPermissionDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false

            request.addResource(with: .photo, fileURL: draft.photoURL, options: options)
            request.addResource(with: .pairedVideo, fileURL: draft.pairedVideoURL, options: options)
        }
    }
}

import os.log
import Photos
import UIKit

private let log = Logger(subsystem: "com.livephotos", category: "PreviewLoader")

struct PhotoKitLivePhotoPreviewService: LivePhotoPreviewLoading {
    func load(from draft: LivePhotoDraft) async throws -> PHLivePhoto {
        let resources = [draft.photoURL, draft.pairedVideoURL]
        let placeholderImage = UIImage(contentsOfFile: draft.photoURL.path) ?? UIImage()

        return try await withThrowingTaskGroup(of: PHLivePhoto.self) { group in
            group.addTask {
                try await requestLivePhoto(resources: resources, placeholderImage: placeholderImage)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(30))
                throw AppError.livePhotoPreviewFailed
            }

            guard let result = try await group.next() else {
                throw AppError.livePhotoPreviewFailed
            }
            group.cancelAll()
            return result
        }
    }

    private func requestLivePhoto(resources: [URL], placeholderImage: UIImage) async throws -> PHLivePhoto {
        log.info("  requestLivePhoto START — resources: \(resources.map(\.lastPathComponent))")
        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false

            PHLivePhoto.request(
                withResourceFileURLs: resources,
                placeholderImage: placeholderImage,
                targetSize: .zero,
                contentMode: .aspectFit
            ) { livePhoto, info in
                let isDegraded = (info[PHLivePhotoInfoIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info[PHLivePhotoInfoCancelledKey] as? Bool) ?? false
                let error = info[PHLivePhotoInfoErrorKey] as? Error
                let hasError = error != nil

                log.info("  callback — degraded=\(isDegraded), cancelled=\(isCancelled), hasError=\(hasError), livePhoto=\(livePhoto != nil), didResume=\(didResume)")
                if let error {
                    log.error("  error: \(error.localizedDescription)")
                }

                guard !didResume else { return }

                // Final failure — cancelled or error on non-degraded callback
                if !isDegraded && (isCancelled || hasError) && livePhoto == nil {
                    log.error("  ✖ final failure")
                    didResume = true
                    continuation.resume(throwing: AppError.livePhotoPreviewFailed)
                    return
                }

                // Skip intermediate degraded results
                guard !isDegraded else {
                    log.debug("  skipping degraded result")
                    return
                }

                didResume = true
                if let livePhoto {
                    log.info("  ✓ got live photo")
                    continuation.resume(returning: livePhoto)
                } else {
                    log.error("  ✖ non-degraded but nil livePhoto")
                    continuation.resume(throwing: AppError.livePhotoPreviewFailed)
                }
            }
        }
    }
}

import Combine
import os.log
import Photos
import SwiftUI
import UIKit

private let log = Logger(subsystem: "com.livephotos", category: "PreviewVM")

@MainActor
final class LivePhotoPreviewViewModel: ObservableObject {
    let asset: LocalVideoAsset
    let trimRange: TrimRange
    let selectedFrameTime: Double
    let selectedImage: UIImage

    @Published var buildState: ScreenState<LivePhotoDraft> = .idle
    @Published var livePhoto: PHLivePhoto?
    @Published var saveState: ScreenState<Void> = .idle
    @Published var buildProgress: Double = 0

    private let trimExporter: any TrimExporting
    private let livePhotoBuilder: any LivePhotoBuilding
    private let previewLoader: any LivePhotoPreviewLoading
    private let saver: any PhotoLibrarySaving
    private let tempFiles = TemporaryFileService()
    private var buildTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?

    init(
        asset: LocalVideoAsset,
        trimRange: TrimRange,
        selectedFrameTime: Double,
        selectedImage: UIImage,
        trimExporter: any TrimExporting = AVTrimExportService(),
        livePhotoBuilder: any LivePhotoBuilding = LivePhotoBuildService(),
        previewLoader: any LivePhotoPreviewLoading = PhotoKitLivePhotoPreviewService(),
        saver: any PhotoLibrarySaving = PhotoLibrarySaveService()
    ) {
        self.asset = asset
        self.trimRange = trimRange
        self.selectedFrameTime = selectedFrameTime
        self.selectedImage = selectedImage
        self.trimExporter = trimExporter
        self.livePhotoBuilder = livePhotoBuilder
        self.previewLoader = previewLoader
        self.saver = saver
    }

    func buildLivePhoto() {
        buildTask?.cancel()
        saveTask?.cancel()
        progressTask?.cancel()
        buildState = .loading
        buildProgress = 0
        livePhoto = nil
        saveState = .idle

        buildTask = Task {
            do {
                // Phase 1: Trim export (0% → 40%)
                log.info("Phase 1: trim export START")
                startProgressAnimation(from: 0, to: 0.35)
                let clipURL = try await trimExporter.exportClip(
                    from: asset.sourceURL,
                    range: trimRange
                )
                guard !Task.isCancelled else { return }
                setProgress(0.4)
                log.info("Phase 1: trim export DONE — \(clipURL.lastPathComponent)")

                // Phase 2: Build paired video + JPEG (40% → 70%)
                log.info("Phase 2: build START")
                startProgressAnimation(from: 0.4, to: 0.65)
                let stillTimeRelative = selectedFrameTime - trimRange.start
                let draft = try await livePhotoBuilder.build(
                    stillImage: selectedImage,
                    clipURL: clipURL,
                    stillTime: stillTimeRelative
                )
                guard !Task.isCancelled else { return }
                setProgress(0.7)
                log.info("Phase 2: build DONE")

                // Phase 3: Load Live Photo preview (70% → 100%)
                log.info("Phase 3: preview load START")
                startProgressAnimation(from: 0.7, to: 0.95)
                let preview = try await previewLoader.load(from: draft)
                guard !Task.isCancelled else { return }
                setProgress(1.0)
                log.info("Phase 3: preview load DONE")

                buildState = .loaded(draft)
                livePhoto = preview
            } catch is CancellationError {
                return
            } catch let error as AppError {
                log.error("Build FAILED: \(error.localizedDescription)")
                buildState = .failed(error)
            } catch {
                log.error("Build FAILED (unexpected): \(error.localizedDescription)")
                buildState = .failed(.livePhotoBuildFailed)
            }
        }
    }

    func saveLivePhoto() {
        guard case .loaded(let draft) = buildState else { return }
        saveTask?.cancel()
        saveState = .loading

        saveTask = Task {
            do {
                try await saver.save(draft: draft)
                guard !Task.isCancelled else { return }
                saveState = .loaded(())
            } catch is CancellationError {
                return
            } catch let error as AppError {
                saveState = .failed(error)
            } catch {
                saveState = .failed(.saveFailed)
            }
            tempFiles.cleanSession(at: draft.photoURL)
        }
    }

    /// Immediately set progress and stop any running animation
    private func setProgress(_ value: Double) {
        progressTask?.cancel()
        buildProgress = value
    }

    /// Gradually animate progress from `from` toward `to` over time
    private func startProgressAnimation(from start: Double, to target: Double) {
        progressTask?.cancel()
        buildProgress = start
        progressTask = Task {
            var current = start
            while !Task.isCancelled && current < target {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                // Each tick moves ~2% of the remaining distance (ease-out feel)
                let remaining = target - current
                current += remaining * 0.08
                buildProgress = current
            }
        }
    }

    deinit {
        buildTask?.cancel()
        saveTask?.cancel()
        progressTask?.cancel()
    }
}

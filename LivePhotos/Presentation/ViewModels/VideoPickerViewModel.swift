import Combine
import PhotosUI
import SwiftUI

@MainActor
final class VideoPickerViewModel: ObservableObject {
    @Published var state: ScreenState<LocalVideoAsset> = .idle
    @Published var selectedItem: PhotosPickerItem? {
        didSet {
            importVideo()
        }
    }

    private let videoImporter: any VideoImporting
    private var importTask: Task<Void, Never>?

    init(videoImporter: any VideoImporting) {
        self.videoImporter = videoImporter
    }

    func importVideo() {
        importTask?.cancel()

        guard selectedItem != nil else {
            state = .idle
            return
        }

        state = .loading
        importTask = Task { @MainActor [weak self] in
            await self?.performImport()
        }
    }

    private func performImport() async {
        guard let item = selectedItem else {
            state = .idle
            return
        }

        do {
            let asset = try await videoImporter.importVideo(item)

            guard !Task.isCancelled else {
                return
            }

            state = .loaded(asset)
        } catch is CancellationError {
            guard !Task.isCancelled else {
                return
            }

            state = .failed(.cancelled)
        } catch let error as AppError {
            guard !Task.isCancelled else {
                return
            }

            state = .failed(error)
        } catch {
            guard !Task.isCancelled else {
                return
            }

            state = .failed(.importFailed)
        }
    }
}

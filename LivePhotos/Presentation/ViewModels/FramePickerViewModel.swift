import Combine
import SwiftUI
import UIKit

@MainActor
final class FramePickerViewModel: ObservableObject {
    let asset: LocalVideoAsset
    let trimRange: TrimRange

    @Published var state: ScreenState<[FrameCandidate]> = .idle
    @Published var selectedFrame: FrameCandidate?
    @Published var highQualityImage: UIImage?

    private let frameExtractor: any FrameExtracting
    private var loadTask: Task<Void, Never>?
    private var highQualityTask: Task<Void, Never>?

    init(asset: LocalVideoAsset, trimRange: TrimRange, frameExtractor: any FrameExtracting = AVFrameExtractionService()) {
        self.asset = asset
        self.trimRange = trimRange
        self.frameExtractor = frameExtractor
    }

    func loadThumbnails() {
        loadTask?.cancel()
        highQualityTask?.cancel()
        state = .loading

        loadTask = Task {
            do {
                let candidates = try await frameExtractor.thumbnails(
                    from: asset.sourceURL,
                    range: trimRange,
                    count: 15
                )
                guard !Task.isCancelled else { return }
                state = .loaded(candidates)
                if selectedFrame == nil, let first = candidates.first {
                    selectFrame(first)
                }
            } catch let error as AppError {
                guard !Task.isCancelled else { return }
                state = .failed(error)
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(.frameExtractionFailed)
            }
        }
    }

    func selectFrame(_ candidate: FrameCandidate) {
        highQualityTask?.cancel()
        selectedFrame = candidate
        highQualityImage = nil

        highQualityTask = Task {
            do {
                let image = try await frameExtractor.highQualityFrame(
                    from: asset.sourceURL,
                    at: candidate.time
                )
                guard !Task.isCancelled else { return }
                if selectedFrame?.id == candidate.id {
                    highQualityImage = image
                }
            } catch {
                // Fall back to thumbnail quality
            }
        }
    }

    deinit {
        loadTask?.cancel()
        highQualityTask?.cancel()
    }
}

import AVFoundation
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct PhotosPickerImportService: VideoImporting {
    func importVideo(_ item: PhotosPickerItem) async throws -> LocalVideoAsset {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw AppError.importFailed
            }

            let destinationURL = try makeTemporaryURL(for: item)

            do {
                try data.write(to: destinationURL, options: .atomic)
            } catch {
                throw AppError.temporaryFileError
            }

            let asset = AVURLAsset(url: destinationURL)
            let duration = try await asset.load(.duration)
            let durationInSeconds = CMTimeGetSeconds(duration)
            let tracks = try await asset.loadTracks(withMediaType: .video)

            guard durationInSeconds.isFinite, durationInSeconds > 0, let videoTrack = tracks.first else {
                try? FileManager.default.removeItem(at: destinationURL)
                throw AppError.importFailed
            }

            let naturalSize = try await videoTrack.load(.naturalSize)

            return LocalVideoAsset(
                sourceURL: destinationURL,
                duration: durationInSeconds,
                naturalSize: naturalSize
            )
        } catch is CancellationError {
            throw AppError.cancelled
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.importFailed
        }
    }

    private func makeTemporaryURL(for item: PhotosPickerItem) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImportedVideos", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw AppError.temporaryFileError
        }

        let fileExtension = item.supportedContentTypes.first?.preferredFilenameExtension ?? "mov"

        return directoryURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
    }
}

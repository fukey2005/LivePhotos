import AVFoundation
import Foundation
import os.log

private let log = Logger(subsystem: "com.livephotos", category: "TrimExport")

struct AVTrimExportService: TrimExporting {
    func exportClip(from sourceURL: URL, range: TrimRange) async throws -> URL {
        log.info("exportClip START — range: \(range.start)-\(range.end)s")
        let asset = AVURLAsset(url: sourceURL)
        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LivePhotoBuilder", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let outputURL = outputDir.appendingPathComponent("trimmed.mov")

        let startTime = CMTime(seconds: range.start, preferredTimescale: 600)
        let endTime = CMTime(seconds: range.end, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startTime, end: endTime)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw AppError.trimExportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.timeRange = timeRange

        log.info("  exporting...")
        await exportSession.export()
        log.info("  export done — status: \(exportSession.status.rawValue)")

        guard exportSession.status == .completed else {
            log.error("  ✖ export failed: \(exportSession.error?.localizedDescription ?? "unknown")")
            throw AppError.trimExportFailed
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int) ?? 0
        log.info("  ✓ output: \(outputURL.lastPathComponent), \(fileSize) bytes")
        return outputURL
    }
}

@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import ImageIO
import os.log
import UIKit

private let log = Logger(subsystem: "com.livephotos", category: "LivePhotoBuild")

struct LivePhotoBuildService: LivePhotoBuilding {
    func build(stillImage: UIImage, clipURL: URL, stillTime: Double) async throws -> LivePhotoDraft {
        log.info("▶ build() START — stillTime=\(stillTime), clipURL=\(clipURL.lastPathComponent)")
        let assetIdentifier = UUID().uuidString

        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LivePhotoBuilder", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

        let photoURL = workDir.appendingPathComponent("still.jpg")
        let pairedVideoURL = workDir.appendingPathComponent("paired.mov")

        log.info("  [1/3] normalizing image to sRGB...")
        let normalizedImage = normalizeToSRGB(stillImage)
        log.info("  [1/3] normalized: \(Int(normalizedImage.size.width))x\(Int(normalizedImage.size.height))")

        log.info("  [2/3] writing JPEG...")
        try writeJPEG(image: normalizedImage, to: photoURL, assetIdentifier: assetIdentifier)
        let jpegSize = (try? FileManager.default.attributesOfItem(atPath: photoURL.path)[.size] as? Int) ?? 0
        log.info("  [2/3] JPEG written: \(jpegSize) bytes")

        log.info("  [3/3] writing paired video (with 30s timeout)...")
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await writePairedVideo(
                    from: clipURL, to: pairedVideoURL,
                    assetIdentifier: assetIdentifier, stillTime: stillTime
                )
            }
            group.addTask {
                try await Task.sleep(for: .seconds(30))
                log.error("  ✖ writePairedVideo TIMED OUT after 30s")
                throw AppError.livePhotoBuildFailed
            }
            try await group.next()
            group.cancelAll()
        }

        let videoSize = (try? FileManager.default.attributesOfItem(atPath: pairedVideoURL.path)[.size] as? Int) ?? 0
        log.info("▶ build() DONE — paired video: \(videoSize) bytes")

        return LivePhotoDraft(
            assetIdentifier: assetIdentifier,
            photoURL: photoURL,
            pairedVideoURL: pairedVideoURL,
            stillFrameTime: stillTime
        )
    }

    // MARK: - Image normalization

    private func normalizeToSRGB(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    // MARK: - JPEG with metadata

    private func writeJPEG(image: UIImage, to url: URL, assetIdentifier: String) throws {
        guard let imageData = image.jpegData(compressionQuality: 0.95) else {
            log.error("  ✖ jpegData() returned nil")
            throw AppError.livePhotoBuildFailed
        }
        log.debug("    jpegData: \(imageData.count) bytes")

        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let uti = CGImageSourceGetType(source) else {
            log.error("  ✖ CGImageSource creation failed")
            throw AppError.livePhotoBuildFailed
        }

        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(destinationData, uti, 1, nil) else {
            log.error("  ✖ CGImageDestination creation failed")
            throw AppError.livePhotoBuildFailed
        }

        let originalProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        var mutableProperties = originalProperties as [CFString: Any]

        var makerApple = (mutableProperties[kCGImagePropertyMakerAppleDictionary] as? [CFString: Any]) ?? [:]
        makerApple["17" as CFString] = assetIdentifier
        mutableProperties[kCGImagePropertyMakerAppleDictionary] = makerApple

        CGImageDestinationAddImageFromSource(destination, source, 0, mutableProperties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            log.error("  ✖ CGImageDestinationFinalize failed")
            throw AppError.livePhotoBuildFailed
        }

        try (destinationData as Data).write(to: url)
    }

    // MARK: - Paired Video (passthrough remux)

    private func writePairedVideo(from sourceURL: URL, to outputURL: URL, assetIdentifier: String, stillTime: Double) async throws {
        log.info("    ▷ writePairedVideo START")

        let asset = AVURLAsset(url: sourceURL)

        guard let reader = try? AVAssetReader(asset: asset) else {
            log.error("    ✖ AVAssetReader creation failed")
            throw AppError.livePhotoBuildFailed
        }

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        log.info("    tracks loaded — video: \(videoTracks.count), audio: \(audioTracks.count)")

        guard let videoTrack = videoTracks.first else {
            log.error("    ✖ no video track")
            throw AppError.livePhotoBuildFailed
        }

        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let videoFormatDescriptions = try await videoTrack.load(.formatDescriptions)
        log.info("    video formatDescriptions: \(videoFormatDescriptions.count)")

        // Passthrough reader outputs
        let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
        guard reader.canAdd(videoReaderOutput) else {
            log.error("    ✖ cannot add video reader output")
            throw AppError.livePhotoBuildFailed
        }
        reader.add(videoReaderOutput)

        var audioReaderOutput: AVAssetReaderTrackOutput?
        var audioFormatHint: CMFormatDescription?
        if let audioTrack = audioTracks.first {
            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            guard reader.canAdd(output) else {
                log.error("    ✖ cannot add audio reader output")
                throw AppError.livePhotoBuildFailed
            }
            reader.add(output)
            audioReaderOutput = output
            let fmts = try await audioTrack.load(.formatDescriptions)
            audioFormatHint = fmts.first
            log.info("    audio formatDescriptions: \(fmts.count)")
        }

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
            log.error("    ✖ AVAssetWriter creation failed")
            throw AppError.livePhotoBuildFailed
        }

        // Passthrough video writer
        let videoWriterInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: nil,
            sourceFormatHint: videoFormatDescriptions.first
        )
        videoWriterInput.transform = preferredTransform
        videoWriterInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(videoWriterInput) else {
            log.error("    ✖ cannot add video writer input")
            throw AppError.livePhotoBuildFailed
        }
        writer.add(videoWriterInput)

        // Passthrough audio writer
        var audioWriterInput: AVAssetWriterInput?
        if audioReaderOutput != nil {
            let input = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: nil,
                sourceFormatHint: audioFormatHint
            )
            input.expectsMediaDataInRealTime = false
            guard writer.canAdd(input) else {
                log.error("    ✖ cannot add audio writer input")
                throw AppError.livePhotoBuildFailed
            }
            writer.add(input)
            audioWriterInput = input
        }

        // Content identifier metadata
        let metadataItem = AVMutableMetadataItem()
        metadataItem.key = AVMetadataKey.quickTimeMetadataKeyContentIdentifier.rawValue as NSString
        metadataItem.keySpace = .quickTimeMetadata
        metadataItem.value = assetIdentifier as NSString
        metadataItem.dataType = "com.apple.metadata.datatype.UTF-8"
        writer.metadata = [metadataItem]

        // Still-image-time timed metadata
        let stillTimeMetadata = AVMutableMetadataItem()
        stillTimeMetadata.key = "com.apple.quicktime.still-image-time" as NSString
        stillTimeMetadata.keySpace = .quickTimeMetadata
        stillTimeMetadata.value = 0 as NSNumber
        stillTimeMetadata.dataType = "com.apple.metadata.datatype.int8"

        let timedMetadataGroup = AVTimedMetadataGroup(
            items: [stillTimeMetadata],
            timeRange: CMTimeRange(
                start: CMTime(seconds: stillTime, preferredTimescale: 600),
                duration: CMTime(seconds: 0.001, preferredTimescale: 600)
            )
        )

        let metadataInput = AVAssetWriterInput(
            mediaType: .metadata,
            outputSettings: nil,
            sourceFormatHint: try makeStillImageTimeMetadataFormatDescription()
        )
        metadataInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(metadataInput) else {
            log.error("    ✖ cannot add metadata writer input")
            throw AppError.livePhotoBuildFailed
        }
        writer.add(metadataInput)
        let metadataAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metadataInput)

        // Start
        guard writer.startWriting() else {
            log.error("    ✖ startWriting failed: \(writer.error?.localizedDescription ?? "unknown")")
            throw AppError.livePhotoBuildFailed
        }
        writer.startSession(atSourceTime: .zero)
        log.info("    writer started")

        guard reader.startReading() else {
            log.error("    ✖ startReading failed: \(reader.error?.localizedDescription ?? "unknown")")
            writer.cancelWriting()
            throw AppError.livePhotoBuildFailed
        }
        log.info("    reader started")

        guard metadataAdaptor.append(timedMetadataGroup) else {
            log.error("    ✖ metadata append failed")
            reader.cancelReading()
            writer.cancelWriting()
            throw AppError.livePhotoBuildFailed
        }
        metadataInput.markAsFinished()
        log.info("    metadata appended & finished")

        // Transfer video + audio CONCURRENTLY using requestMediaDataWhenReady.
        // AVAssetWriter interleaves tracks — writing all video before audio
        // causes the writer to block when its interleave buffer fills up.
        log.info("    starting concurrent transfer...")

        if let audioInput = audioWriterInput, let audioOutput = audioReaderOutput {
            let counts = await transferAllTracks(
                writer: writer,
                videoInput: videoWriterInput, videoOutput: videoReaderOutput,
                audioInput: audioInput, audioOutput: audioOutput
            )
            log.info("    transfer done — video: \(counts.video) samples, audio: \(counts.audio) samples")
        } else {
            let count = await transferSingleTrack(
                writer: writer, input: videoWriterInput,
                output: videoReaderOutput, label: "video"
            )
            log.info("    transfer done — video: \(count) samples (no audio)")
        }

        log.info("    calling finishWriting...")
        await writer.finishWriting()
        log.info("    finishWriting done — writer: \(writer.status.rawValue), reader: \(reader.status.rawValue)")

        if writer.status == .failed {
            log.error("    ✖ writer error: \(writer.error?.localizedDescription ?? "unknown")")
        }
        if reader.status == .failed {
            log.error("    ✖ reader error: \(reader.error?.localizedDescription ?? "unknown")")
        }

        guard reader.status == .completed, writer.status == .completed else {
            if reader.status != .completed { reader.cancelReading() }
            throw AppError.livePhotoBuildFailed
        }
        log.info("    ▷ writePairedVideo DONE ✓")
    }

    // MARK: - Concurrent track transfer (video + audio interleaved)

    /// Transfers video and audio samples concurrently using requestMediaDataWhenReady
    /// on separate dispatch queues. This allows AVAssetWriter to interleave tracks properly.
    private func transferAllTracks(
        writer: AVAssetWriter,
        videoInput: AVAssetWriterInput, videoOutput: AVAssetReaderTrackOutput,
        audioInput: AVAssetWriterInput, audioOutput: AVAssetReaderTrackOutput
    ) async -> (video: Int, audio: Int) {
        await withCheckedContinuation { (continuation: CheckedContinuation<(video: Int, audio: Int), Never>) in
            let videoQueue = DispatchQueue(label: "transfer.video")
            let audioQueue = DispatchQueue(label: "transfer.audio")
            // Synchronize completion tracking on a dedicated queue
            let syncQueue = DispatchQueue(label: "transfer.sync")

            var videoCount = 0
            var audioCount = 0
            var videoFinished = false
            var audioFinished = false
            var didResume = false

            func checkCompletion() {
                // Must be called on syncQueue
                guard videoFinished, audioFinished, !didResume else { return }
                didResume = true
                continuation.resume(returning: (video: videoCount, audio: audioCount))
            }

            videoInput.requestMediaDataWhenReady(on: videoQueue) {
                while videoInput.isReadyForMoreMediaData {
                    guard writer.status == .writing else {
                        log.warning("      [video] writer not writing at sample \(videoCount)")
                        videoInput.markAsFinished()
                        syncQueue.async { videoFinished = true; checkCompletion() }
                        return
                    }
                    guard let sample = videoOutput.copyNextSampleBuffer() else {
                        log.debug("      [video] no more samples after \(videoCount)")
                        videoInput.markAsFinished()
                        syncQueue.async { videoFinished = true; checkCompletion() }
                        return
                    }
                    if !videoInput.append(sample) {
                        log.error("      [video] append failed at \(videoCount)")
                        videoInput.markAsFinished()
                        syncQueue.async { videoFinished = true; checkCompletion() }
                        return
                    }
                    videoCount += 1
                }
            }

            audioInput.requestMediaDataWhenReady(on: audioQueue) {
                while audioInput.isReadyForMoreMediaData {
                    guard writer.status == .writing else {
                        log.warning("      [audio] writer not writing at sample \(audioCount)")
                        audioInput.markAsFinished()
                        syncQueue.async { audioFinished = true; checkCompletion() }
                        return
                    }
                    guard let sample = audioOutput.copyNextSampleBuffer() else {
                        log.debug("      [audio] no more samples after \(audioCount)")
                        audioInput.markAsFinished()
                        syncQueue.async { audioFinished = true; checkCompletion() }
                        return
                    }
                    if !audioInput.append(sample) {
                        log.error("      [audio] append failed at \(audioCount)")
                        audioInput.markAsFinished()
                        syncQueue.async { audioFinished = true; checkCompletion() }
                        return
                    }
                    audioCount += 1
                }
            }
        }
    }

    // MARK: - Single track transfer (video only, no audio)

    private func transferSingleTrack(
        writer: AVAssetWriter, input: AVAssetWriterInput,
        output: AVAssetReaderTrackOutput, label: String
    ) async -> Int {
        await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            var count = 0
            var finished = false
            let queue = DispatchQueue(label: "transfer.\(label)")

            input.requestMediaDataWhenReady(on: queue) {
                guard !finished else { return }

                guard writer.status == .writing else {
                    finished = true
                    input.markAsFinished()
                    continuation.resume(returning: count)
                    return
                }

                while input.isReadyForMoreMediaData {
                    guard let sample = output.copyNextSampleBuffer() else {
                        finished = true
                        input.markAsFinished()
                        continuation.resume(returning: count)
                        return
                    }
                    if !input.append(sample) {
                        finished = true
                        input.markAsFinished()
                        continuation.resume(returning: count)
                        return
                    }
                    count += 1
                }
            }
        }
    }

    private func makeStillImageTimeMetadataFormatDescription() throws -> CMFormatDescription {
        let metadataSpecifications: [[CFString: Any]] = [[
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier: "mdta/com.apple.quicktime.still-image-time",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType: "com.apple.metadata.datatype.int8"
        ]]

        var formatDescription: CMFormatDescription?
        let status = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: metadataSpecifications as CFArray,
            formatDescriptionOut: &formatDescription
        )

        guard status == noErr, let formatDescription else {
            log.error("    ✖ metadata format description creation failed: \(status)")
            throw AppError.livePhotoBuildFailed
        }

        return formatDescription
    }
}

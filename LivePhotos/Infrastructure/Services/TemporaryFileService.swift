import Foundation

struct TemporaryFileService: Sendable {
    private let baseDirectory: URL

    init() {
        baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LivePhotoBuilder", isDirectory: true)
    }

    func cleanAll() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }

    func cleanSession(at url: URL) {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: directory)
    }
}

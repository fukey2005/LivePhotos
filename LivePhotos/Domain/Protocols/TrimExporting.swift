import Foundation

protocol TrimExporting: Sendable {
    func exportClip(from sourceURL: URL, range: TrimRange) async throws -> URL
}

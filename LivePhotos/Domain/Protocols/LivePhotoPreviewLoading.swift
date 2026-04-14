import Photos

protocol LivePhotoPreviewLoading: Sendable {
    func load(from draft: LivePhotoDraft) async throws -> PHLivePhoto
}

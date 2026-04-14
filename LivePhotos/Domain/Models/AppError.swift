import Foundation

enum AppError: LocalizedError, Sendable {
    case photoLibraryPermissionDenied
    case importFailed
    case invalidTrimRange
    case frameExtractionFailed
    case trimExportFailed
    case livePhotoBuildFailed
    case livePhotoPreviewFailed
    case saveFailed
    case temporaryFileError
    case cancelled

    var errorDescription: String? {
        switch self {
        case .photoLibraryPermissionDenied:
            "写真ライブラリへのアクセスが許可されていません。"
        case .importFailed:
            "動画の読み込みに失敗しました。"
        case .invalidTrimRange:
            "トリミング範囲が不正です。"
        case .frameExtractionFailed:
            "フレームの抽出に失敗しました。"
        case .trimExportFailed:
            "動画の書き出しに失敗しました。"
        case .livePhotoBuildFailed:
            "Live Photoの生成に失敗しました。"
        case .livePhotoPreviewFailed:
            "Live Photoプレビューの読み込みに失敗しました。"
        case .saveFailed:
            "写真ライブラリへの保存に失敗しました。"
        case .temporaryFileError:
            "一時ファイルの作成に失敗しました。"
        case .cancelled:
            "処理がキャンセルされました。"
        }
    }
}

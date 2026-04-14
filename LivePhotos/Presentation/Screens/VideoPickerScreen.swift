import PhotosUI
import SwiftUI

struct VideoPickerScreen: View {
    @StateObject private var viewModel: VideoPickerViewModel
    @State private var navigationPath = NavigationPath()

    init(videoImporter: any VideoImporting = PhotosPickerImportService()) {
        _viewModel = StateObject(wrappedValue: VideoPickerViewModel(videoImporter: videoImporter))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                mainContent

                VStack(spacing: 12) {
                    PhotosPicker(
                        selection: $viewModel.selectedItem,
                        matching: .videos,
                        photoLibrary: .shared()
                    ) {
                        Label("動画を選択", systemImage: "video.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if case .loaded(let asset) = viewModel.state {
                        HStack(spacing: 16) {
                            infoItem(icon: "clock", label: "長さ", value: formatDuration(asset.duration))
                            Divider().frame(height: 20)
                            infoItem(icon: "arrow.up.left.and.arrow.down.right", label: "解像度", value: "\(Int(asset.naturalSize.width))×\(Int(asset.naturalSize.height))")
                            Divider().frame(height: 20)
                            infoItem(icon: "doc", label: "形式", value: asset.sourceURL.pathExtension.uppercased())
                        }
                        .frame(maxWidth: .infinity)

                        Button("トリミングへ進む") {
                            navigationPath.append(NavigationRoute.trim(asset))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color.white)
            }
            .navigationTitle("Video to Live Photo")
            .navigationDestination(for: NavigationRoute.self) { route in
                switch route {
                case .trim(let asset):
                    TrimEditorScreen(asset: asset, navigationPath: $navigationPath)
                case .framePicker(let asset, let trimRange):
                    FramePickerScreen(asset: asset, trimRange: trimRange, navigationPath: $navigationPath)
                case .preview(let asset, let trimRange, let frameTime, let image):
                    LivePhotoPreviewScreen(
                        asset: asset, trimRange: trimRange,
                        selectedFrameTime: frameTime, selectedImage: image,
                        navigationPath: $navigationPath
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.state {
        case .idle:
            ContentUnavailableView("動画を選択してください", systemImage: "livephoto")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("動画を読み込み中…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let asset):
            VideoPlayerView(url: asset.sourceURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
                .padding(.top, 8)
        case .failed(let error):
            VStack(alignment: .center, spacing: 12) {
                Label("読み込みに失敗しました", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text(error.localizedDescription).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func infoItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.caption).foregroundStyle(.tertiary)
            Text(value).font(.subheadline.monospacedDigit().bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let frac = Int((seconds - Double(Int(seconds))) * 10)
        if mins > 0 { return String(format: "%d:%02d.%d", mins, secs, frac) }
        return String(format: "%d.%d秒", secs, frac)
    }
}

#Preview {
    VideoPickerScreen()
}

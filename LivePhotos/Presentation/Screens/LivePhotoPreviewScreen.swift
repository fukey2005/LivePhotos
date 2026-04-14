import Combine
import Photos
import PhotosUI
import SwiftUI
import UIKit

struct LivePhotoPreviewScreen: View {
    @StateObject private var viewModel: LivePhotoPreviewViewModel
    @State private var isShowingSaveSuccessAlert = false
    @Environment(\.dismiss) private var dismiss
    @Binding private var navigationPath: NavigationPath

    init(
        asset: LocalVideoAsset,
        trimRange: TrimRange,
        selectedFrameTime: Double,
        selectedImage: UIImage,
        navigationPath: Binding<NavigationPath>
    ) {
        self._navigationPath = navigationPath
        _viewModel = StateObject(
            wrappedValue: LivePhotoPreviewViewModel(
                asset: asset,
                trimRange: trimRange,
                selectedFrameTime: selectedFrameTime,
                selectedImage: selectedImage
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Preview (fills available space) ──
            previewContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
                .padding(.top, 8)

            // ── Bottom controls (pinned) ──
            VStack(spacing: 12) {
                // Progress bar
                if case .loading = viewModel.buildState {
                    VStack(spacing: 4) {
                        ProgressView(value: viewModel.buildProgress)
                            .progressViewStyle(.linear)
                            .animation(.easeOut(duration: 0.3), value: viewModel.buildProgress)
                        Text(buildPhaseLabel)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } else if case .idle = viewModel.buildState {
                    VStack(spacing: 4) {
                        ProgressView(value: 0)
                            .progressViewStyle(.linear)
                        Text("準備中…")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                statusText

                // Action buttons
                HStack(spacing: 12) {
                    Button("戻る") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(.gray)
                        .controlSize(.large)
                    Spacer()
                    Button("保存") { viewModel.saveLivePhoto() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!canSave)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.white)
        }
        .navigationTitle("Live Photo プレビュー")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task {
            viewModel.buildLivePhoto()
        }
        .onReceive(viewModel.$saveState) { state in
            if case .loaded = state {
                isShowingSaveSuccessAlert = true
            }
        }
        .alert("保存完了", isPresented: $isShowingSaveSuccessAlert) {
            Button("OK") {
                navigationPath = NavigationPath()
            }
        } message: {
            Text("Live Photoが写真ライブラリに保存されました。")
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch viewModel.buildState {
        case .idle, .loading:
            ZStack {
                Image(uiImage: viewModel.selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.4)

                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Live Photoを生成中…")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))

        case .loaded:
            if let livePhoto = viewModel.livePhoto {
                LivePhotoView(livePhoto: livePhoto)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(uiImage: viewModel.selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .failed(let error):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("再試行") { viewModel.buildLivePhoto() }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var statusText: some View {
        Group {
            switch viewModel.saveState {
            case .loading:
                Text("保存中…").foregroundStyle(.secondary)
            case .failed(let error):
                Text(error.localizedDescription).foregroundStyle(.red)
            default:
                EmptyView()
            }
        }
        .font(.subheadline)
    }

    private var buildPhaseLabel: String {
        let p = viewModel.buildProgress
        if p < 0.4 { return "動画をトリミング中…" }
        if p < 0.7 { return "Live Photo を構築中…" }
        return "プレビューを読み込み中…"
    }

    private var canSave: Bool {
        if case .loaded = viewModel.buildState {
            if case .loading = viewModel.saveState { return false }
            if case .loaded = viewModel.saveState { return false }
            return true
        }
        return false
    }
}

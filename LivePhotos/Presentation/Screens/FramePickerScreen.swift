import SwiftUI
import UIKit

struct FramePickerScreen: View {
    @StateObject private var viewModel: FramePickerViewModel
    @Environment(\.dismiss) private var dismiss
    @Binding private var navigationPath: NavigationPath

    init(asset: LocalVideoAsset, trimRange: TrimRange, navigationPath: Binding<NavigationPath>) {
        self._navigationPath = navigationPath
        _viewModel = StateObject(
            wrappedValue: FramePickerViewModel(asset: asset, trimRange: trimRange)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Frame preview (fills available space) ──
            selectedFramePreview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
                .padding(.top, 8)

            // ── Bottom controls (pinned) ──
            VStack(spacing: 12) {
                // Time display
                if let frame = viewModel.selectedFrame {
                    Text(String(format: "%.2f 秒", frame.time))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                // Thumbnail scroll
                thumbnailStrip
                    .frame(height: 72)

                // Navigation
                HStack(spacing: 12) {
                    Button("戻る") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(.gray)
                        .controlSize(.large)
                    Spacer()
                    Button("次へ") {
                        guard let frame = viewModel.selectedFrame else { return }
                        let image = viewModel.highQualityImage ?? frame.image
                        navigationPath.append(
                            NavigationRoute.preview(viewModel.asset, viewModel.trimRange, frame.time, image)
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.selectedFrame == nil)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.white)
        }
        .navigationTitle("フレーム選択")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task {
            viewModel.loadThumbnails()
        }
    }

    @ViewBuilder
    private var selectedFramePreview: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("フレームを読み込み中…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))

        case .loaded:
            if let image = viewModel.highQualityImage ?? viewModel.selectedFrame?.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.gray.opacity(0.1)
            }

        case .failed(let error):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("再試行") { viewModel.loadThumbnails() }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var thumbnailStrip: some View {
        if case .loaded(let candidates) = viewModel.state {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(candidates) { candidate in
                        Button {
                            viewModel.selectFrame(candidate)
                        } label: {
                            Image(uiImage: candidate.image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 54, height: 72)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(
                                            viewModel.selectedFrame?.id == candidate.id
                                                ? Color.accentColor
                                                : Color.clear,
                                            lineWidth: 3
                                        )
                                )
                        }
                    }
                }
            }
        }
    }
}

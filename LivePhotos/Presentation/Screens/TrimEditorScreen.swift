import AVKit
import Combine
import SwiftUI

struct TrimEditorScreen: View {
    @StateObject private var viewModel: TrimEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @Binding private var navigationPath: NavigationPath

    init(asset: LocalVideoAsset, navigationPath: Binding<NavigationPath>) {
        self._navigationPath = navigationPath
        _viewModel = StateObject(wrappedValue: TrimEditorViewModel(asset: asset))
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Video player (fills available space) ──
            VideoPlayer(player: viewModel.player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
                .padding(.top, 8)

            // ── Bottom controls (pinned) ──
            VStack(spacing: 12) {
                // Playback controls
                HStack {
                    Button(action: { viewModel.togglePlayback() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    Spacer()
                    Text(formatTime(viewModel.currentTime))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                // Full-video seek bar
                VStack(alignment: .leading, spacing: 2) {
                    Text("全体")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    VideoSeekBarView(
                        videoURL: viewModel.asset.sourceURL,
                        duration: viewModel.asset.duration,
                        currentTime: viewModel.currentTime,
                        trimStart: viewModel.trimStart,
                        trimEnd: viewModel.trimEnd,
                        onSeek: { time in
                            viewModel.pause()
                            viewModel.seekGlobal(to: time)
                        }
                    )
                    .frame(height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // "Set start here" button
                Button {
                    viewModel.setTrimStartAtCurrentTime()
                } label: {
                    Label("ここから開始", systemImage: "arrow.right.to.line")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .controlSize(.regular)

                // Trim range slider
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("トリム範囲")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("\(String(format: "%.1f", viewModel.trimDuration))秒")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                        if !viewModel.isValidTrim {
                            Text("(1〜5秒)")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    ZStack {
                        ThumbnailStripView(videoURL: viewModel.asset.sourceURL)
                        RangeSliderView(
                            duration: viewModel.asset.duration,
                            trimStart: $viewModel.trimStart,
                            trimEnd: $viewModel.trimEnd,
                            currentTime: viewModel.currentTime
                        )
                    }
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Navigation
                HStack(spacing: 12) {
                    Button("戻る") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(.gray)
                        .controlSize(.large)
                    Spacer()
                    Button("次へ") {
                        navigationPath.append(
                            NavigationRoute.framePicker(viewModel.asset, viewModel.trimRange)
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.isValidTrim)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.white)
        }
        .navigationTitle("トリミング")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let frac = Int((seconds - Double(Int(seconds))) * 10)
        return String(format: "%d:%02d.%d", mins, secs, frac)
    }
}

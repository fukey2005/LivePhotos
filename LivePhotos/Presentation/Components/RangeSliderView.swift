import SwiftUI

struct RangeSliderView: View {
    let duration: Double
    @Binding var trimStart: Double
    @Binding var trimEnd: Double
    let currentTime: Double

    private let handleWidth: CGFloat = 16
    private let minDuration: Double = 1.0
    private let maxDuration: Double = 5.0

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width - handleWidth * 2
            let pxPerSec = duration > 0 ? trackWidth / duration : 0

            ZStack(alignment: .leading) {
                // Gray overlay left
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: handleWidth + CGFloat(trimStart) * pxPerSec)

                // Gray overlay right
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: handleWidth + CGFloat(duration - trimEnd) * pxPerSec)
                    .position(x: geometry.size.width - (handleWidth + CGFloat(duration - trimEnd) * pxPerSec) / 2,
                              y: geometry.size.height / 2)

                // Selected region border
                let leftX = handleWidth + CGFloat(trimStart) * pxPerSec
                let rightX = handleWidth + CGFloat(trimEnd) * pxPerSec
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .frame(width: rightX - leftX + handleWidth * 2)
                    .offset(x: leftX - handleWidth)

                // Left handle
                handleView()
                    .offset(x: CGFloat(trimStart) * pxPerSec)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newStart = max(0, Double(value.location.x) / pxPerSec)
                                let clamped = min(newStart, trimEnd - minDuration)
                                if trimEnd - clamped <= maxDuration {
                                    trimStart = max(0, clamped)
                                }
                            }
                    )

                // Right handle
                handleView()
                    .offset(x: handleWidth + CGFloat(trimEnd) * pxPerSec)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newEnd = min(duration, Double(value.location.x - handleWidth) / pxPerSec)
                                let clamped = max(newEnd, trimStart + minDuration)
                                if clamped - trimStart <= maxDuration {
                                    trimEnd = min(duration, clamped)
                                }
                            }
                    )

                // Playback head
                if currentTime >= trimStart && currentTime <= trimEnd {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                        .offset(x: handleWidth + CGFloat(currentTime) * pxPerSec - 1)
                }
            }
        }
    }

    private func handleView() -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.accentColor)
            .frame(width: handleWidth)
    }
}

import Foundation
import UIKit

enum NavigationRoute: Hashable {
    case trim(LocalVideoAsset)
    case framePicker(LocalVideoAsset, TrimRange)
    case preview(LocalVideoAsset, TrimRange, Double, UIImage)

    static func == (lhs: NavigationRoute, rhs: NavigationRoute) -> Bool {
        switch (lhs, rhs) {
        case let (.trim(a), .trim(b)):
            return a.sourceURL == b.sourceURL
        case let (.framePicker(a1, a2), .framePicker(b1, b2)):
            return a1.sourceURL == b1.sourceURL && a2.start == b2.start && a2.end == b2.end
        case let (.preview(a1, a2, a3, _), .preview(b1, b2, b3, _)):
            return a1.sourceURL == b1.sourceURL && a2.start == b2.start && a3 == b3
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .trim(let asset):
            hasher.combine(0)
            hasher.combine(asset.sourceURL)
        case .framePicker(let asset, let range):
            hasher.combine(1)
            hasher.combine(asset.sourceURL)
            hasher.combine(range.start)
        case .preview(let asset, _, let frameTime, _):
            hasher.combine(2)
            hasher.combine(asset.sourceURL)
            hasher.combine(frameTime)
        }
    }
}

import Foundation

struct TrimRange: Sendable {
    let start: Double
    let end: Double

    var duration: Double {
        end - start
    }
}

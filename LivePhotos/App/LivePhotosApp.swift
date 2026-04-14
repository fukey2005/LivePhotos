import SwiftUI

@main
struct LivePhotosApp: App {
    var body: some Scene {
        WindowGroup {
            VideoPickerScreen()
                .preferredColorScheme(.light)
        }
    }
}

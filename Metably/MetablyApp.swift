import MetablyFeatures
import SwiftUI

/// App entry point. Kept deliberately thin: all screens, logic and storage live in the
/// MetablyKit Swift package (Packages/MetablyKit), so they can be tested without the app.
@main
struct MetablyApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}

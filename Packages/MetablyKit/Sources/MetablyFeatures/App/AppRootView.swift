import MetablyDomain
import SwiftUI

/// Entry point used by the app target. Builds dependencies once and shows the main tabs,
/// or a calm error screen if the local store cannot be opened.
public struct AppRootView: View {
    private enum LaunchState {
        case ready(AppDependencies)
        case failed
    }

    @State private var launchState: LaunchState

    public init() {
        do {
            let dependencies = try AppDependencies.live()
            _launchState = State(initialValue: .ready(dependencies))
        } catch {
            _launchState = State(initialValue: .failed)
        }
    }

    public var body: some View {
        switch launchState {
        case let .ready(dependencies):
            MainTabView(dependencies: dependencies)
        case .failed:
            ContentUnavailableView {
                Label {
                    Text("launch.error.title", bundle: .module)
                } icon: {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                }
            } description: {
                Text("launch.error.message", bundle: .module)
            }
        }
    }
}

import MetablyDomain
import SwiftUI

/// Entry point used by the app target. Builds dependencies once and shows the main tabs,
/// or a calm error screen if the local store cannot be opened.
public struct AppRootView: View {
    private enum LaunchState {
        case ready(AppDependencies, GlucoseLogModel)
        case failed
    }

    @State private var launchState: LaunchState

    public init() {
        do {
            let dependencies = try AppDependencies.live()
            _launchState = State(initialValue: .ready(dependencies, GlucoseLogModel(dependencies: dependencies)))
        } catch {
            _launchState = State(initialValue: .failed)
        }
    }

    public var body: some View {
        switch launchState {
        case let .ready(dependencies, logModel):
            MainTabView(dependencies: dependencies, logModel: logModel)
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

struct MainTabView: View {
    let dependencies: AppDependencies
    let logModel: GlucoseLogModel

    var body: some View {
        TabView {
            NavigationStack {
                GlucoseLogView(model: logModel, preferences: dependencies.preferences)
            }
            .tabItem {
                Label {
                    Text("tab.diary", bundle: .module)
                } icon: {
                    Image(systemName: "list.bullet.rectangle")
                }
            }

            NavigationStack {
                SettingsView(preferences: dependencies.preferences, logModel: logModel)
            }
            .tabItem {
                Label {
                    Text("tab.settings", bundle: .module)
                } icon: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    MainTabView(dependencies: dependencies, logModel: GlucoseLogModel(dependencies: dependencies))
}

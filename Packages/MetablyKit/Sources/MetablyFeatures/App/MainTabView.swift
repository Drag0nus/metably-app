import MetablyDomain
import SwiftUI

/// The five MVP tabs. Persisted for state restoration only, so raw values may change freely.
enum AppTab: String, Hashable, CaseIterable {
    case today
    case journal
    case meals
    case medications
    case reports
}

/// Five tabs in the iOS 26 floating tab bar, plus a bottom accessory that keeps
/// "Record reading" one tap away on every tab. On iPad the tabs become a sidebar.
///
/// SwiftUI note: `@State` here owns the screen models for the lifetime of this view, and
/// the entry sheet is driven by an optional model (`sheet(item:)`): setting it shows the sheet,
/// and SwiftUI sets it back to nil when the sheet closes.
struct MainTabView: View {
    let dependencies: AppDependencies

    @State private var selection: AppTab = .today
    @State private var todayModel: TodayModel
    @State private var logModel: GlucoseLogModel
    @State private var entryModel: GlucoseEntryModel?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _todayModel = State(initialValue: TodayModel(dependencies: dependencies))
        _logModel = State(initialValue: GlucoseLogModel(dependencies: dependencies))
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: AppTab.today) {
                NavigationStack {
                    TodayView(
                        model: todayModel,
                        preferences: dependencies.preferences,
                        logModel: logModel,
                        onRecordReading: recordReading
                    )
                }
            } label: {
                TabLabel(titleKey: "tab.today", systemImage: "sun.max")
            }

            Tab(value: AppTab.journal) {
                NavigationStack {
                    GlucoseLogView(model: logModel, preferences: dependencies.preferences)
                }
            } label: {
                TabLabel(titleKey: "tab.journal", systemImage: "list.bullet.rectangle")
            }

            Tab(value: AppTab.meals) {
                NavigationStack {
                    ComingSoonView(titleKey: "tab.meals", systemImage: "fork.knife", messageKey: "soon.meals")
                }
            } label: {
                TabLabel(titleKey: "tab.meals", systemImage: "fork.knife")
            }

            Tab(value: AppTab.medications) {
                NavigationStack {
                    ComingSoonView(titleKey: "tab.medications", systemImage: "pills", messageKey: "soon.medications")
                }
            } label: {
                TabLabel(titleKey: "tab.medications", systemImage: "pills")
            }

            Tab(value: AppTab.reports) {
                NavigationStack {
                    ComingSoonView(titleKey: "tab.reports", systemImage: "doc.text", messageKey: "soon.reports")
                }
            } label: {
                TabLabel(titleKey: "tab.reports", systemImage: "doc.text")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        #if os(iOS)
        .tabViewBottomAccessory {
            Button(action: recordReading) {
                Label {
                    Text("action.recordReading", bundle: .module)
                } icon: {
                    Image(systemName: "plus.circle.fill")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .accessibilityHint(Text("action.recordReading.hint", bundle: .module))
        }
        #endif
        .sheet(item: $entryModel) { entry in
            GlucoseEntryView(model: entry) {
                dependencies.preferences.lastActivityLevel = entry.activityLevel
                todayModel.reload()
                logModel.reload()
            }
        }
    }

    private func recordReading() {
        entryModel = dependencies.makeGlucoseEntryModel()
    }
}

private struct TabLabel: View {
    let titleKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label {
            Text(titleKey, bundle: .module)
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

/// Honest placeholder for a tab whose screens come in a later pull request.
struct ComingSoonView: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    let messageKey: LocalizedStringKey

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("soon.title", bundle: .module)
            } icon: {
                Image(systemName: systemImage)
            }
        } description: {
            Text(messageKey, bundle: .module)
        }
        .navigationTitle(Text(titleKey, bundle: .module))
    }
}

#Preview {
    MainTabView(dependencies: AppDependencies.preview())
}

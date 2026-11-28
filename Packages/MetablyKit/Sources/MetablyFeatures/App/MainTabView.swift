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
    @State private var mealsModel: MealsModel
    @State private var entryModel: GlucoseEntryModel?
    /// Set by pushed screens such as Settings that should show without "Record reading".
    @State private var recordAccessoryHidden = false
    /// First launch: profile, then reminders. Shown until the user finishes or skips.
    @State private var onboarding: OnboardingModel?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _todayModel = State(initialValue: TodayModel(dependencies: dependencies))
        _logModel = State(initialValue: GlucoseLogModel(dependencies: dependencies))
        _mealsModel = State(initialValue: MealsModel(dependencies: dependencies))
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: AppTab.today) {
                NavigationStack {
                    TodayView(
                        model: todayModel,
                        preferences: dependencies.preferences,
                        logModel: logModel,
                        onRecordReading: recordReading,
                        recordAccessoryHidden: $recordAccessoryHidden,
                        profileStore: dependencies.profileStore,
                        reminderCoordinator: dependencies.reminderCoordinator
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
                    MealsView(model: mealsModel)
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
        .modifier(RecordReadingAccessory(isHidden: recordAccessoryHidden, action: recordReading))
        #endif
        .sheet(item: $entryModel) { entry in
            GlucoseEntryView(model: entry) {
                dependencies.preferences.lastActivityLevel = entry.activityLevel
                todayModel.reload()
                logModel.reload()
            }
        }
        .sheet(item: $onboarding) { model in
            OnboardingView(model: model, preferences: dependencies.preferences, reminders: dependencies.reminderCoordinator) {
                dependencies.profileStore.completeOnboarding()
                onboarding = nil
            }
            .interactiveDismissDisabled()
        }
        .task {
            if !dependencies.profileStore.hasCompletedOnboarding {
                onboarding = OnboardingModel(
                    editor: ProfileEditorModel(
                        profileStore: dependencies.profileStore,
                        preferences: dependencies.preferences,
                        reminders: dependencies.reminderCoordinator
                    )
                )
            }
            // Keep the daily plan in step with the profile and the clock.
            await dependencies.reminderCoordinator.applyIfAllowed()
        }
    }

    private func recordReading() {
        entryModel = dependencies.makeGlucoseEntryModel()
    }
}

#if os(iOS)
/// "Record reading" as the TabView's bottom accessory.
///
/// `.toolbarVisibility(.hidden, for: .tabBar)` on a pushed screen hides the tab bar but not the
/// accessory, so the accessory is switched off explicitly with `isEnabled` (iOS 26.1 and later).
/// The `#available` branch is fixed for a device, so the TabView keeps its identity and state.
private struct RecordReadingAccessory: ViewModifier {
    let isHidden: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: !isHidden) { button }
        } else {
            content.tabViewBottomAccessory { button }
        }
    }

    private var button: some View {
        Button(action: action) {
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
}
#endif

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

import MetablyDomain
import Observation
import SwiftUI

/// State for the first-launch sheet: the profile draft and which step is shown.
@Observable
@MainActor
final class OnboardingModel: Identifiable {
    enum Step: Hashable {
        case reminders
    }

    let id = UUID()
    let editor: ProfileEditorModel
    var path: [Step] = []

    init(editor: ProfileEditorModel) {
        self.editor = editor
    }
}

/// First launch: the profile, then the reminder plan built from it. Every field is optional,
/// and "Skip" goes straight to the app; both can be changed later in Settings.
///
/// SwiftUI note: `NavigationStack(path:)` pushes the reminders step by appending to `path`,
/// so the profile's "Next" button moves forward without a `NavigationLink`.
struct OnboardingView: View {
    @Bindable var model: OnboardingModel
    let preferences: UserPreferencesStore
    let reminders: ReminderCoordinator
    let onFinish: () -> Void

    var body: some View {
        NavigationStack(path: $model.path) {
            ProfileView(
                model: model.editor,
                onSaved: { model.path.append(.reminders) },
                saveTitleKey: "onboarding.next",
                introKey: "onboarding.intro"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onFinish) {
                        Text("onboarding.skip", bundle: .module)
                    }
                }
            }
            .navigationDestination(for: OnboardingModel.Step.self) { step in
                switch step {
                case .reminders:
                    RemindersView(preferences: preferences, coordinator: reminders, onDone: onFinish)
                }
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    OnboardingView(
        model: OnboardingModel(editor: ProfileEditorModel(
            profileStore: dependencies.profileStore,
            preferences: dependencies.preferences
        )),
        preferences: dependencies.preferences,
        reminders: dependencies.reminderCoordinator,
        onFinish: {}
    )
}

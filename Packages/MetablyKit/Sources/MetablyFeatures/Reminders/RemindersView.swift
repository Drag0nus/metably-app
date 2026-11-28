import MetablyDomain
import SwiftUI

/// "Нагадування": the daily plan built from the profile and routine. Each group and each
/// reminder can be switched off. Permission is asked only when the user taps "Turn on".
struct RemindersView: View {
    @Bindable var preferences: UserPreferencesStore
    let coordinator: ReminderCoordinator
    /// Shown during onboarding as the last step.
    var onDone: (() -> Void)?

    var body: some View {
        Form {
            permissionSection

            Section {
                Toggle(isOn: $preferences.reminderSettings.glucoseChecks) {
                    Text("reminders.group.checks", bundle: .module)
                }
                Toggle(isOn: $preferences.reminderSettings.meals) {
                    Text("reminders.group.meals", bundle: .module)
                }
                Toggle(isOn: $preferences.reminderSettings.medications) {
                    Text("reminders.group.medications", bundle: .module)
                }
                Toggle(isOn: $preferences.reminderSettings.water) {
                    Text("reminders.group.water", bundle: .module)
                }
                if preferences.reminderSettings.water {
                    Picker(selection: $preferences.reminderSettings.waterIntervalMinutes) {
                        ForEach(ReminderSettings.waterIntervalOptions, id: \.self) { minutes in
                            Text(verbatim: ReminderCoordinator.duration(minutes: minutes)).tag(minutes)
                        }
                    } label: {
                        Text("reminders.water.interval", bundle: .module)
                    }
                }
            } header: {
                Text("reminders.groups", bundle: .module)
            }

            Section {
                Toggle(isOn: $preferences.reminderSettings.postMealCheck) {
                    Text("reminders.postMeal", bundle: .module)
                }
                if preferences.reminderSettings.postMealCheck {
                    Picker(selection: $preferences.reminderSettings.postMealMinutes) {
                        ForEach(ReminderSettings.postMealOptions, id: \.self) { minutes in
                            Text(verbatim: ReminderCoordinator.duration(minutes: minutes)).tag(minutes)
                        }
                    } label: {
                        Text("reminders.postMeal.after", bundle: .module)
                    }
                }
            } footer: {
                Text("reminders.postMeal.footer", bundle: .module)
            }

            Section {
                let plan = coordinator.plan
                if plan.isEmpty {
                    Text("reminders.plan.empty", bundle: .module)
                        .foregroundStyle(.secondary)
                }
                ForEach(plan) { item in
                    Toggle(isOn: Binding(
                        get: { item.isEnabled },
                        set: { coordinator.setEnabled($0, id: item.id) }
                    )) {
                        HStack {
                            Text(verbatim: MinuteOfDayFormat.text(item.minute))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 56, alignment: .leading)
                            Text(verbatim: coordinator.label(for: item.kind))
                        }
                    }
                }
            } header: {
                Text("reminders.plan", bundle: .module)
            } footer: {
                Text("reminders.plan.footer", bundle: .module)
            }
        }
        .navigationTitle(Text("reminders.title", bundle: .module))
        .toolbar {
            if let onDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onDone()
                    } label: {
                        Text("common.done", bundle: .module)
                    }
                }
            }
        }
        .task { await coordinator.refreshAuthorization() }
        // Changes apply when leaving the screen, so moving a toggle does not reschedule every time.
        .onDisappear {
            let coordinator = coordinator
            Task { await coordinator.applyIfAllowed() }
        }
    }

    @ViewBuilder
    private var permissionSection: some View {
        Section {
            switch coordinator.authorization {
            case .allowed:
                Label {
                    Text("reminders.permission.allowed", bundle: .module)
                } icon: {
                    Image(systemName: "bell.badge")
                }
            case .notDetermined:
                Button {
                    Task { await coordinator.enableAndApply() }
                } label: {
                    Label {
                        Text("reminders.permission.ask", bundle: .module)
                    } icon: {
                        Image(systemName: "bell")
                    }
                }
            case .denied:
                Label {
                    Text("reminders.permission.denied", bundle: .module)
                } icon: {
                    Image(systemName: "bell.slash")
                }
                .foregroundStyle(.secondary)
            }
        } footer: {
            Text("reminders.privacy.footer", bundle: .module)
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    NavigationStack {
        RemindersView(preferences: dependencies.preferences, coordinator: dependencies.reminderCoordinator)
    }
}

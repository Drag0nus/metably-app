import MetablyDomain
import SwiftUI

/// "Профіль": diabetes type, medicines with the user's own doses and times, height and weight
/// (BMI shown as a plain number), and the usual day. Used in Settings and on first launch.
///
/// SwiftUI note: `ForEach($model.medicines)` gives each section a binding to one medicine, so
/// its text fields edit the draft directly.
struct ProfileView: View {
    @Bindable var model: ProfileEditorModel
    /// Called after a successful save.
    var onSaved: () -> Void = {}
    /// Shown as the confirm button title, e.g. "Далі" during onboarding.
    var saveTitleKey: LocalizedStringKey = "common.save"
    /// An explanation shown above the form, used on first launch.
    var introKey: LocalizedStringKey?

    var body: some View {
        Form {
            if let introKey {
                Section {
                    Text(introKey, bundle: .module)
                }
            }

            Section {
                Picker(selection: $model.diabetesType) {
                    ForEach(DiabetesType.allCases, id: \.self) { type in
                        Text(type.localizedName).tag(type)
                    }
                } label: {
                    Text("profile.diabetesType", bundle: .module)
                }
            } footer: {
                Text("profile.private.footer", bundle: .module)
            }

            Section {
                measureField("profile.height", text: $model.heightText, unit: "profile.unit.cm")
                measureField("profile.weight", text: $model.weightText, unit: "profile.unit.kg")
                LabeledContent {
                    Text(verbatim: model.bodyMassIndex.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—")
                        .monospacedDigit()
                } label: {
                    Text("profile.bmi", bundle: .module)
                }
                .accessibilityElement(children: .combine)
            } header: {
                Text("profile.body", bundle: .module)
            } footer: {
                Text("profile.bmi.footer", bundle: .module)
            }

            medicinesSection

            RoutineSections(model: model)

            if let error = model.saveError ?? model.validationError {
                Section {
                    Label {
                        Text(error.localizedMessage)
                    } icon: {
                        Image(systemName: "exclamationmark.circle")
                    }
                }
            }
        }
        .navigationTitle(Text("profile.title", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if model.save() { onSaved() }
                } label: {
                    Text(saveTitleKey, bundle: .module)
                }
                .disabled(!model.canSave)
            }
        }
    }

    private func measureField(_ label: LocalizedStringKey, text: Binding<String>, unit: LocalizedStringKey) -> some View {
        LabeledContent {
            HStack(spacing: 4) {
                TextField(text: text, prompt: Text("profile.optional", bundle: .module)) {
                    Text(label, bundle: .module)
                }
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                Text(unit, bundle: .module)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        } label: {
            Text(label, bundle: .module)
        }
    }

    @ViewBuilder
    private var medicinesSection: some View {
        ForEach($model.medicines) { $medicine in
            Section {
                TextField(text: $medicine.name, prompt: Text("profile.medicine.name.prompt", bundle: .module)) {
                    Text("profile.medicine.name", bundle: .module)
                }
                Picker(selection: $medicine.kind) {
                    ForEach(MedicineKind.allCases, id: \.self) { kind in
                        Text(kind.localizedName).tag(kind)
                    }
                } label: {
                    Text("profile.medicine.kind", bundle: .module)
                }
                TextField(text: $medicine.doseText, prompt: Text("profile.medicine.dose.prompt", bundle: .module)) {
                    Text("profile.medicine.dose", bundle: .module)
                }
                ForEach(Array(medicine.minutes.enumerated()), id: \.offset) { index, minute in
                    HStack {
                        DatePicker(
                            selection: Binding(
                                get: { MinuteOfDayFormat.date(for: minute) },
                                set: { model.setTime(MinuteOfDayFormat.minute(of: $0), at: index, forMedicine: medicine.id) }
                            ),
                            displayedComponents: .hourAndMinute
                        ) {
                            Text("profile.medicine.time \(index + 1)", bundle: .module)
                        }
                        Button(role: .destructive) {
                            model.removeTime(at: index, forMedicine: medicine.id)
                        } label: {
                            Label {
                                Text("profile.medicine.time.remove", bundle: .module)
                            } icon: {
                                Image(systemName: "minus.circle")
                            }
                            .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button {
                    model.addTime(toMedicine: medicine.id)
                } label: {
                    Text("profile.medicine.time.add", bundle: .module)
                }
                Button(role: .destructive) {
                    model.removeMedicine(id: medicine.id)
                } label: {
                    Text("profile.medicine.remove", bundle: .module)
                }
            } header: {
                Text(verbatim: medicine.name.isEmpty ? medicine.kind.localizedName : medicine.name)
            }
        }
        Section {
            Button {
                model.addMedicine()
            } label: {
                Label {
                    Text("profile.medicine.add", bundle: .module)
                } icon: {
                    Image(systemName: "plus")
                }
            }
        } header: {
            Text("profile.medicines", bundle: .module)
        } footer: {
            Text("profile.medicines.footer", bundle: .module)
        }
    }
}

/// Wake, meals, snacks and bed times.
private struct RoutineSections: View {
    @Bindable var model: ProfileEditorModel

    var body: some View {
        Section {
            timeRow("profile.routine.wake", minute: $model.routine.wakeMinute)
            mealRow(.breakfast, minute: $model.routine.schedule.breakfastMinute)
            mealRow(.lunch, minute: $model.routine.schedule.lunchMinute)
            mealRow(.dinner, minute: $model.routine.schedule.dinnerMinute)
            ForEach(Array(model.routine.snackMinutes.enumerated()), id: \.offset) { index, minute in
                HStack {
                    DatePicker(
                        selection: Binding(
                            get: { MinuteOfDayFormat.date(for: minute) },
                            set: { model.setSnack(MinuteOfDayFormat.minute(of: $0), at: index) }
                        ),
                        displayedComponents: .hourAndMinute
                    ) {
                        Text("profile.routine.snack \(index + 1)", bundle: .module)
                    }
                    Button(role: .destructive) {
                        model.removeSnack(at: index)
                    } label: {
                        Label {
                            Text("profile.routine.snack.remove", bundle: .module)
                        } icon: {
                            Image(systemName: "minus.circle")
                        }
                        .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                }
            }
            if model.routine.snackMinutes.count < DayRoutine.maximumSnacks {
                Button {
                    model.addSnack()
                } label: {
                    Text("profile.routine.snack.add", bundle: .module)
                }
            }
            timeRow("profile.routine.bed", minute: $model.routine.schedule.bedtimeMinute)
        } header: {
            Text("profile.routine", bundle: .module)
        } footer: {
            Text("profile.routine.footer \(model.routine.mealsPerDay)", bundle: .module)
        }
    }

    private func timeRow(_ label: LocalizedStringKey, minute: Binding<Int>) -> some View {
        DatePicker(
            selection: Binding(
                get: { MinuteOfDayFormat.date(for: minute.wrappedValue) },
                set: { minute.wrappedValue = MinuteOfDayFormat.minute(of: $0) }
            ),
            displayedComponents: .hourAndMinute
        ) {
            Text(label, bundle: .module)
        }
    }

    @ViewBuilder
    private func mealRow(_ slot: MealSlot, minute: Binding<Int>) -> some View {
        let eaten = !model.routine.skippedMeals.contains(slot)
        Toggle(isOn: Binding(get: { eaten }, set: { model.setMainMeal(slot, eaten: $0) })) {
            Text(slot.localizedName)
        }
        if eaten {
            DatePicker(
                selection: Binding(
                    get: { MinuteOfDayFormat.date(for: minute.wrappedValue) },
                    set: { minute.wrappedValue = MinuteOfDayFormat.minute(of: $0) }
                ),
                displayedComponents: .hourAndMinute
            ) {
                Text("profile.routine.time", bundle: .module)
            }
            .padding(.leading)
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    NavigationStack {
        ProfileView(model: ProfileEditorModel(profileStore: dependencies.profileStore, preferences: dependencies.preferences))
    }
}

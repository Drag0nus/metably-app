import MetablyDomain
import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: UserPreferencesStore
    let logModel: GlucoseLogModel

    /// Hides the tab view's "Record reading" accessory while this screen is shown.
    var recordAccessoryHidden: Binding<Bool> = .constant(false)

    var body: some View {
        Form {
            Section {
                Picker(selection: $preferences.displayGlucoseUnit) {
                    ForEach(GlucoseUnit.allCases, id: \.self) { unit in
                        Text(verbatim: unit.symbol).tag(unit)
                    }
                } label: {
                    Text("settings.glucoseUnit", bundle: .module)
                }

                Picker(selection: $preferences.carbsPerBreadUnit) {
                    Text("settings.breadUnit.10", bundle: .module).tag(10.0)
                    Text("settings.breadUnit.12", bundle: .module).tag(12.0)
                } label: {
                    Text("settings.breadUnit", bundle: .module)
                }
            } header: {
                Text("settings.units", bundle: .module)
            }

            GlucoseTargetsSection(preferences: preferences)

            NutritionGoalsSection(preferences: preferences)

            Section {
                Toggle(isOn: $preferences.usesInsulin) {
                    Text("settings.usesInsulin", bundle: .module)
                }
                Toggle(isOn: $preferences.nightCheckEnabled) {
                    Text("settings.nightCheck", bundle: .module)
                }
            } header: {
                Text("settings.modules", bundle: .module)
            }

            #if DEBUG
            Section {
                Button {
                    logModel.loadSyntheticData()
                } label: {
                    Text("settings.debug.loadSyntheticAll", bundle: .module)
                }
            } header: {
                Text("settings.debug", bundle: .module)
            } footer: {
                Text("settings.debug.footer", bundle: .module)
            }
            #endif

            AboutSection(version: .current)

            Section {
                Text("settings.disclaimer", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("tab.settings", bundle: .module))
        #if os(iOS)
        // A pushed secondary screen: hide the tab bar, like `hidesBottomBarWhenPushed` in UIKit.
        // The "Record reading" accessory belongs to the TabView, not to this screen, so hiding
        // the tab bar leaves it on screen; the TabView hides it while this flag is set.
        .toolbarVisibility(.hidden, for: .tabBar)
        #endif
        .onAppear { recordAccessoryHidden.wrappedValue = true }
        .onDisappear { recordAccessoryHidden.wrappedValue = false }
    }
}

/// The user's own targets, edited in the display unit and stored in mmol/L.
private struct GlucoseTargetsSection: View {
    @Bindable var preferences: UserPreferencesStore

    private var unit: GlucoseUnit { preferences.displayGlucoseUnit }
    private var step: Double { unit == .millimolesPerLiter ? 0.1 : 1 }

    var body: some View {
        Section {
            stepper("settings.targets.preMealLower", keyPath: \.preMealLowerMmolL)
            stepper("settings.targets.preMealUpper", keyPath: \.preMealUpperMmolL)
            stepper("settings.targets.postMealUpper", keyPath: \.postMealUpperMmolL)
            if preferences.glucoseTargets != .adaDefaults {
                Button {
                    preferences.glucoseTargets = .adaDefaults
                } label: {
                    Text("settings.targets.reset", bundle: .module)
                }
            }
        } header: {
            Text("settings.targets", bundle: .module)
        } footer: {
            Text("settings.targets.footer", bundle: .module)
        }
    }

    /// A stepper in the display unit over a bound mmol/L field. A step that would make the
    /// targets inconsistent (for example lower above upper) is ignored.
    private func stepper(
        _ titleKey: LocalizedStringKey,
        keyPath: WritableKeyPath<GlucoseTargets, Double>
    ) -> some View {
        let mmolRange = GlucoseTargets.editableRangeMmolL
        let value = Binding<Double>(
            get: { GlucoseConcentration(millimolesPerLiter: preferences.glucoseTargets[keyPath: keyPath]).roundedValue(in: unit) },
            set: { newValue in
                var targets = preferences.glucoseTargets
                targets[keyPath: keyPath] = GlucoseConcentration(value: newValue, unit: unit).millimolesPerLiter
                if targets.isValid { preferences.glucoseTargets = targets }
            }
        )
        let lower = GlucoseConcentration(millimolesPerLiter: mmolRange.lowerBound).roundedValue(in: unit)
        let upper = GlucoseConcentration(millimolesPerLiter: mmolRange.upperBound).roundedValue(in: unit)
        let displayed = GlucoseConcentration(millimolesPerLiter: preferences.glucoseTargets[keyPath: keyPath])
            .formattedValue(in: unit)
        return Stepper(value: value, in: lower...upper, step: step) {
            HStack {
                Text(titleKey, bundle: .module)
                Spacer()
                Text(verbatim: "\(displayed) \(unit.symbol)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityValue(Text(verbatim: "\(displayed) \(unit.symbol)"))
    }
}

/// Daily nutrient goals, each off until the user sets one: the app does not invent dietary targets.
private struct NutritionGoalsSection: View {
    @Bindable var preferences: UserPreferencesStore

    /// A first value when the goal is switched on; the user adjusts it to their own plan.
    private static let initialGoalGrams: Double = 150

    var body: some View {
        Section {
            Toggle(isOn: isOn) {
                Text("settings.goals.carbs", bundle: .module)
            }
            if let goal = preferences.dailyCarbohydrateGoalGrams {
                Stepper(value: goalBinding, in: UserPreferencesStore.carbohydrateGoalRange, step: 5) {
                    HStack {
                        Text("settings.goals.carbs.value", bundle: .module)
                        Spacer()
                        Text(verbatim: "\(NutritionFormat.grams(goal)) \(NutritionFormat.gramsUnit)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityValue(Text(verbatim: "\(NutritionFormat.grams(goal)) \(NutritionFormat.gramsUnit)"))
            }
            ForEach(Nutrient.allCases) { nutrient in
                NutrientGoalRows(preferences: preferences, nutrient: nutrient)
            }
        } header: {
            Text("settings.goals", bundle: .module)
        } footer: {
            Text("settings.goals.footer", bundle: .module)
        }
    }

    private var isOn: Binding<Bool> {
        Binding(
            get: { preferences.dailyCarbohydrateGoalGrams != nil },
            set: { preferences.dailyCarbohydrateGoalGrams = $0 ? Self.initialGoalGrams : nil }
        )
    }

    private var goalBinding: Binding<Double> {
        Binding(
            get: { preferences.dailyCarbohydrateGoalGrams ?? Self.initialGoalGrams },
            set: { preferences.dailyCarbohydrateGoalGrams = $0 }
        )
    }
}

/// Toggle and stepper for one nutrient goal. Switching it on starts from a round number that
/// the user then sets to their own plan.
private struct NutrientGoalRows: View {
    @Bindable var preferences: UserPreferencesStore
    let nutrient: Nutrient

    var body: some View {
        Toggle(isOn: Binding(
            get: { preferences.goal(for: nutrient) != nil },
            set: { preferences.setGoal($0 ? initialGoal : nil, for: nutrient) }
        )) {
            Text("settings.goals.nutrient \(nutrient.localizedName)", bundle: .module)
        }
        if let goal = preferences.goal(for: nutrient) {
            Stepper(
                value: Binding(get: { goal }, set: { preferences.setGoal($0, for: nutrient) }),
                in: nutrient.goalRange,
                step: nutrient.goalStep
            ) {
                HStack {
                    Text("settings.goals.carbs.value", bundle: .module)
                    Spacer()
                    Text(verbatim: "\(NutritionFormat.grams(goal)) \(nutrient.unitSymbol)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityValue(Text(verbatim: "\(NutritionFormat.grams(goal)) \(nutrient.unitSymbol)"))
        }
    }

    private var initialGoal: Double {
        switch nutrient {
        case .protein: 60
        case .fat: 60
        case .fiber: 25
        case .energy: 2000
        }
    }
}

/// Version, build and build time, so a tester always knows which build is installed.
private struct AboutSection: View {
    let version: AppVersion

    var body: some View {
        Section {
            LabeledContent {
                Text(verbatim: version.versionAndBuild)
                    .monospacedDigit()
                    .textSelection(.enabled)
            } label: {
                Text("settings.about.version", bundle: .module)
            }
            if let builtAt = version.builtAt {
                LabeledContent {
                    Text(builtAt.formatted(date: .abbreviated, time: .shortened))
                        .monospacedDigit()
                } label: {
                    Text("settings.about.built", bundle: .module)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("settings.about.foodData", bundle: .module)
                Text("settings.about.foodData.detail", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let url = URL(string: "https://fdc.nal.usda.gov/") {
                    Link(destination: url) {
                        Text(verbatim: "fdc.nal.usda.gov")
                            .font(.footnote)
                    }
                }
            }
        } header: {
            Text("settings.about", bundle: .module)
        }
    }
}

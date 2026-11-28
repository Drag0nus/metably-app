import MetablyDomain
import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: UserPreferencesStore
    let logModel: GlucoseLogModel

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
                    Text("settings.debug.loadSynthetic", bundle: .module)
                }
            } header: {
                Text("settings.debug", bundle: .module)
            } footer: {
                Text("settings.debug.footer", bundle: .module)
            }
            #endif

            Section {
                Text("settings.disclaimer", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("tab.settings", bundle: .module))
        #if os(iOS)
        // A pushed secondary screen: hide the tab bar and its "Record reading" accessory,
        // like `hidesBottomBarWhenPushed` in UIKit. They return on the tab's root screen.
        .toolbarVisibility(.hidden, for: .tabBar)
        #endif
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

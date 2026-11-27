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
    }
}

import MetablyDomain
import SwiftUI

/// Quick manual entry of a fingerstick glucose reading.
struct GlucoseEntryView: View {
    @Bindable var model: GlucoseEntryModel
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isValueFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        TextField(text: $model.valueText, prompt: Text(verbatim: "0,0")) {
                            Text("entry.value", bundle: .module)
                        }
                        .font(.system(.largeTitle, design: .rounded).monospacedDigit())
                        .focused($isValueFocused)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif

                        Picker(selection: $model.unit) {
                            ForEach(GlucoseUnit.allCases, id: \.self) { unit in
                                Text(verbatim: unit.symbol).tag(unit)
                            }
                        } label: {
                            Text("entry.unit", bundle: .module)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                } footer: {
                    if let error = model.visibleValidationError {
                        Label {
                            Text(error.localizedMessage)
                        } icon: {
                            Image(systemName: "exclamationmark.circle")
                        }
                    }
                }

                Section {
                    Picker(selection: $model.context) {
                        ForEach(GlucoseMeasurementContext.allCases, id: \.self) { context in
                            Text(context.localizedName).tag(context)
                        }
                    } label: {
                        Text("entry.context", bundle: .module)
                    }

                    DatePicker(selection: $model.measuredAt, in: ...model.latestAllowedDate) {
                        Text("entry.time", bundle: .module)
                    }
                }

                Section {
                    TextField(
                        text: $model.note,
                        prompt: Text("entry.note.prompt", bundle: .module),
                        axis: .vertical
                    ) {
                        Text("entry.note", bundle: .module)
                    }
                    .lineLimit(1...4)
                }

                if let saveError = model.saveError {
                    Section {
                        Label {
                            Text(Self.message(for: saveError))
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                    }
                }
            }
            .navigationTitle(Text("entry.title", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("common.cancel", bundle: .module)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if model.save() != nil {
                            onSaved()
                            dismiss()
                        }
                    } label: {
                        Text("common.save", bundle: .module)
                    }
                    .disabled(!model.canSave)
                }
            }
            .onAppear { isValueFocused = true }
        }
    }

    private static func message(for error: GlucoseEntrySaveError) -> String {
        switch error {
        case .invalid(let entryError): entryError.localizedMessage
        case .duplicate: String(localized: "entry.error.duplicate", bundle: .module)
        case .storage: String(localized: "entry.error.storage", bundle: .module)
        }
    }
}

#Preview {
    GlucoseEntryView(
        model: GlucoseEntryModel(repository: InMemoryGlucoseRepository(), unit: .millimolesPerLiter),
        onSaved: {}
    )
}

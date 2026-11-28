import MetablyDomain
import SwiftUI

/// Quick manual entry of a fingerstick glucose reading, or editing a saved one.
///
/// A new entry opens with the keypad up and the diary slot suggested from the time of day,
/// so a typical entry is: type the value, tap Save. Editing shows the source and a delete action.
struct GlucoseEntryView: View {
    @Bindable var model: GlucoseEntryModel
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isValueFocused: Bool
    @State private var confirmsDelete = false

    var body: some View {
        NavigationStack {
            Form {
                valueSection

                if model.showsLowGlucoseGuidance && !model.isEditing {
                    LowGlucoseGuidanceSection(model: model)
                }

                Section {
                    SlotChips(slots: model.availableSlots, selection: $model.slot)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } header: {
                    Text("entry.context", bundle: .module)
                } footer: {
                    Text("entry.context.footer", bundle: .module)
                }

                Section {
                    ActivityLevelPicker(selection: $model.activityLevel)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } header: {
                    Text("entry.activity", bundle: .module)
                } footer: {
                    Text("entry.activity.footer", bundle: .module)
                }

                Section {
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

                if let original = model.editing {
                    RecordInfoSection(reading: original)
                    Section {
                        Button(role: .destructive) {
                            confirmsDelete = true
                        } label: {
                            Text("entry.delete", bundle: .module)
                        }
                    }
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
            .navigationTitle(Text(model.isEditing ? "entry.edit.title" : "entry.title", bundle: .module))
            .confirmationDialog(
                Text("entry.delete.confirm", bundle: .module),
                isPresented: $confirmsDelete,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    if model.deleteEditedReading() {
                        onSaved()
                        dismiss()
                    }
                } label: {
                    Text("entry.delete", bundle: .module)
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
                        finish(model.save())
                    } label: {
                        Text("common.save", bundle: .module)
                    }
                    .disabled(!model.canSave)
                }
            }
            .alert(
                Text("entry.duplicate.title", bundle: .module),
                isPresented: duplicateAlertBinding,
                presenting: model.likelyDuplicate
            ) { _ in
                Button {
                    finish(model.saveDespiteDuplicate())
                } label: {
                    Text("entry.duplicate.saveAnother", bundle: .module)
                }
                Button(role: .cancel) {
                    model.dismissDuplicateWarning()
                } label: {
                    Text("common.cancel", bundle: .module)
                }
            } message: { existing in
                Text("entry.duplicate.message \(Self.time(of: existing))", bundle: .module)
            }
            .onAppear { isValueFocused = !model.isEditing }
        }
    }

    private var valueSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                TextField(text: $model.valueText, prompt: Text(verbatim: "0,0")) {
                    Text("entry.value", bundle: .module)
                }
                .font(.system(.largeTitle, design: .rounded).monospacedDigit().weight(.semibold))
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
            Picker(selection: $model.meterDisplay) {
                Text("entry.meter.value", bundle: .module).tag(MeterDisplay.value)
                Text(verbatim: "LO").tag(MeterDisplay.low)
                Text(verbatim: "HI").tag(MeterDisplay.high)
            } label: {
                Text("entry.meter", bundle: .module)
            }
            .pickerStyle(.segmented)
            .accessibilityHint(Text("entry.meter.hint", bundle: .module))
            if let status = model.previewStatus {
                GlucoseStatusBadge(status: status)
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
    }

    private var duplicateAlertBinding: Binding<Bool> {
        Binding(
            get: { model.likelyDuplicate != nil },
            set: { if !$0 { model.dismissDuplicateWarning() } }
        )
    }

    private func finish(_ saved: GlucoseReading?) {
        guard saved != nil else { return }
        onSaved()
        dismiss()
    }

    private static func time(of reading: GlucoseReading) -> String {
        reading.measuredAt.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: reading.timeZone))
    }

    private static func message(for error: GlucoseEntrySaveError) -> String {
        switch error {
        case .invalid(let entryError): entryError.localizedMessage
        case .duplicate: String(localized: "entry.error.duplicate", bundle: .module)
        case .storage: String(localized: "entry.error.storage", bundle: .module)
        }
    }
}

/// Where a saved reading came from and when it was recorded. Facts only.
private struct RecordInfoSection: View {
    let reading: GlucoseReading

    var body: some View {
        Section {
            LabeledContent {
                Text(reading.provenance.source.localizedName)
            } label: {
                Text("entry.info.source", bundle: .module)
            }
            LabeledContent {
                Text(reading.createdAt.formatted(date: .abbreviated, time: .shortened))
            } label: {
                Text("entry.info.created", bundle: .module)
            }
            if reading.version > 1 {
                LabeledContent {
                    Text(reading.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                } label: {
                    Text("entry.info.modified", bundle: .module)
                }
            }
        } footer: {
            Text("entry.info.footer", bundle: .module)
        }
    }
}

/// Shown while the typed value is below 3.9 mmol/L.
///
/// The doctor's plan always comes first. The 15 g / 15 min rule is general guidance with its
/// source, not a treatment recommendation, and the app never suggests a medication or dose.
private struct LowGlucoseGuidanceSection: View {
    let model: GlucoseEntryModel

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("low.title", bundle: .module)
                        .font(.headline)
                } icon: {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(GlucoseTargetStatus.below.tint)
                }
                Text("low.plan", bundle: .module)
                    .font(.subheadline.weight(.semibold))
                Text("low.rule", bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            switch model.recheckReminder {
            case .notScheduled:
                Button {
                    model.scheduleRecheckReminder()
                } label: {
                    Label {
                        Text("low.remind", bundle: .module)
                    } icon: {
                        Image(systemName: "bell")
                    }
                }
            case .scheduled(let date):
                Label {
                    Text("low.reminded \(date.formatted(date: .omitted, time: .shortened))", bundle: .module)
                } icon: {
                    Image(systemName: "bell.badge")
                }
                .foregroundStyle(.secondary)
            case .unavailable:
                Label {
                    Text("low.reminderUnavailable", bundle: .module)
                } icon: {
                    Image(systemName: "bell.slash")
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

/// Diary slot choice as wrapping chips (the paper diary's columns).
struct SlotChips: View {
    let slots: [DiarySlot]
    @Binding var selection: DiarySlot

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(slots) { slot in
                let isSelected = slot == selection
                Button {
                    selection = slot
                } label: {
                    Text(slot.localizedName)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .padding(.horizontal, 8)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background(
                            isSelected ? Color.accentColor : Color.secondary.opacity(0.12),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

/// The paper diary's 1–5 activity scale as five equal buttons. Tapping the selected level
/// clears it, because the level is optional.
struct ActivityLevelPicker: View {
    @Binding var selection: ActivityLevel?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ActivityLevel.all) { level in
                let isSelected = level == selection
                Button {
                    selection = isSelected ? nil : level
                } label: {
                    Text(level.rawValue, format: .number)
                        .font(.headline.monospacedDigit())
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background(
                            isSelected ? Color.accentColor : Color.secondary.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("entry.activity.level \(level.rawValue)", bundle: .module))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

#Preview("Entry") {
    GlucoseEntryView(
        model: GlucoseEntryModel(repository: InMemoryGlucoseRepository(), unit: .millimolesPerLiter),
        onSaved: {}
    )
}

#Preview("Low value") {
    let model = GlucoseEntryModel(repository: InMemoryGlucoseRepository(), unit: .millimolesPerLiter)
    model.valueText = "3,4"
    return GlucoseEntryView(model: model, onSaved: {})
}

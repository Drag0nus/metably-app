import MetablyDomain
import SwiftUI

/// Recording a meal (eaten or planned) with its foods, or editing a saved one.
///
/// Carbohydrate grams are what the user types; bread units (ХО) are shown next to the total,
/// derived from the factor in Settings. Nothing here suggests what or how much to eat.
///
/// SwiftUI note: `ForEach($model.items)` hands each row a binding to its element, so a text
/// field edits the draft in the model directly, and `.onDelete` adds swipe-to-delete.
struct MealEntryView: View {
    @Bindable var model: MealEntryModel
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $model.status) {
                        Text("meal.status.eaten", bundle: .module).tag(MealStatus.eaten)
                        Text("meal.status.planned", bundle: .module).tag(MealStatus.planned)
                    } label: {
                        Text("meal.status", bundle: .module)
                    }
                    .pickerStyle(.segmented)

                    Picker(selection: $model.slot) {
                        ForEach(MealSlot.allCases, id: \.self) { slot in
                            Text(slot.localizedName).tag(slot)
                        }
                    } label: {
                        Text("meal.slot", bundle: .module)
                    }

                    timePicker
                }

                Section {
                    ForEach($model.items) { $item in
                        MealItemRow(item: $item, trackedNutrients: model.trackedNutrients)
                    }
                    .onDelete { model.removeItems(at: $0) }

                    Button {
                        model.addItem()
                    } label: {
                        Label {
                            Text("meal.addItem", bundle: .module)
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                } header: {
                    Text("meal.items", bundle: .module)
                } footer: {
                    if let error = visibleError {
                        Label {
                            Text(error.localizedMessage)
                        } icon: {
                            Image(systemName: "exclamationmark.circle")
                        }
                    } else {
                        Text("meal.items.footer", bundle: .module)
                    }
                }

                Section {
                    LabeledContent {
                        Text(verbatim: totalText)
                            .font(.headline.monospacedDigit())
                    } label: {
                        Text("meal.total", bundle: .module)
                    }
                    .accessibilityElement(children: .combine)

                    PortionPicker(selection: $model.portionSize)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } footer: {
                    Text("meal.portion.footer", bundle: .module)
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

                if model.isEditing {
                    Section {
                        Button(role: .destructive) {
                            confirmsDelete = true
                        } label: {
                            Text("meal.delete", bundle: .module)
                        }
                    }
                }

                if let saveError = model.saveError, saveError == .storage {
                    Section {
                        Label {
                            Text(saveError.localizedMessage)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                    }
                }
            }
            .navigationTitle(Text(model.isEditing ? "meal.edit.title" : "meal.new.title", bundle: .module))
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
            .confirmationDialog(
                Text("meal.delete.confirm", bundle: .module),
                isPresented: $confirmsDelete,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    if model.delete() {
                        onSaved()
                        dismiss()
                    }
                } label: {
                    Text("meal.delete", bundle: .module)
                }
            }
        }
    }

    @ViewBuilder
    private var timePicker: some View {
        if let latest = model.latestAllowedDate {
            DatePicker(selection: $model.startedAt, in: ...latest) {
                Text("meal.time", bundle: .module)
            }
        } else {
            DatePicker(selection: $model.startedAt) {
                Text("meal.time", bundle: .module)
            }
        }
    }

    /// Validation is shown only once the user has typed something, not on an empty sheet.
    private var visibleError: MealEntryModel.SaveError? {
        guard model.items.contains(where: { !$0.isBlank }) else { return nil }
        return model.validationError
    }

    private var totalText: String {
        let grams = NutritionFormat.grams(model.totalCarbohydrateGrams)
        let units = NutritionFormat.breadUnits(model.totalBreadUnits)
        return String(localized: "meal.carbs.withBreadUnits \(grams) \(units)", bundle: .module)
    }
}

/// One food: name on its own line, then portion and carbohydrate grams side by side.
private struct MealItemRow: View {
    @Binding var item: MealEntryModel.ItemDraft
    let trackedNutrients: [Nutrient]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(text: $item.name, prompt: Text("meal.item.name.prompt", bundle: .module)) {
                Text("meal.item.name", bundle: .module)
            }
            .font(.body.weight(.medium))

            HStack(spacing: 12) {
                gramsField(text: $item.amountText, label: "meal.item.amount", prompt: "meal.item.amount.prompt")
                gramsField(text: $item.carbsText, label: "meal.item.carbs", prompt: "meal.item.carbs.prompt")
            }
            if !trackedNutrients.isEmpty {
                // Two per row so the fields stay wide enough at large text sizes.
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 8) {
                    ForEach(trackedNutrients) { nutrient in
                        NumberField(
                            text: nutrientBinding(nutrient),
                            label: Text(nutrient.localizedName),
                            prompt: Text("meal.item.optional", bundle: .module),
                            unit: nutrient.unitSymbol
                        )
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func gramsField(text: Binding<String>, label: LocalizedStringKey, prompt: LocalizedStringKey) -> some View {
        NumberField(
            text: text,
            label: Text(label, bundle: .module),
            prompt: Text(prompt, bundle: .module),
            unit: NutritionFormat.gramsUnit
        )
    }

    private func nutrientBinding(_ nutrient: Nutrient) -> Binding<String> {
        Binding(
            get: { item.nutrientTexts[nutrient] ?? "" },
            set: { item.nutrientTexts[nutrient] = $0 }
        )
    }
}

/// A small labelled decimal field with its unit, e.g. "Carbohydrates [ 30 ] g".
private struct NumberField: View {
    @Binding var text: String
    let label: Text
    let prompt: Text
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            label
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField(text: $text, prompt: prompt) {
                    label
                }
                .monospacedDigit()
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                Text(verbatim: unit)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// М / С / В as three equal buttons. Tapping the selected size clears it: it is optional.
struct PortionPicker: View {
    @Binding var selection: PortionSize?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("meal.portion", bundle: .module)
                .font(.subheadline)
            HStack(spacing: 8) {
                ForEach(PortionSize.allCases, id: \.self) { size in
                    let isSelected = size == selection
                    Button {
                        selection = isSelected ? nil : size
                    } label: {
                        Text(size.shortName)
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .background(
                                isSelected ? Color.accentColor : Color.secondary.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(size.localizedName))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}

#Preview("New meal") {
    MealEntryView(model: MealEntryModel(repository: InMemoryMealRepository()), onSaved: {})
}

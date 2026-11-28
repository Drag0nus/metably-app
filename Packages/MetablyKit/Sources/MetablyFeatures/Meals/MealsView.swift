import MetablyDomain
import SwiftUI

/// "Їжа": one diary day of meals. Eaten meals are facts; planned meals are shown apart and
/// never count towards what was eaten until the user marks them.
struct MealsView: View {
    @Bindable var model: MealsModel

    @State private var entryModel: MealEntryModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DayHeader(model: model)

                CarbohydrateCard(
                    eatenGrams: model.eatenCarbohydrateGrams,
                    plannedGrams: model.plannedCarbohydrateGrams,
                    goalGrams: model.carbohydrateGoalGrams,
                    breadUnits: model.breadUnits
                )

                if !model.nutrientProgress.isEmpty {
                    NutrientsCard(rows: model.nutrientProgress.map {
                        NutrientsCard.Row(nutrient: $0.nutrient, total: $0.total, goal: $0.goal)
                    })
                }

                let sugars = model.sugarBreakdown
                if sugars.totalSugars.foodsWithValue > 0 || sugars.hasBreakdown {
                    SugarsCard(breakdown: sugars)
                }

                if model.eaten.isEmpty && model.planned.isEmpty {
                    EmptyMealsCard { entryModel = model.makeEntryModel(status: .eaten) }
                }

                if !model.eaten.isEmpty {
                    MealListCard(titleKey: "meals.eaten", meals: model.eaten, breadUnits: model.breadUnits) {
                        entryModel = model.makeEntryModel(editing: $0)
                    }
                }

                if !model.planned.isEmpty {
                    MealListCard(
                        titleKey: "meals.planned",
                        meals: model.planned,
                        breadUnits: model.breadUnits,
                        onMarkEaten: { model.markEaten($0) },
                        onSelect: { entryModel = model.makeEntryModel(editing: $0) }
                    )
                }

                if model.loadFailed {
                    Label {
                        Text("meals.loadFailed", bundle: .module)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        #if os(iOS)
        .background(Color(.systemGroupedBackground))
        #endif
        .navigationTitle(Text("tab.meals", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        entryModel = model.makeEntryModel(status: .eaten)
                    } label: {
                        Label {
                            Text("meals.add.eaten", bundle: .module)
                        } icon: {
                            Image(systemName: "fork.knife")
                        }
                    }
                    Button {
                        entryModel = model.makeEntryModel(status: .planned)
                    } label: {
                        Label {
                            Text("meals.add.planned", bundle: .module)
                        } icon: {
                            Image(systemName: "calendar.badge.clock")
                        }
                    }
                } label: {
                    Label {
                        Text("meals.add", bundle: .module)
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear { model.reload() }
        .sheet(item: $entryModel) { entry in
            MealEntryView(model: entry) { model.reload() }
        }
    }
}

/// Previous / next day with the date in the middle; "Today" returns from another day.
private struct DayHeader: View {
    let model: MealsModel

    var body: some View {
        HStack {
            Button {
                model.showDay(offset: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Text("meals.day.previous", bundle: .module))

            Spacer()
            VStack(spacing: 2) {
                Text(Self.title(model.day))
                    .font(.headline)
                if !model.isToday {
                    Button {
                        model.showToday()
                    } label: {
                        Text("meals.day.today", bundle: .module)
                            .font(.subheadline)
                    }
                }
            }
            Spacer()

            Button {
                model.showDay(offset: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(model.day >= model.today.adding(days: 7))
            .accessibilityLabel(Text("meals.day.next", bundle: .module))
        }
    }

    /// Diary days are calendar dates; format them without shifting through the device zone.
    static func title(_ day: LocalDay) -> String {
        guard let start = day.startInstant(in: .gmt) else { return day.isoString }
        return start.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.wide).day().month(.wide))
    }
}

/// Carbohydrates eaten today, against the user's own goal when they set one.
struct CarbohydrateCard: View {
    let eatenGrams: Double
    let plannedGrams: Double
    let goalGrams: Double?
    let breadUnits: BreadUnitConverter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("meals.carbs", bundle: .module)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: NutritionFormat.grams(eatenGrams))
                    .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                if let goalGrams {
                    Text(verbatim: "/ \(NutritionFormat.grams(goalGrams)) \(NutritionFormat.gramsUnit)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                } else {
                    Text(verbatim: NutritionFormat.gramsUnit)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text("meals.breadUnits \(NutritionFormat.breadUnits(breadUnits.breadUnits(forCarbohydrateGrams: eatenGrams)))", bundle: .module)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let goalGrams, goalGrams > 0 {
                // A neutral bar: the goal is the user's own plan, not a limit the app enforces.
                ProgressView(value: min(eatenGrams, goalGrams), total: goalGrams)
                    .tint(Color.accentColor)
                    .accessibilityHidden(true)
            } else {
                Text("meals.goal.none", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if plannedGrams > 0 {
                Text("meals.carbs.planned \(NutritionFormat.grams(plannedGrams))", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

/// Other nutrients against the user's own goals. Foods without a value are counted, so a
/// low total is not mistaken for a low intake.
struct NutrientsCard: View {
    struct Row: Identifiable {
        let nutrient: Nutrient
        let total: NutrientTotal
        let goal: Double
        var id: Nutrient { nutrient }
    }

    let rows: [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("meals.nutrients", bundle: .module)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.nutrient.localizedName)
                        Spacer()
                        Text(verbatim: "\(NutritionFormat.grams(row.total.value)) / \(NutritionFormat.grams(row.goal)) \(row.nutrient.unitSymbol)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: min(row.total.value, row.goal), total: row.goal)
                        .tint(Color.accentColor)
                        .accessibilityHidden(true)
                    if row.total.foodsWithoutValue > 0 {
                        Text("meals.nutrients.missing \(row.total.foodsWithoutValue)", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }
}

/// Dietary sugars eaten today, by type. Grams of sugar in food, never blood glucose.
/// A sugar is listed only when at least one food knows it, and gaps are said out loud.
struct SugarsCard: View {
    let breakdown: DietarySugarBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("meals.sugars", bundle: .module)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("meals.sugars.subtitle", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if breakdown.totalSugars.foodsWithValue > 0 {
                row(name: Text("meals.sugars.total", bundle: .module), value: breakdown.totalSugars.value, bold: true)
                if breakdown.totalSugars.foodsWithoutValue > 0 {
                    missing(breakdown.totalSugars.foodsWithoutValue)
                }
            }
            if breakdown.hasBreakdown {
                Divider()
                ForEach(breakdown.sugars) { entry in
                    row(name: Text(verbatim: entry.sugar.localizedName), value: entry.total.value, bold: false)
                }
                if breakdown.foodsWithoutBreakdown > 0 {
                    missing(breakdown.foodsWithoutBreakdown)
                }
            }
        }
        .card()
    }

    private func row(name: Text, value: Double, bold: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            name
            Spacer()
            Text(verbatim: "\(NutritionFormat.tenths(value)) \(NutritionFormat.gramsUnit)")
                .monospacedDigit()
                .foregroundStyle(bold ? Color.primary : Color.secondary)
        }
        .font(bold ? .body.weight(.semibold) : .body)
        .accessibilityElement(children: .combine)
    }

    private func missing(_ count: Int) -> some View {
        Text("meals.sugars.missing \(count)", bundle: .module)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

private struct EmptyMealsCard: View {
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("meals.empty.title", bundle: .module)
                .font(.title3.weight(.semibold))
            Text("meals.empty.message", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: onAdd) {
                Label {
                    Text("meals.add.eaten", bundle: .module)
                } icon: {
                    Image(systemName: "fork.knife")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .card()
    }
}

/// A list of meals; planned meals get the one-tap "Eaten as planned" action.
private struct MealListCard: View {
    let titleKey: LocalizedStringKey
    let meals: [Meal]
    let breadUnits: BreadUnitConverter
    var onMarkEaten: ((Meal) -> Void)?
    var onSelect: (Meal) -> Void

    init(
        titleKey: LocalizedStringKey,
        meals: [Meal],
        breadUnits: BreadUnitConverter,
        onMarkEaten: ((Meal) -> Void)? = nil,
        onSelect: @escaping (Meal) -> Void
    ) {
        self.titleKey = titleKey
        self.meals = meals
        self.breadUnits = breadUnits
        self.onMarkEaten = onMarkEaten
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleKey, bundle: .module)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(meals) { meal in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        onSelect(meal)
                    } label: {
                        MealRowView(meal: meal, breadUnits: breadUnits)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("meals.row.hint", bundle: .module))

                    if let onMarkEaten {
                        Button {
                            onMarkEaten(meal)
                        } label: {
                            Label {
                                Text("meals.markEaten", bundle: .module)
                            } icon: {
                                Image(systemName: "checkmark.circle")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                if meal.id != meals.last?.id {
                    Divider()
                }
            }
        }
        .card()
    }
}

struct MealRowView: View {
    let meal: Meal
    let breadUnits: BreadUnitConverter

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: meal.slot.symbolName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(meal.slot.localizedName)
                        .font(.body.weight(.semibold))
                    Text(verbatim: time)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let portion = meal.portionSize {
                        Text(portion.shortName)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                            .accessibilityLabel(Text(portion.localizedName))
                    }
                }
                Text(meal.items.map(\.name).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: "\(NutritionFormat.grams(meal.totalCarbohydrateGrams)) \(NutritionFormat.gramsUnit)")
                    .font(.body.monospacedDigit().weight(.semibold))
                Text("meals.breadUnits \(NutritionFormat.breadUnits(breadUnits.breadUnits(forCarbohydrateGrams: meal.totalCarbohydrateGrams)))", bundle: .module)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var time: String {
        meal.startedAt.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: meal.timeZone))
    }
}

#Preview("Meals") {
    NavigationStack {
        MealsView(model: MealsModel(dependencies: AppDependencies.preview()))
    }
}

#Preview("No meals") {
    NavigationStack {
        MealsView(model: MealsModel(dependencies: AppDependencies.preview(days: 0)))
    }
}

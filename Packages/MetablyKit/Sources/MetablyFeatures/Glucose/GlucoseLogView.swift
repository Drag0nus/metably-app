import MetablyDomain
import SwiftUI

/// Journal: readings grouped by diary day, as a list (swipe to delete) or as the
/// paper-diary table.
struct GlucoseLogView: View {
    @Bindable var model: GlucoseLogModel
    let preferences: UserPreferencesStore

    @State private var entryModel: GlucoseEntryModel?

    var body: some View {
        content
            .safeAreaInset(edge: .top) {
                Picker(selection: $model.layout) {
                    Text("journal.layout.list", bundle: .module).tag(GlucoseLogModel.Layout.list)
                    Text("journal.layout.table", bundle: .module).tag(GlucoseLogModel.Layout.table)
                } label: {
                    Text("journal.layout", bundle: .module)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.regularMaterial)
            }
            .overlay {
                if model.sections.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("log.empty.title", bundle: .module)
                        } icon: {
                            Image(systemName: "drop")
                        }
                    } description: {
                        Text("log.empty.message", bundle: .module)
                    }
                }
            }
            .navigationTitle(Text("tab.journal", bundle: .module))
            #if !os(iOS)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        entryModel = model.makeEntryModel()
                    } label: {
                        Label {
                            Text("log.add", bundle: .module)
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            #endif
            .sheet(item: $entryModel) { entry in
                GlucoseEntryView(model: entry) { model.reload() }
            }
            .onAppear { model.reload() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.layout {
        case .list:
            listView
        case .table:
            DiaryTableView(
                rows: model.diaryRows,
                slots: model.tableSlots,
                displayUnit: preferences.displayGlucoseUnit,
                targets: preferences.glucoseTargets,
                onSelect: edit
            )
        }
    }

    private var listView: some View {
        List {
            ForEach(model.sections) { section in
                Section {
                    ForEach(section.readings) { reading in
                        Button {
                            edit(reading)
                        } label: {
                            GlucoseRowView(
                                reading: reading,
                                displayUnit: preferences.displayGlucoseUnit,
                                targets: preferences.glucoseTargets,
                                mealLinkText: model.mealLinkTexts[reading.id]
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("journal.row.hint", bundle: .module))
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            model.delete(id: section.readings[index].id)
                        }
                    }
                } header: {
                    Text(Self.title(for: section.day))
                }
            }
        }
    }

    private func edit(_ reading: GlucoseReading) {
        entryModel = model.makeEntryModel(editing: reading)
    }

    /// Diary days are calendar dates; format them without shifting through the device zone.
    private static func title(for day: LocalDay) -> String {
        guard let start = day.startInstant(in: .gmt) else { return day.isoString }
        return start.formatted(Date.FormatStyle(date: .complete, time: .omitted, timeZone: .gmt))
    }
}

struct GlucoseRowView: View {
    let reading: GlucoseReading
    let displayUnit: GlucoseUnit
    let targets: GlucoseTargets
    /// "2 h 5 min after lunch" when the user linked the reading to a meal.
    var mealLinkText: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(reading.diarySlot().localizedName)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(timeText)
                    if showsZoneBadge {
                        Text(verbatim: reading.timeZone.abbreviation(for: reading.measuredAt) ?? reading.timeZoneID)
                    }
                    if let activity = reading.activityLevel {
                        Label {
                            Text(activity.rawValue, format: .number)
                        } icon: {
                            Image(systemName: "figure.walk")
                        }
                        .labelStyle(.titleAndIcon)
                        .accessibilityLabel(Text("entry.activity.level \(activity.rawValue)", bundle: .module))
                    }
                    if reading.provenance.source == .synthetic {
                        Image(systemName: "testtube.2")
                            .accessibilityLabel(Text("log.synthetic", bundle: .module))
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if let mealLinkText {
                    Label {
                        Text(mealLinkText)
                    } icon: {
                        Image(systemName: "fork.knife")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                if let note = reading.note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            if let status {
                // Out-of-target values are bold with an arrow, never marked by colour alone.
                Image(systemName: status.symbolName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(status.tint)
                    .accessibilityLabel(Text(status.localizedName))
            }
            Text(reading.concentration.formattedValue(in: displayUnit))
                .font(.system(.title2, design: .rounded).monospacedDigit().weight(isOutside ? .bold : .medium))
            Text(verbatim: displayUnit.symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var status: GlucoseTargetStatus? { reading.targetStatus(using: targets) }
    private var isOutside: Bool { status == .below || status == .above }

    /// Local time where the reading was taken, so 07:30 stays 07:30 after travel.
    private var timeText: String {
        reading.measuredAt.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: reading.timeZone))
    }

    private var showsZoneBadge: Bool {
        reading.timeZoneID != TimeZone.current.identifier
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    NavigationStack {
        GlucoseLogView(model: GlucoseLogModel(dependencies: dependencies), preferences: dependencies.preferences)
    }
}

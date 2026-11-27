import MetablyDomain
import SwiftUI

/// Glucose diary: readings grouped by diary day, with quick add and swipe to delete.
struct GlucoseLogView: View {
    @Bindable var model: GlucoseLogModel
    let preferences: UserPreferencesStore

    @State private var entryModel: GlucoseEntryModel?

    var body: some View {
        List {
            ForEach(model.sections) { section in
                Section {
                    ForEach(section.readings) { reading in
                        GlucoseRowView(reading: reading, displayUnit: preferences.displayGlucoseUnit)
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
        .navigationTitle(Text("log.title", bundle: .module))
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
        .sheet(item: $entryModel) { entry in
            GlucoseEntryView(model: entry) { model.reload() }
        }
        .task { model.reload() }
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

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(reading.context.localizedName)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(timeText)
                    if showsZoneBadge {
                        Text(verbatim: reading.timeZone.abbreviation(for: reading.measuredAt) ?? reading.timeZoneID)
                    }
                    if reading.provenance.source == .synthetic {
                        Image(systemName: "testtube.2")
                            .accessibilityLabel(Text("log.synthetic", bundle: .module))
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if let note = reading.note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Text(reading.concentration.formattedValue(in: displayUnit))
                .font(.system(.title2, design: .rounded).monospacedDigit().weight(.semibold))
            Text(verbatim: displayUnit.symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

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

import MetablyDomain
import SwiftUI

/// "Сьогодні": the current diary day at a glance, in the order of the paper diary.
struct TodayView: View {
    @Bindable var model: TodayModel
    let preferences: UserPreferencesStore
    let logModel: GlucoseLogModel
    /// Opens the glucose entry sheet (owned by the tab view, shared with the accessory button).
    var onRecordReading: () -> Void

    @State private var editModel: GlucoseEntryModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Self.dateTitle(model.today))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if let latest = model.latest {
                    LatestReadingCard(reading: latest, targets: model.targets, displayUnit: model.displayUnit)
                } else {
                    FirstReadingCard(onRecordReading: onRecordReading)
                }

                DaySlotStripCard(cells: model.slotCells, targets: model.targets, displayUnit: model.displayUnit)

                if !model.todayReadings.isEmpty {
                    TodayTimelineCard(
                        readings: model.todayReadings,
                        targets: model.targets,
                        displayUnit: model.displayUnit,
                        onSelect: { editModel = model.makeEntryModel(editing: $0) }
                    )
                }

                if model.loadFailed {
                    Label {
                        Text("today.loadFailed", bundle: .module)
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
        .navigationTitle(Text("tab.today", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    SettingsView(preferences: preferences, logModel: logModel)
                } label: {
                    Label {
                        Text("tab.settings", bundle: .module)
                    } icon: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .onAppear { model.reload() }
        .sheet(item: $editModel) { entry in
            GlucoseEntryView(model: entry) {
                model.reload()
                logModel.reload()
            }
        }
    }

    /// Diary days are calendar dates; format them without shifting through the device zone.
    private static func dateTitle(_ day: LocalDay) -> String {
        guard let start = day.startInstant(in: .gmt) else { return day.isoString }
        return start.formatted(
            Date.FormatStyle(timeZone: .gmt).weekday(.wide).day().month(.wide)
        )
    }
}

/// Shared card chrome.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Self.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private static var fill: Color {
        #if os(iOS)
        Color(.secondarySystemGroupedBackground)
        #else
        Color.secondary.opacity(0.08)
        #endif
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

/// The latest reading with its age. A reading older than 8 hours is visibly marked as old,
/// so an old number is never read as the current one.
struct LatestReadingCard: View {
    let reading: GlucoseReading
    let targets: GlucoseTargets
    let displayUnit: GlucoseUnit

    /// Same staleness rule as widgets and complications (decided 27 Nov 2026).
    static let staleAfter: TimeInterval = 8 * 60 * 60

    var body: some View {
        // TimelineView re-renders the card every minute so "15 min ago" stays true.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let isStale = context.date.timeIntervalSince(reading.measuredAt) > Self.staleAfter
            VStack(alignment: .leading, spacing: 8) {
                Text("today.latest", bundle: .module)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(reading.concentration.formattedValue(in: displayUnit))
                        .font(.system(size: 56, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(isStale ? Color.secondary : Color.primary)
                    Text(verbatim: displayUnit.symbol)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if let status = reading.targetStatus(using: targets), !isStale {
                        GlucoseStatusBadge(status: status)
                    }
                }

                Text(detailLine(now: context.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if isStale {
                    Label {
                        Text("today.latest.stale", bundle: .module)
                    } icon: {
                        Image(systemName: "clock.badge.exclamationmark")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
            }
            .card()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText(now: context.date, isStale: isStale))
        }
    }

    /// "Before lunch · 13:05 · 15 min ago · manual"
    private func detailLine(now: Date) -> String {
        [
            reading.diarySlot().localizedName,
            ageText(now: now),
            reading.provenance.source.localizedName,
        ].joined(separator: " · ")
    }

    private func ageText(now: Date) -> String {
        let time = reading.measuredAt.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened, timeZone: reading.timeZone)
        )
        let readingDay = reading.localDay
        let today = LocalDay(instant: now, timeZone: reading.timeZone)
        if readingDay == today {
            let relative = reading.measuredAt.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
            return "\(time) · \(relative)"
        }
        if readingDay == today.adding(days: -1) {
            return String(localized: "today.yesterdayAt \(time)", bundle: .module)
        }
        let date = reading.measuredAt.formatted(
            Date.FormatStyle(timeZone: reading.timeZone).day().month(.abbreviated)
        )
        return "\(date), \(time)"
    }

    private func accessibilityText(now: Date, isStale: Bool) -> String {
        var parts = [
            "\(reading.concentration.formattedValue(in: displayUnit)) \(displayUnit.symbol)",
            reading.diarySlot().localizedName,
        ]
        if let status = reading.targetStatus(using: targets), !isStale {
            parts.append(status.localizedName)
        }
        parts.append(ageText(now: now))
        if isStale {
            parts.append(String(localized: "today.latest.stale", bundle: .module))
        }
        return parts.joined(separator: ", ")
    }
}

/// Empty first day: one clear action, no empty charts.
struct FirstReadingCard: View {
    var onRecordReading: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("today.first.title", bundle: .module)
                .font(.title3.weight(.semibold))
            Text("today.first.message", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: onRecordReading) {
                Label {
                    Text("action.recordReading", bundle: .module)
                } icon: {
                    Image(systemName: "drop.fill")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .card()
    }
}

/// The day's 7-point profile as a strip of cells, like the columns of the paper diary.
struct DaySlotStripCard: View {
    let cells: [TodayModel.SlotCell]
    let targets: GlucoseTargets
    let displayUnit: GlucoseUnit

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("today.profile", bundle: .module)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("today.profile.count \(measured) \(cells.count)", bundle: .module)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            // At accessibility text sizes the strip wraps to two rows.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columnCount), spacing: 8) {
                ForEach(cells) { cell in
                    SlotCellView(cell: cell, targets: targets, displayUnit: displayUnit)
                }
            }
        }
        .card()
    }

    private var measured: Int { cells.filter { $0.reading != nil }.count }

    private var columnCount: Int {
        dynamicTypeSize.isAccessibilitySize ? 4 : max(cells.count, 1)
    }
}

struct SlotCellView: View {
    let cell: TodayModel.SlotCell
    let targets: GlucoseTargets
    let displayUnit: GlucoseUnit

    var body: some View {
        let status = cell.reading?.targetStatus(using: targets)
        let isOutside = status == .below || status == .above
        VStack(spacing: 4) {
            Text(cell.slot.shortName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let reading = cell.reading {
                Text(reading.concentration.formattedValue(in: displayUnit))
                    .font(.callout.monospacedDigit().weight(isOutside ? .bold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let status {
                    Image(systemName: status.symbolName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(status.tint)
                } else {
                    Text(verbatim: " ").font(.caption2)
                }
            } else {
                Text(verbatim: "–")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                Text(verbatim: " ").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Color.secondary.opacity(cell.reading == nil ? 0.06 : 0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(status: status))
    }

    private func accessibilityText(status: GlucoseTargetStatus?) -> String {
        guard let reading = cell.reading else {
            return "\(cell.slot.localizedName), \(String(localized: "today.slot.empty", bundle: .module))"
        }
        var parts = [
            cell.slot.localizedName,
            "\(reading.concentration.formattedValue(in: displayUnit)) \(displayUnit.symbol)",
        ]
        if let status { parts.append(status.localizedName) }
        return parts.joined(separator: ", ")
    }
}

/// Today's readings, newest first.
struct TodayTimelineCard: View {
    let readings: [GlucoseReading]
    let targets: GlucoseTargets
    let displayUnit: GlucoseUnit
    var onSelect: (GlucoseReading) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("today.timeline", bundle: .module)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(readings) { reading in
                Button {
                    onSelect(reading)
                } label: {
                    GlucoseRowView(reading: reading, displayUnit: displayUnit, targets: targets)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("journal.row.hint", bundle: .module))
                if reading.id != readings.last?.id {
                    Divider()
                }
            }
        }
        .card()
    }
}

#Preview("Today") {
    let dependencies = AppDependencies.preview()
    NavigationStack {
        TodayView(
            model: TodayModel(dependencies: dependencies),
            preferences: dependencies.preferences,
            logModel: GlucoseLogModel(dependencies: dependencies),
            onRecordReading: {}
        )
    }
}

#Preview("Empty day") {
    let dependencies = AppDependencies.preview(days: 0)
    NavigationStack {
        TodayView(
            model: TodayModel(dependencies: dependencies),
            preferences: dependencies.preferences,
            logModel: GlucoseLogModel(dependencies: dependencies),
            onRecordReading: {}
        )
    }
}

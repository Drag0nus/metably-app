import MetablyDomain
import SwiftUI

/// The paper self-control diary as a table: one row per day, one column per slot.
///
/// Out-of-target values are bold with an arrow (not colour alone). When a slot has more than
/// one reading, the newest is shown with a small count. The table scrolls sideways on narrow
/// screens; the date column stays readable because each row starts with it.
struct DiaryTableView: View {
    let rows: [GlucoseLogModel.DiaryRow]
    let slots: [DiarySlot]
    let displayUnit: GlucoseUnit
    let targets: GlucoseTargets

    @ScaledMetric(relativeTo: .body) private var cellWidth: CGFloat = 52
    @ScaledMetric(relativeTo: .body) private var dateWidth: CGFloat = 64

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 12) {
                Grid(alignment: .center, horizontalSpacing: 4, verticalSpacing: 4) {
                    GridRow {
                        Text(verbatim: "")
                            .frame(width: dateWidth)
                        ForEach(slots) { slot in
                            Text(slot.shortName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: cellWidth)
                                .accessibilityLabel(Text(slot.localizedName))
                        }
                    }
                    ForEach(rows) { row in
                        GridRow {
                            Text(Self.dayTitle(row.day))
                                .font(.caption.monospacedDigit())
                                .frame(width: dateWidth, alignment: .leading)
                            ForEach(slots) { slot in
                                DiaryTableCell(
                                    slot: slot,
                                    readings: row.cells[slot] ?? [],
                                    displayUnit: displayUnit,
                                    targets: targets
                                )
                                .frame(width: cellWidth)
                            }
                        }
                    }
                }

                Text("journal.table.footer \(displayUnit.symbol)", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: dateWidth + CGFloat(slots.count) * (cellWidth + 4), alignment: .leading)
            }
            .padding()
        }
    }

    /// "27.11 Пт" style short label, formatted without shifting through the device zone.
    private static func dayTitle(_ day: LocalDay) -> String {
        guard let start = day.startInstant(in: .gmt) else { return day.isoString }
        return start.formatted(Date.FormatStyle(timeZone: .gmt).day().month(.twoDigits).weekday(.abbreviated))
    }
}

private struct DiaryTableCell: View {
    let slot: DiarySlot
    let readings: [GlucoseReading]
    let displayUnit: GlucoseUnit
    let targets: GlucoseTargets

    var body: some View {
        let latest = readings.first
        let status = latest?.targetStatus(using: targets)
        let isOutside = status == .below || status == .above
        HStack(spacing: 1) {
            if let latest {
                Text(latest.concentration.formattedValue(in: displayUnit))
                    .font(.callout.monospacedDigit().weight(isOutside ? .bold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let status, isOutside {
                    Image(systemName: status.symbolName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(status.tint)
                }
                if readings.count > 1 {
                    Text(verbatim: "+\(readings.count - 1)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(verbatim: "·")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .background(Color.secondary.opacity(latest == nil ? 0.04 : 0.1), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(latest: latest, status: status))
    }

    private func accessibilityText(latest: GlucoseReading?, status: GlucoseTargetStatus?) -> String {
        guard let latest else {
            return "\(slot.localizedName), \(String(localized: "today.slot.empty", bundle: .module))"
        }
        var parts = [slot.localizedName, "\(latest.concentration.formattedValue(in: displayUnit)) \(displayUnit.symbol)"]
        if let status { parts.append(status.localizedName) }
        if readings.count > 1 {
            parts.append(String(localized: "journal.table.more \(readings.count - 1)", bundle: .module))
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    let model = GlucoseLogModel(dependencies: dependencies)
    model.layout = .table
    return NavigationStack {
        GlucoseLogView(model: model, preferences: dependencies.preferences)
    }
}

import MetablyDomain
import SwiftUI

extension GlucoseTargetStatus {
    /// Calm colours: blue-ish for low, green for in range, orange for high. Never red for
    /// "bad"; the app states facts, not verdicts.
    var tint: Color {
        switch self {
        case .below: .indigo
        case .inRange: .green
        case .above: .orange
        }
    }
}

/// Symbol + word (+ colour) for a reading's status. Used on Today, the diary and the entry sheet.
struct GlucoseStatusBadge: View {
    let status: GlucoseTargetStatus

    var body: some View {
        Label {
            Text(status.localizedName)
        } icon: {
            Image(systemName: status.symbolName)
                .fontWeight(.bold)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(status.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(status.tint.opacity(0.12), in: Capsule())
    }
}

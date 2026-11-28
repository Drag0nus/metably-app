import Foundation
import MetablyDomain
import Observation

/// Draft of the profile and daily routine while the user edits them.
///
/// Height and weight stay text until saving so typing "72," is not lost. Doses are the user's
/// own text; nothing here computes, checks or suggests a dose.
@Observable
@MainActor
public final class ProfileEditorModel {
    public enum SaveError: Error, Sendable, Hashable {
        case height
        case weight
        case medicineName
        case storage
    }

    public var diabetesType: DiabetesType
    public var heightText: String
    public var weightText: String
    public var medicines: [ProfileMedicine]
    public var routine: DayRoutine
    public private(set) var saveError: SaveError?

    @ObservationIgnored private let profileStore: ProfileStore
    @ObservationIgnored private let preferences: UserPreferencesStore
    @ObservationIgnored private let reminders: ReminderCoordinator?

    public init(profileStore: ProfileStore, preferences: UserPreferencesStore, reminders: ReminderCoordinator? = nil) {
        self.profileStore = profileStore
        self.preferences = preferences
        self.reminders = reminders
        let profile = profileStore.profile ?? UserProfile()
        diabetesType = profile.diabetesType
        heightText = profile.heightCentimeters.map(Self.text) ?? ""
        weightText = profile.weightKilograms.map(Self.text) ?? ""
        medicines = profile.medicines
        routine = preferences.dayRoutine
    }

    static func text(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
    }

    // MARK: - Derived

    var height: Double? { DecimalInputParser.parse(heightText.trimmingCharacters(in: .whitespaces)) }
    var weight: Double? { DecimalInputParser.parse(weightText.trimmingCharacters(in: .whitespaces)) }

    /// Live BMI while typing, or nil until both values are plausible.
    public var bodyMassIndex: Double? {
        UserProfile(heightCentimeters: height, weightKilograms: weight).bodyMassIndex
    }

    public var validationError: SaveError? {
        if !heightText.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let height, UserProfile.heightRange.contains(height) else { return .height }
        }
        if !weightText.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let weight, UserProfile.weightRange.contains(weight) else { return .weight }
        }
        if medicines.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return .medicineName
        }
        return nil
    }

    public var canSave: Bool { validationError == nil }

    // MARK: - Medicines

    public func addMedicine() {
        let kind: MedicineKind = diabetesType == .type1 ? .basalInsulin : .tablet
        medicines.append(ProfileMedicine(name: "", kind: kind, minutes: [routine.schedule.breakfastMinute]))
    }

    public func removeMedicines(at offsets: IndexSet) {
        medicines.remove(atOffsets: offsets)
    }

    public func removeMedicine(id: UUID) {
        medicines.removeAll { $0.id == id }
    }

    public func addTime(toMedicine id: UUID) {
        guard let index = medicines.firstIndex(where: { $0.id == id }) else { return }
        let last = medicines[index].minutes.last ?? routine.schedule.breakfastMinute
        var minute = (last + 12 * 60) % 1440
        while medicines[index].minutes.contains(minute) { minute = (minute + 60) % 1440 }
        medicines[index].minutes = (medicines[index].minutes + [minute]).sorted()
    }

    public func setTime(_ minute: Int, at timeIndex: Int, forMedicine id: UUID) {
        guard let index = medicines.firstIndex(where: { $0.id == id }),
              medicines[index].minutes.indices.contains(timeIndex)
        else { return }
        var minutes = medicines[index].minutes
        minutes[timeIndex] = minute
        medicines[index].minutes = Array(Set(minutes)).sorted()
    }

    public func removeTime(at timeIndex: Int, forMedicine id: UUID) {
        guard let index = medicines.firstIndex(where: { $0.id == id }),
              medicines[index].minutes.indices.contains(timeIndex)
        else { return }
        medicines[index].minutes.remove(at: timeIndex)
    }

    // MARK: - Routine

    public func setMainMeal(_ slot: MealSlot, eaten: Bool) {
        if eaten { routine.skippedMeals.remove(slot) } else { routine.skippedMeals.insert(slot) }
    }

    public func addSnack() {
        guard routine.snackMinutes.count < DayRoutine.maximumSnacks else { return }
        let candidates = [11 * 60, 16 * 60 + 30, 21 * 60]
        let minute = candidates.first { !routine.snackMinutes.contains($0) } ?? 15 * 60
        routine.snackMinutes = (routine.snackMinutes + [minute]).sorted()
    }

    public func removeSnack(at index: Int) {
        guard routine.snackMinutes.indices.contains(index) else { return }
        routine.snackMinutes.remove(at: index)
    }

    public func setSnack(_ minute: Int, at index: Int) {
        guard routine.snackMinutes.indices.contains(index) else { return }
        routine.snackMinutes[index] = minute
        routine.snackMinutes.sort()
    }

    // MARK: - Save

    @discardableResult
    public func save() -> Bool {
        saveError = nil
        if let error = validationError {
            saveError = error
            return false
        }
        let profile = UserProfile(
            diabetesType: diabetesType,
            heightCentimeters: heightText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : height,
            weightKilograms: weightText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : weight,
            medicines: medicines.map { medicine in
                var medicine = medicine
                medicine.name = medicine.name.trimmingCharacters(in: .whitespacesAndNewlines)
                medicine.doseText = medicine.doseText.trimmingCharacters(in: .whitespacesAndNewlines)
                return medicine
            }
        )
        profileStore.save(profile)
        if profileStore.saveFailed {
            saveError = .storage
            return false
        }
        preferences.dayRoutine = routine
        // Insulin in the profile shows the insulin module; it is never switched off from here.
        if profile.usesInsulin { preferences.usesInsulin = true }
        if let reminders { Task { await reminders.applyIfAllowed() } }
        return true
    }
}

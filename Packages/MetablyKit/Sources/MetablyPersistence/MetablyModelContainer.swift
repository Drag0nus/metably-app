import Foundation
import SwiftData

/// Builds the app's `ModelContainer`.
///
/// CloudKit is explicitly disabled (`cloudKitDatabase: .none`): personal health data must not
/// go to iCloud. Backup and sync will go through Metably's own backend in a later milestone.
public enum MetablyModelContainer {
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: MetablySchemaV1.self)
        let configuration = ModelConfiguration(
            "Metably",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: MetablyMigrationPlan.self,
            configurations: [configuration]
        )
    }
}

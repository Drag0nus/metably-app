import Foundation
import SwiftData

/// Builds the app's `ModelContainer`.
///
/// CloudKit is explicitly disabled (`cloudKitDatabase: .none`): personal health data must not
/// go to iCloud. Backup and sync will go through Metably's own backend in a later milestone.
public enum MetablyModelContainer {
    /// - Parameter url: store location; nil uses the default app location. Tests pass a
    ///   temporary file to exercise migrations.
    public static func make(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: MetablyCurrentSchema.self)
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(
                "Metably",
                schema: schema,
                url: url,
                allowsSave: true,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                "Metably",
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: MetablyMigrationPlan.self,
            configurations: [configuration]
        )
    }
}

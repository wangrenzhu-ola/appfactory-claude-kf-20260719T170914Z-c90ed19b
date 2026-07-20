import Foundation

public enum StoreError: Error, Equatable {
    case loadFailed
    case saveFailed
    case corruptedData
}

/// Append-only-style local JSON store. All data stays on device; there is no
/// account and no network dependency. Writes are atomic and failures surface
/// as typed errors so the UI can show an inline error bar without losing
/// in-flight form data.
public final class LocalStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    /// Test/debug hook: when true, every save throws `StoreError.saveFailed`.
    public var simulateSaveFailure = false

    public init(fileURL: URL) {
        self.fileURL = fileURL
        // Encode dates as raw timestamps so a save→load round-trip preserves
        // full Date precision; ISO8601 text truncates to milliseconds and
        // breaks snapshot equality for in-flight editing state.
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .deferredToDate
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
    }

    public func load() throws -> StoreSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .empty
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(StoreSnapshot.self, from: data)
        } catch {
            throw StoreError.corruptedData
        }
    }

    public func save(_ snapshot: StoreSnapshot) throws {
        if simulateSaveFailure { throw StoreError.saveFailed }
        do {
            let data = try encoder.encode(snapshot)
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw StoreError.saveFailed
        }
    }
}

/// In-memory store used by unit tests and SwiftUI previews.
public final class MemoryStore {
    public private(set) var snapshot: StoreSnapshot
    public var simulateSaveFailure = false

    public init(snapshot: StoreSnapshot = .empty) {
        self.snapshot = snapshot
    }

    public func save(_ snapshot: StoreSnapshot) throws {
        if simulateSaveFailure { throw StoreError.saveFailed }
        self.snapshot = snapshot
    }

    public func load() -> StoreSnapshot { snapshot }
}

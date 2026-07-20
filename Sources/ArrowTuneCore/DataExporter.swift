import Foundation

/// Complete snapshot of the local data store, used for persistence and export.
public struct StoreSnapshot: Codable, Equatable, Sendable {
    public var sessions: [Session]
    public var ends: [End]
    public var impacts: [ArrowImpact]
    public var gear: [GearSetup]
    public var tuningChanges: [TuningChange]
    public var reports: [DiagnosisReport]

    public init(
        sessions: [Session] = [],
        ends: [End] = [],
        impacts: [ArrowImpact] = [],
        gear: [GearSetup] = [],
        tuningChanges: [TuningChange] = [],
        reports: [DiagnosisReport] = []
    ) {
        self.sessions = sessions
        self.ends = ends
        self.impacts = impacts
        self.gear = gear
        self.tuningChanges = tuningChanges
        self.reports = reports
    }

    public static let empty = StoreSnapshot()
}

public enum ExportError: Error, Equatable {
    case encodingFailed
}

/// Pro-gated data portability: JSON and CSV snapshots of the local store.
public enum DataExporter {
    public static func exportJSON(_ snapshot: StoreSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(snapshot)
        } catch {
            throw ExportError.encodingFailed
        }
    }

    /// One CSV row per confirmed impact, joined with its session context.
    public static func exportCSV(_ snapshot: StoreSnapshot) -> String {
        var lines = [
            "session_id,date,distance_m,target_face,bow_type,end_index,impact_id,x_norm,y_norm,ring_value,source"
        ]
        let sessionsByID = Dictionary(uniqueKeysWithValues: snapshot.sessions.map { ($0.sessionID, $0) })
        let endsByID = Dictionary(uniqueKeysWithValues: snapshot.ends.map { ($0.endID, $0) })
        let formatter = ISO8601DateFormatter()
        for impact in snapshot.impacts where impact.confirmed {
            guard let end = endsByID[impact.endID],
                  let session = sessionsByID[end.sessionID] else { continue }
            let row = [
                session.sessionID.uuidString,
                formatter.string(from: session.date),
                String(session.distanceM),
                session.targetFace.rawValue,
                session.bowType.rawValue,
                String(end.endIndex),
                impact.impactID.uuidString,
                String(format: "%.5f", impact.xNorm),
                String(format: "%.5f", impact.yNorm),
                String(impact.ringValue),
                impact.source.rawValue,
            ].map(csvEscape).joined(separator: ",")
            lines.append(row)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}

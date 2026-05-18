import Foundation
import ComposableArchitecture
import SQLite3
@preconcurrency import ZcashLightClientKit

// MARK: - Draft Persistence

extension Voting {
    private static let draftPrefix = "voting.draftVotes."
    private static let voteRecordPrefix = "voting.voteRecord."

    /// Persisted record of when a round's vote submission fully completed,
    /// the voting weight at that moment, and how many proposals were included.
    /// Survives app termination so the Results screen can render
    /// "Voted Feb 15 - Voting Power X.XXX ZEC" and the polls list can show
    /// the Voted state days after submission, even though the live session
    /// state is per-session.
    struct VoteRecord: Equatable {
        let votedAt: Date
        let votingWeight: UInt64
        let proposalCount: Int

        init(votedAt: Date, votingWeight: UInt64, proposalCount: Int) {
            self.votedAt = votedAt
            self.votingWeight = votingWeight
            self.proposalCount = proposalCount
        }
    }

    private static func voteRecordKey(walletId: String, roundId: String) -> String {
        "\(voteRecordPrefix)\(walletId)|\(roundId)"
    }

    static func persistVoteRecord(_ record: VoteRecord, walletId: String, roundId: String) {
        let key = voteRecordKey(walletId: walletId, roundId: roundId)
        UserDefaults.standard.set(
            [
                "votedAt": record.votedAt.timeIntervalSince1970,
                "votingWeight": NSNumber(value: record.votingWeight),
                "proposalCount": NSNumber(value: record.proposalCount)
            ],
            forKey: key
        )
    }

    static func loadVoteRecord(walletId: String, roundId: String) -> VoteRecord? {
        let key = voteRecordKey(walletId: walletId, roundId: roundId)
        guard let raw = UserDefaults.standard.dictionary(forKey: key),
              let votedAtUnix = raw["votedAt"] as? Double,
              let weight = (raw["votingWeight"] as? NSNumber)?.uint64Value else {
            return nil
        }
        // proposalCount was added later — older records default to 0 and the
        // view falls back to the round's full proposal count for display.
        let count = (raw["proposalCount"] as? NSNumber)?.intValue ?? 0
        return VoteRecord(
            votedAt: Date(timeIntervalSince1970: votedAtUnix),
            votingWeight: weight,
            proposalCount: count
        )
    }

    static func clearPersistedVoteRecord(walletId: String, roundId: String) {
        UserDefaults.standard.removeObject(forKey: voteRecordKey(walletId: walletId, roundId: roundId))
    }

    /// A round-level vote record is only valid once all drafts are gone.
    /// Older builds wrote it too early, so clear it if there is still
    /// outstanding editable work for the round.
    static func loadCompletedVoteRecord(walletId: String, roundId: String) -> VoteRecord? {
        guard loadDrafts(walletId: walletId, roundId: roundId).isEmpty else {
            clearPersistedVoteRecord(walletId: walletId, roundId: roundId)
            return nil
        }
        return loadVoteRecord(walletId: walletId, roundId: roundId)
    }

    private static func draftKey(walletId: String, roundId: String) -> String {
        "\(draftPrefix)\(walletId)|\(roundId)"
    }

    /// Persist draft votes to UserDefaults so they survive app termination.
    static func persistDrafts(_ drafts: [UInt32: VoteChoice], walletId: String, roundId: String) {
        let key = draftKey(walletId: walletId, roundId: roundId)
        if drafts.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            let encoded = drafts.reduce(into: [String: UInt32]()) { dict, entry in
                dict[String(entry.key)] = entry.value.index
            }
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    /// Load persisted draft votes for a round.
    static func loadDrafts(walletId: String, roundId: String) -> [UInt32: VoteChoice] {
        let key = draftKey(walletId: walletId, roundId: roundId)
        guard let raw = UserDefaults.standard.dictionary(forKey: key) as? [String: UInt32] else {
            return [:]
        }
        return raw.reduce(into: [UInt32: VoteChoice]()) { dict, entry in
            if let proposalId = UInt32(entry.key) {
                dict[proposalId] = .option(entry.value)
            }
        }
    }

    /// Remove all persisted drafts for a round.
    static func clearPersistedDrafts(walletId: String, roundId: String) {
        UserDefaults.standard.removeObject(forKey: draftKey(walletId: walletId, roundId: roundId))
    }
}

// MARK: - Note Bundling

/// Result of value-aware note bundling on the Swift side.
struct BundleResult {
    let bundles: [[NoteInfo]]
    let eligibleWeight: UInt64
    let droppedCount: Int
}

enum VoteNoiseFeature {
    static let bundleIdentifier = "co.valargroup.zodl.noise"
    static let defaultTargetNoteValue: UInt64 = ballotDivisor
    /// Hard cap on how many outputs a single Split transaction will create.
    /// Each output is one Orchard action and proof generation is CPU-heavy on
    /// device, so 100 is a conservative ceiling. When the wallet's balance
    /// would produce more, the Split summary tells the user to re-run after
    /// this transaction confirms.
    static let maxSplitOutputs = 100
    /// Notes worth at or below this threshold are non-economic — ZIP-317's
    /// marginal fee is 5,000 zatoshi per logical action, so spending such a
    /// note costs at least as much as the note is worth. Hidden from the
    /// default note list (toggle reveals them) and excluded from the visible
    /// count, though their value still appears in Total since the planner
    /// can sweep them when they aggregate to something useful.
    static let dustThresholdZatoshi: UInt64 = 5_000
    /// Minimum value the smaller non-dust notes must sum to before Consolidate
    /// is considered useful. ZIP-317 fees for a 1-output consolidate proposal
    /// land around 10–30k zatoshi depending on input count; 100,000 zatoshi
    /// (0.001 ZEC) puts the gain comfortably above the fee floor so the button
    /// only enables when running it produces a meaningfully larger merged note.
    static let consolidateMeaningfulMinZatoshi: UInt64 = 100_000

    static var isEnabled: Bool {
        Bundle.main.bundleIdentifier == bundleIdentifier
    }

    static func zecString(_ zatoshi: UInt64) -> String {
        let whole = zatoshi / UInt64(Zatoshi.Constants.oneZecInZatoshi)
        let fractional = zatoshi % UInt64(Zatoshi.Constants.oneZecInZatoshi)
        guard fractional > 0 else { return "\(whole)" }

        var fractionalText = String(format: "%08llu", fractional)
        while fractionalText.last == "0" {
            fractionalText.removeLast()
        }
        return "\(whole).\(fractionalText)"
    }

    /// Strip everything except digits and a single decimal point from typed
    /// input. `decimalPad` only gates the soft keyboard — paste, hardware
    /// keyboards, and dictation can all still inject letters or extra dots,
    /// so the reducer scrubs the text on its way in.
    static func sanitizeNoteValueInput(_ text: String) -> String {
        var seenDot = false
        var result = ""
        for ch in text {
            if ch.isASCII, ch.isNumber {
                result.append(ch)
            } else if ch == "." && !seenDot {
                result.append(ch)
                seenDot = true
            }
        }
        return result
    }

    static func parseZatoshi(_ text: String) -> UInt64? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2,
              let whole = UInt64(parts[0]),
              whole <= UInt64.max / UInt64(Zatoshi.Constants.oneZecInZatoshi)
        else {
            return nil
        }

        var fractional: UInt64 = 0
        if parts.count == 2 {
            let fraction = parts[1]
            guard fraction.count <= 8, fraction.allSatisfy(\.isNumber) else { return nil }
            let padded = String(fraction).padding(toLength: 8, withPad: "0", startingAt: 0)
            guard let parsedFractional = UInt64(padded) else { return nil }
            fractional = parsedFractional
        }

        let zatoshi = whole * UInt64(Zatoshi.Constants.oneZecInZatoshi) + fractional
        return zatoshi > 0 ? zatoshi : nil
    }

    static func splitReserve(total: UInt64, target: UInt64) -> UInt64 {
        guard total > target, target > 1 else { return 0 }
        let proportionalReserve = total / 1_000
        let minimumReserve: UInt64 = 100_000
        return min(target - 1, max(minimumReserve, proportionalReserve))
    }

    static func normalizeReserve(total: UInt64, target: UInt64) -> UInt64 {
        guard total > 1 else { return 0 }
        let proportionalReserve = total / 500
        let minimumReserve: UInt64 = 100_000
        let cappedByTarget = target > 1 ? min(target - 1, max(minimumReserve, proportionalReserve)) : minimumReserve
        return min(total - 1, cappedByTarget)
    }
}

enum VoteNoiseSettings {
    private static let targetNoteValueKey = "voteNoise.targetNoteValueZatoshi"

    static var targetNoteValue: UInt64 {
        let stored = UserDefaults.standard.object(forKey: targetNoteValueKey) as? NSNumber
        return stored?.uint64Value ?? VoteNoiseFeature.defaultTargetNoteValue
    }

    static var targetNoteValueText: String {
        VoteNoiseFeature.zecString(targetNoteValue)
    }

    static func setTargetNoteValue(_ value: UInt64) {
        UserDefaults.standard.set(NSNumber(value: value), forKey: targetNoteValueKey)
    }
}

enum VotingBundlePolicy {
    case standard
    case zodlNoise

    func bundle(_ notes: [NoteInfo]) -> BundleResult {
        switch self {
        case .standard:
            return notes.smartBundles()
        case .zodlNoise:
            let eligibleNotes = notes
                .filter { $0.value == ballotDivisor }
                .sorted { $0.position < $1.position }
            let bundles = eligibleNotes.map { [$0] }
            return BundleResult(
                bundles: bundles,
                eligibleWeight: UInt64(bundles.count) * ballotDivisor,
                droppedCount: notes.count - eligibleNotes.count
            )
        }
    }
}

func votingBundlePolicy() -> VotingBundlePolicy {
    VoteNoiseFeature.isEnabled ? .zodlNoise : .standard
}

enum VotingNoiseBundleStoreError: LocalizedError {
    case openDatabase(String)
    case prepare(String)
    case bind(String)
    case step(String)
    case bundleCountOverflow

    var errorDescription: String? {
        switch self {
        case .openDatabase(let message):
            return "Couldn't open voting database: \(message)"
        case .prepare(let message):
            return "Couldn't prepare voting database statement: \(message)"
        case .bind(let message):
            return "Couldn't bind voting database statement: \(message)"
        case .step(let message):
            return "Couldn't update voting database: \(message)"
        case .bundleCountOverflow:
            return "Too many note bundles to prepare."
        }
    }
}

enum VotingNoiseBundleStore {
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    static func replaceBundles(
        databasePath: String,
        roundId: String,
        walletId: String,
        bundles: [[NoteInfo]]
    ) throws -> UInt32 {
        guard let count = UInt32(exactly: bundles.count) else {
            throw VotingNoiseBundleStoreError.bundleCountOverflow
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db
        else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            throw VotingNoiseBundleStoreError.openDatabase(message)
        }
        defer { sqlite3_close(db) }

        do {
            try execute(db, sql: "BEGIN IMMEDIATE")
            try execute(
                db,
                sql: "DELETE FROM bundles WHERE round_id = ? AND wallet_id = ?",
                bind: { statement in
                    try bindText(statement, index: 1, value: roundId)
                    try bindText(statement, index: 2, value: walletId)
                }
            )

            for (index, bundle) in bundles.enumerated() {
                let positionsBlob = notePositionsBlob(bundle)
                try execute(
                    db,
                    sql: "INSERT INTO bundles (round_id, wallet_id, bundle_index, note_positions_blob) VALUES (?, ?, ?, ?)",
                    bind: { statement in
                        try bindText(statement, index: 1, value: roundId)
                        try bindText(statement, index: 2, value: walletId)
                        try bindInt(statement, index: 3, value: Int32(index))
                        try bindBlob(statement, index: 4, value: positionsBlob)
                    }
                )
            }

            try execute(db, sql: "COMMIT")
            return count
        } catch {
            try? execute(db, sql: "ROLLBACK")
            throw error
        }
    }

    private static func notePositionsBlob(_ notes: [NoteInfo]) -> Data {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(notes.count * MemoryLayout<UInt64>.size)
        for note in notes {
            var littleEndianPosition = note.position.littleEndian
            withUnsafeBytes(of: &littleEndianPosition) { rawBuffer in
                bytes.append(contentsOf: rawBuffer)
            }
        }
        return Data(bytes)
    }

    private static func execute(
        _ db: OpaquePointer,
        sql: String,
        bind: (OpaquePointer) throws -> Void = { _ in }
    ) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw VotingNoiseBundleStoreError.prepare(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }

        try bind(statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw VotingNoiseBundleStoreError.step(String(cString: sqlite3_errmsg(db)))
        }
    }

    private static func bindText(_ statement: OpaquePointer, index: Int32, value: String) throws {
        guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else {
            throw VotingNoiseBundleStoreError.bind("text at index \(index)")
        }
    }

    private static func bindInt(_ statement: OpaquePointer, index: Int32, value: Int32) throws {
        guard sqlite3_bind_int(statement, index, value) == SQLITE_OK else {
            throw VotingNoiseBundleStoreError.bind("integer at index \(index)")
        }
    }

    private static func bindBlob(_ statement: OpaquePointer, index: Int32, value: Data) throws {
        let result = value.withUnsafeBytes { rawBuffer in
            sqlite3_bind_blob(statement, index, rawBuffer.baseAddress, Int32(value.count), transient)
        }
        guard result == SQLITE_OK else {
            throw VotingNoiseBundleStoreError.bind("blob at index \(index)")
        }
    }
}

extension Array where Element == NoteInfo {
    /// Value-aware bundling using greedy min-total assignment.
    ///
    /// Mirrors the Rust peer `chunk_notes` (see
    /// `zcash_voting/zcash_voting/src/types.rs` — function `chunk_notes`) for
    /// client-side use. The numbered steps in the body track that function
    /// one-to-one:
    /// 1. Sort notes by value DESC, then position ASC as tiebreaker
    /// 2. Fill bundles sequentially to capacity (5 notes each)
    /// 3. Drop bundles with total < ballotDivisor
    /// 4. Re-sort notes within each surviving bundle by position
    /// 5. Sort surviving bundles by total value DESC (min position as tiebreaker)
    func smartBundles() -> BundleResult {
        guard !isEmpty else {
            return BundleResult(bundles: [], eligibleWeight: 0, droppedCount: 0)
        }

        // Step 1: Sort by value DESC, then position ASC
        let sorted = self.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.position < rhs.position
        }

        // Step 2: Fill bundles sequentially to capacity (5 notes each)
        var bundleNotes: [[NoteInfo]] = []
        var bundleTotals: [UInt64] = []

        for note in sorted {
            if bundleNotes.isEmpty || (bundleNotes.last?.count ?? 0) >= 5 {
                bundleNotes.append([])
                bundleTotals.append(0)
            }
            let last = bundleNotes.count - 1
            bundleTotals[last] += note.value
            bundleNotes[last].append(note)
        }

        // Step 3: Drop bundles with total < ballotDivisor
        let numBundles = bundleNotes.count
        var surviving: [(total: UInt64, notes: [NoteInfo])] = []
        var eligibleWeight: UInt64 = 0
        var survivingNoteCount = 0

        for i in 0..<numBundles where bundleTotals[i] >= ballotDivisor {
            surviving.append((bundleTotals[i], bundleNotes[i]))
            eligibleWeight += quantizeWeight(bundleTotals[i])
            survivingNoteCount += bundleNotes[i].count
        }
        let droppedCount = count - survivingNoteCount

        // Step 5: Re-sort notes within each surviving bundle by position
        for i in 0..<surviving.count {
            surviving[i].notes.sort { $0.position < $1.position }
        }

        // Step 6: Sort surviving bundles by total value DESC (min position as tiebreaker).
        // This ensures bundle 0 is always the most valuable, enabling users to skip
        // low-value trailing bundles during Keystone signing.
        surviving.sort { lhs, rhs in
            if lhs.total != rhs.total { return lhs.total > rhs.total }
            return (lhs.notes.first?.position ?? .max) < (rhs.notes.first?.position ?? .max)
        }

        return BundleResult(bundles: surviving.map(\.notes), eligibleWeight: eligibleWeight, droppedCount: droppedCount)
    }
}

/// Convert hex string to Data (used for share confirmation polling and API parsing).
func votingDataFromHex(_ hex: String) -> Data {
    var data = Data()
    var idx = hex.startIndex
    while idx < hex.endIndex {
        let next = hex.index(idx, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
        if let byte = UInt8(hex[idx..<next], radix: 16) {
            data.append(byte)
        }
        idx = next
    }
    return data
}

// MARK: - Skip Bundles Alert

extension AlertState where Action == Voting.Action {
    static func confirmSkip(lockedIn: String, givingUp: String) -> AlertState {
        AlertState {
            TextState(String(localizable: .coinVoteDelegationSigningSkipAlertTitle))
        } actions: {
            ButtonState(role: .destructive, action: .skipRemainingKeystoneBundlesConfirmed) {
                TextState(String(localizable: .coinVoteDelegationSigningSkipAlertPrimary))
            }
            ButtonState(role: .cancel, action: .skipBundlesAlert(.dismiss)) {
                TextState(String(localizable: .coinVoteDelegationSigningSkipAlertCancel))
            }
        } message: {
            TextState(String(localizable: .coinVoteDelegationSigningSkipAlertMessage(lockedIn, givingUp)))
        }
    }
}

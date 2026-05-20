import Foundation
import ComposableArchitecture
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

extension Array where Element == NoteInfo {
    /// Value-aware bundle planning delegated to the shared SDK policy.
    func plannedVotingBundles() throws -> BundleResult {
        let plan = try VotingRustBackend.planNoteBundles(notes: map { $0.toSDK() })
        return BundleResult(
            bundles: plan.bundles.map { $0.map(NoteInfo.init(sdk:)) },
            eligibleWeight: plan.eligibleWeight,
            droppedCount: Int(clamping: plan.droppedCount)
        )
    }

    /// Non-throwing convenience for UI-derived display strings.
    func plannedVotingBundlesOrEmpty() -> BundleResult {
        do {
            return try plannedVotingBundles()
        } catch {
            votingLogger.error("Failed to plan voting bundles: \(error)")
            return BundleResult(bundles: [], eligibleWeight: 0, droppedCount: count)
        }
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

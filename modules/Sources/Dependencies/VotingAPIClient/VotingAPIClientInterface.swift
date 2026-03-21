import ComposableArchitecture
import Foundation
import VotingModels

extension DependencyValues {
    public var votingAPI: VotingAPIClient {
        get { self[VotingAPIClient.self] }
        set { self[VotingAPIClient.self] = newValue }
    }
}

@DependencyClient
public struct VotingAPIClient {
    /// Fetch service config: tries local override first, then CDN, then falls back to defaults.
    public var fetchServiceConfig: @Sendable () async throws -> VotingServiceConfig
    /// Configure the API client to use URLs from the resolved service config.
    public var configureURLs: @Sendable (_ config: VotingServiceConfig) async -> Void
    public var fetchActiveVotingSession: @Sendable () async throws -> VotingSession
    public var fetchAllRounds: @Sendable () async throws -> [VotingSession]
    public var fetchRoundById: @Sendable (_ roundIdHex: String) async throws -> VotingSession
    public var fetchTallyResults: @Sendable (_ roundIdHex: String) async throws -> [UInt32: TallyResult]
    public var fetchVotingWeight: @Sendable (_ snapshotHeight: UInt64) async throws -> UInt64
    public var fetchNoteInclusionProofs: @Sendable (_ commitments: [Data]) async throws -> [Data]
    public var fetchNullifierExclusionProofs: @Sendable (_ nullifiers: [Data]) async throws -> [Data]
    public var fetchCommitmentTreeState: @Sendable (_ height: UInt64) async throws -> CommitmentTreeState
    public var fetchLatestCommitmentTree: @Sendable () async throws -> CommitmentTreeState
    public var submitDelegation: @Sendable (_ registration: DelegationRegistration) async throws -> TxResult
    public var submitVoteCommitment: @Sendable (_ bundle: VoteCommitmentBundle, _ signature: CastVoteSignature) async throws -> TxResult
    /// Distribute shares across available vote servers. Config must be set via `configureURLs` first.
    /// Returns one receipt per successful helper POST, with `seq` ordering targets for status polling.
    public var delegateShares: @Sendable (_ payloads: [SharePayload], _ roundIdHex: String) async throws -> [ShareDelegationReceipt]
        = { _, _ in [] }
    /// Poll share submission status on the **same** helper host that accepted the share (`roundId` + nullifier hex).
    public var fetchShareSubmissionStatus: @Sendable (
        _ helperURL: String, _ roundIdHex: String, _ nullifierHex: String
    ) async throws -> String
        = { _, _, _ in "confirmed" }
    /// Re-POST a share to a specific helper (same body as delegation). Returns true if queued/duplicate.
    public var resubmitShare: @Sendable (_ payload: SharePayload, _ roundIdHex: String, _ helperURL: String) async throws -> Bool
        = { _, _, _ in false }
    public var fetchProposalTally: @Sendable (_ roundId: Data, _ proposalId: UInt32) async throws -> TallyResult
    /// Query the Cosmos SDK TX endpoint for a confirmed transaction and its ABCI events.
    /// Returns nil if the TX is not yet in a block (404 or network error).
    public var fetchTxConfirmation: @Sendable (_ txHash: String) async throws -> TxConfirmation?
}

import Foundation

/// A single vote option within a proposal (e.g. "Support", "Oppose").
/// Maps to VoteOption message (zvote/v1/types.proto).
public struct VoteOption: Equatable, Sendable {
    public let index: UInt32
    public let label: String

    public init(index: UInt32, label: String) {
        self.index = index
        self.label = label
    }
}

/// A group of vote options whose votes are summed when comparing camps.
/// Maps to OptionGroup message (svote/v1/types.proto).
public struct OptionGroup: Equatable, Sendable {
    public let id: UInt32
    public let label: String
    public let optionIndices: [UInt32]

    public init(id: UInt32, label: String, optionIndices: [UInt32]) {
        self.id = id
        self.label = label
        self.optionIndices = optionIndices
    }
}

/// Maps to Proposal message (svote/v1/types.proto).
/// Chain uses uint32 id. UI-only metadata (zipNumber, forumURL) comes from off-chain sources.
public struct Proposal: Equatable, Identifiable, Sendable {
    public let id: UInt32
    public let title: String
    public let description: String
    public let options: [VoteOption]
    public let optionGroups: [OptionGroup]
    public let zipNumber: String?
    public let forumURL: URL?

    public init(
        id: UInt32,
        title: String,
        description: String,
        options: [VoteOption] = [],
        optionGroups: [OptionGroup] = [],
        zipNumber: String? = nil,
        forumURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.options = options
        self.optionGroups = optionGroups
        self.zipNumber = zipNumber
        self.forumURL = forumURL
    }
}

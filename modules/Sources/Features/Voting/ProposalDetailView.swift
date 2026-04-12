import SwiftUI
import ComposableArchitecture
import Generated
import UIComponents
import VotingModels

struct ProposalDetailView: View {
    @Environment(\.colorScheme)
    var colorScheme

    let store: StoreOf<Voting>
    let proposal: Proposal

    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                ScrollView {
                    contentSection()
                }

                bottomSection()
            }
            .applyScreenBackground()
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        store.send(.backToList)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Design.Text.primary.color(colorScheme))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(positionLabel)
                        .zFont(.semiBold, size: 14, style: Design.Text.primary)
                }
            }
        }
    }

    private var positionLabel: String {
        if let index = store.detailProposalIndex {
            return "\(index + 1) OF \(store.totalProposals)"
        }
        return ""
    }

    // MARK: - Content

    @ViewBuilder
    private func contentSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(proposal.title)
                .zFont(.semiBold, size: 24, style: Design.Text.primary)
                .tracking(-0.384)
                .fixedSize(horizontal: false, vertical: true)

            if !proposal.description.isEmpty {
                Text(proposal.description)
                    .zFont(size: 16, style: Design.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            forumLink()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    // MARK: - Forum Link

    @ViewBuilder
    private func forumLink() -> some View {
        let content = HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Design.Surfaces.bgTertiary.color(colorScheme))
                    .frame(width: 36, height: 36)
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Design.Text.primary.color(colorScheme))
            }

            Text("View Forum Discussion")
                .zFont(.medium, size: 16, style: Design.Text.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Design.Text.tertiary.color(colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius._2xl))
        .overlay(
            RoundedRectangle(cornerRadius: Design.Radius._2xl)
                .stroke(Design.Surfaces.strokeSecondary.color(colorScheme), lineWidth: 1)
        )

        if let url = proposal.forumURL {
            Link(destination: url) { content }
        } else {
            content
                .opacity(0.5)
        }
    }

    // MARK: - Bottom Section

    @ViewBuilder
    private func bottomSection() -> some View {
        let confirmedVote = store.votes[proposal.id]
        let isLocked = confirmedVote != nil || store.isBatchSubmitting

        VStack(spacing: 20) {
            voteOptions(confirmedVote: confirmedVote, isLocked: isLocked)
            navigationButtons()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: - Vote Options

    /// Options including an Abstain fallback when the data doesn't provide one.
    private var displayOptions: [VoteOption] {
        let hasAbstain = proposal.options.contains {
            $0.label.localizedCaseInsensitiveContains("abstain")
        }
        if hasAbstain || proposal.options.isEmpty {
            return proposal.options
        }
        let nextIndex = (proposal.options.map(\.index).max() ?? 0) + 1
        return proposal.options + [VoteOption(index: nextIndex, label: "Abstain")]
    }

    @ViewBuilder
    private func voteOptions(confirmedVote: VoteChoice?, isLocked: Bool) -> some View {
        let options = displayOptions
        let draftChoice = store.draftVotes[proposal.id]
        let displayChoice = confirmedVote ?? draftChoice

        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.index) { offset, option in
                let choice = VoteChoice.option(option.index)
                let isSelected = displayChoice == choice

                voteOptionRow(
                    label: option.label,
                    isSelected: isSelected,
                    color: voteOptionColor(for: option.index, total: options.count),
                    isLocked: isLocked
                ) {
                    impactFeedback.impactOccurred()
                    store.send(.castVote(proposalId: proposal.id, choice: choice))
                }

                // Divider between unselected adjacent options
                if offset < options.count - 1 {
                    let nextOption = options[offset + 1]
                    let nextSelected = displayChoice == VoteChoice.option(nextOption.index)
                    if !isSelected && !nextSelected {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func voteOptionRow(
        label: String,
        isSelected: Bool,
        color: Color,
        isLocked: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .zFont(.medium, size: 16,
                           color: isSelected ? .white : Design.Text.primary.color(colorScheme))

                Spacer()

                // Checkbox
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 40/255, green: 38/255, blue: 34/255))
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Design.Surfaces.strokeSecondary.color(colorScheme), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? color : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: Design.Radius._xl))
        }
        .disabled(isLocked)
    }

    // MARK: - Navigation Buttons

    @ViewBuilder
    private func navigationButtons() -> some View {
        let isFirst = store.detailProposalIndex == 0
        let isLast = store.detailProposalIndex == store.totalProposals - 1

        HStack(spacing: 12) {
            if !isFirst {
                ZashiButton("Back", type: .secondary) {
                    store.send(.previousProposalDetail)
                }
            }

            ZashiButton(isLast ? "Done" : "Next") {
                if isLast {
                    store.send(.backToList)
                } else {
                    store.send(.nextProposalDetail)
                }
            }
        }
    }
}

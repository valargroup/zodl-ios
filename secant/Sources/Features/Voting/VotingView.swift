import SwiftUI
import ComposableArchitecture

struct VotingView: View {
    let store: StoreOf<Voting>

    public init(store: StoreOf<Voting>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            let screen = store.screenStack.last ?? .pollsList
            screenView(for: screen)
                .id(screenId(screen))
                .animation(.easeInOut(duration: 0.22), value: screenId(screen))
                .animation(.easeInOut(duration: 0.3), value: store.selectedProposal?.id)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            store.send(.initialize)
            store.send(.warmProvingCaches)
        }
        .sheet(
            store: store.scope(state: \.$keystoneScan, action: \.keystoneScan)
        ) { scanStore in
            ScanView(store: scanStore, popoverRatio: 1.075)
        }
        .votingSheet(
            isPresented: pollClosedBinding,
            title: String(localizable: .coinVoteVotingViewPollClosedTitle),
            message: String(localizable: .coinVoteVotingViewPollClosedMessage),
            primary: .init(title: String(localizable: .coinVoteCommonViewResults), style: .primary) {
                store.send(.viewPollClosedResults)
            },
            secondary: .init(title: String(localizable: .coinVoteCommonClose), style: .secondary) {
                store.send(.dismissPollClosedSheet)
            },
            visualStyle: .unverifiedWarning
        )
        .votingSheet(
            isPresented: unverifiedPollWarningBinding,
            iconSystemName: "exclamationmark.triangle",
            title: String(localized: "Unverified Poll"),
            message: String(
                localized: "This poll hasn't been verified. We can't confirm its legitimacy or how results will be used."
            ),
            primary: .init(title: String(localized: "Go back"), style: .primary) {
                store.send(.unverifiedPollWarningGoBackTapped)
            },
            secondary: .init(title: String(localized: "Proceed anyway"), style: .secondary) {
                store.send(.unverifiedPollWarningProceedTapped)
            },
            visualStyle: .unverifiedWarning,
            onDismiss: {
                if store.pendingUnverifiedRoundTapId != nil {
                    store.send(.openPendingUnverifiedRound)
                }
            }
        )
    }

    private var pollClosedBinding: Binding<Bool> {
        Binding(
            get: { store.showPollClosedSheet },
            // Guard against SwiftUI re-firing this setter after a *programmatic*
            // dismiss (e.g. `viewPollClosedResults` flips `showPollClosedSheet`
            // to false and switches the screen). On iOS 16+ the sheet's binding
            // gets a `set(false)` callback once the dismiss animation settles —
            // without this guard, that spurious callback would send
            // `.dismissPollClosedSheet` → `.backToRoundsList` and pop the user
            // back to the polls list right after we just routed them to
            // results/tallying. Only the *interactive* drag-dismiss path runs
            // with the state still true at the moment of the setter call.
            set: { newValue in
                if !newValue && store.showPollClosedSheet {
                    store.send(.dismissPollClosedSheet)
                }
            }
        )
    }

    private var unverifiedPollWarningBinding: Binding<Bool> {
        Binding(
            get: { store.showUnverifiedPollWarning },
            set: { newValue in
                if !newValue && store.showUnverifiedPollWarning {
                    store.send(.unverifiedPollWarningGoBackTapped)
                }
            }
        )
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func screenId(_ screen: Voting.State.Screen) -> String {
        switch screen {
        case .howToVote: return "howToVote"
        case .loading: return "loading"
        case .noRounds: return "noRounds"
        case .pollsList: return "pollsList"
        case .delegationSigning: return "delegationSigning"
        case .proposalList: return "proposalList"
        case .proposalDetail(let id): return "detail-\(id)"
        case .ineligible: return "ineligible"
        case .tallying: return "tallying"
        case .results: return "results"
        case .reviewVotes: return "reviewVotes"
        case .confirmSubmission: return "confirmSubmission"
        case .error: return "error"
        case .configError: return "configError"
        case .configSettings: return "configSettings"
        case .walletSyncing: return "walletSyncing"
        case .noisePrep: return "noisePrep"
        }
    }

    @ViewBuilder
    private func screenView( // swiftlint:disable:this cyclomatic_complexity
        for screen: Voting.State.Screen
    ) -> some View {
        switch screen {
        case .howToVote:
            HowToVoteView(store: store)
        case .loading:
            ProgressView()
        case .noRounds:
            NoRoundsView(store: store)
        case .pollsList:
            PollsListView(store: store)
        case .delegationSigning:
            DelegationSigningView(store: store)
        case .proposalList:
            ProposalListView(store: store, mode: .voting)
                .transition(.opacity)
        case .reviewVotes:
            ProposalListView(store: store, mode: .review)
        case .confirmSubmission:
            ConfirmSubmissionView(store: store)
        case .proposalDetail:
            if let proposal = store.selectedProposal {
                ProposalDetailView(store: store, proposal: proposal)
                    .id(proposal.id)
                    .transition(.push(from: .trailing))
            }
        case .ineligible:
            IneligibleView(store: store)
        case .tallying:
            TallyingView(store: store)
        case .results:
            ResultsView(store: store)
        case .error(let message):
            VotingErrorView(store: store, errorMessage: message)
        case .configError(let message):
            VotingConfigErrorView(store: store, errorMessage: message)
        case .configSettings:
            if let configSettingsStore = store.scope(state: \.configSettings, action: \.configSettings) {
                VotingConfigSettingsView(store: configSettingsStore)
            }
        case .walletSyncing:
            WalletSyncingView(store: store)
        case .noisePrep:
            NoisePrepView(store: store)
        }
    }
}

// MARK: - Zodl Noise

struct NoisePrepView: View {
    @Environment(\.colorScheme)
    var colorScheme

    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summarySection
                    actionSection
                    noteListSection
                    advancedSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .applyScreenBackground()
            .screenTitle("Zodl Noise")
            .zashiBack { store.send(.goBack) }
            .onAppear { store.send(.noisePrepRefreshTapped) }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .zFont(.semiBold, size: 20, style: Design.Text.primary)
                Spacer()
                if store.noisePrep.isLoading {
                    ProgressView()
                } else {
                    Button {
                        store.send(.noisePrepRefreshTapped)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Refresh notes")
                }
            }

            metricRow("Total", value: "\(VoteNoiseFeature.zecString(store.noisePrep.totalValue)) ZEC")
            metricRow("Count", value: "\(store.noisePrep.notes.count)")
            metricRow("0.125 ZEC notes", value: "\(store.noisePrep.exactBallotNoteCount)")
            metricRow("Target notes", value: "\(store.noisePrep.targetNoteCount)")

            if let snapshotHeight = store.noisePrep.snapshotHeight {
                Text("Scan height \(snapshotHeight)")
                    .zFont(.medium, size: 13, style: Design.Text.tertiary)
            }

            if let status = store.noisePrep.statusMessage {
                Text(status)
                    .zFont(.medium, size: 14, style: Design.Text.tertiary)
            }

            if let error = store.noisePrep.errorMessage {
                Text(error)
                    .zFont(.medium, size: 14, style: Design.Utility.ErrorRed._500)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: Design.Radius._md)
                .fill(Design.Surfaces.bgAlt.color(colorScheme))
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let pendingOperation = store.noisePrep.pendingOperation {
                VStack(alignment: .leading, spacing: 8) {
                    Text(pendingOperation.kind.title)
                        .zFont(.semiBold, size: 16, style: Design.Text.primary)
                    Text(pendingOperation.summary)
                        .zFont(.medium, size: 14, style: Design.Text.tertiary)
                    Text("Fee: \(pendingOperation.fee.decimalZashiFullFormatted()) ZEC")
                        .zFont(.medium, size: 14, style: Design.Text.tertiary)
                }
                Button {
                    store.send(.noisePrepConfirmProposalTapped)
                } label: {
                    HStack {
                        if store.noisePrep.isSubmitting {
                            ProgressView()
                        }
                        Text("Confirm")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.noisePrep.isSubmitting)

                Button("Cancel") {
                    store.send(.noisePrepCancelProposalTapped)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(store.noisePrep.isSubmitting)
            } else {
                Button {
                    store.send(.noisePrepSplitTapped)
                } label: {
                    HStack {
                        if store.noisePrep.isPreparingProposal {
                            ProgressView()
                        }
                        Text("Split to target notes")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.noisePrep.isLoading || store.noisePrep.isPreparingProposal || store.noisePrep.notes.isEmpty)

                Button("Normalize notes") {
                    store.send(.noisePrepNormalizeTapped)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(store.noisePrep.isLoading || store.noisePrep.isPreparingProposal || store.noisePrep.notes.isEmpty)
            }
        }
    }

    private var noteListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current Notes")
                .zFont(.semiBold, size: 16, style: Design.Text.primary)

            if store.noisePrep.notes.isEmpty {
                Text("No notes found.")
                    .zFont(.medium, size: 14, style: Design.Text.tertiary)
            } else {
                ForEach(Array(store.noisePrep.notes.sorted { $0.position < $1.position }.enumerated()), id: \.element.position) { _, note in
                    HStack {
                        Text("#\(note.position)")
                            .zFont(.medium, size: 13, style: Design.Text.tertiary)
                        Spacer()
                        Text("\(VoteNoiseFeature.zecString(note.value)) ZEC")
                            .zFont(.semiBold, size: 14, style: Design.Text.primary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var advancedSection: some View {
        DisclosureGroup("Advanced") {
            VStack(alignment: .leading, spacing: 10) {
                TextField(
                    "0.125",
                    text: Binding(
                        get: { store.noisePrep.targetNoteValueText },
                        set: { store.send(.noisePrepTargetNoteValueChanged($0)) }
                    )
                )
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

                Button("Reset to 0.125 ZEC") {
                    store.send(.noisePrepResetTargetNoteValue)
                }
                .buttonStyle(.bordered)

                Text("Split uses this target. Voting always uses exact 0.125 ZEC notes for noise VANs.")
                    .zFont(.medium, size: 13, style: Design.Text.tertiary)
            }
            .padding(.top, 8)
        }
        .zFont(.semiBold, size: 14, style: Design.Text.primary)
    }

    private func metricRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .zFont(.medium, size: 14, style: Design.Text.tertiary)
            Spacer()
            Text(value)
                .zFont(.semiBold, size: 14, style: Design.Text.primary)
        }
    }
}

struct VotingBlockingBackdrop: View {
    let store: StoreOf<Voting>

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PollsListSkeletonCard()
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .applyScreenBackground()
        .screenTitle(String(localizable: .coinVoteCommonScreenTitle))
        .zashiBack { store.send(.dismissFlow) }
    }
}

// MARK: - No Rounds

struct NoRoundsView: View {
    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            VotingBlockingBackdrop(store: store)
                .votingBlockingSheet(
                    isActive: { store.currentScreen == .noRounds },
                    visualStyle: .unverifiedWarning,
                    onExit: { store.send(.dismissFlow) }
                ) { dismiss in
                    VotingSheetContent(
                        iconSystemName: "exclamationmark.circle",
                        iconStyle: Design.Utility.ErrorRed._500,
                        title: String(localizable: .coinVotePollsListEmptyTitle),
                        message: String(localizable: .coinVotePollsListEmptyMessage),
                        primary: .init(title: String(localizable: .coinVoteCommonGotIt), style: .primary) {
                            dismiss()
                        },
                        secondary: .init(title: String(localizable: .coinVoteCommonRefresh), style: .secondary) {
                            store.send(.retryLoadRounds)
                        },
                        visualStyle: .unverifiedWarning
                    )
                }
        }
    }
}

// MARK: - Placeholders

extension Voting.State {
    static let initial = Voting.State()
}

extension StoreOf<Voting> {
    static let placeholder = StoreOf<Voting>(
        initialState: .initial
    ) {
        Voting()
    }
}

#Preview {
    NavigationStack {
        VotingView(store: .placeholder)
    }
}

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
                    summaryCard
                    if store.noisePrep.isSyncing {
                        syncingBanner
                    } else if let error = store.noisePrep.errorMessage {
                        banner(text: error, style: .error)
                    } else if let status = store.noisePrep.statusMessage {
                        banner(text: status, style: .info)
                    }
                    actionSection
                    noteListCard
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .applyScreenBackground()
            .screenTitle("Split / Consolidate Notes")
            // Noise Prep is now the root screen of the voting flow when
            // entered from Settings → Split / Consolidate Notes, so backing
            // out should dismiss the whole voting flow rather than pop
            // within it.
            .zashiBack { store.send(.dismissFlow) }
            .onAppear { store.send(.noisePrepRefreshTapped) }
        }
    }

    // MARK: Summary card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .zFont(.semiBold, size: 20, style: Design.Text.primary)
                    if let snapshotHeight = store.noisePrep.snapshotHeight {
                        Text("Scan height \(snapshotHeight)")
                            .zFont(.medium, size: 13, style: Design.Text.tertiary)
                    }
                }
                Spacer()
                refreshControl
            }

            VStack(spacing: 10) {
                metricRow("Total", value: "\(VoteNoiseFeature.zecString(store.noisePrep.totalValue)) ZEC")
                divider
                metricRow("Wallet notes", value: "\(store.noisePrep.notes.count)")
                divider
                metricRow(
                    "Notes ≥ \(VoteNoiseFeature.zecString(store.noisePrep.displayTargetNoteValue)) ZEC",
                    value: "\(store.noisePrep.notesAtOrAboveTargetCount)",
                    emphasize: true
                )
            }

            targetControl
        }
        .padding(Design.Spacing._xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.Surfaces.bgPrimary.color(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius._2xl))
        .overlay(
            RoundedRectangle(cornerRadius: Design.Radius._2xl)
                .stroke(Design.Surfaces.strokeSecondary.color(colorScheme), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var refreshControl: some View {
        if store.noisePrep.isLoading {
            ProgressView()
                .frame(width: 36, height: 36)
        } else {
            Button {
                store.send(.noisePrepRefreshTapped)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Design.Text.primary.color(colorScheme))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Design.Surfaces.bgSecondary.color(colorScheme))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh notes")
        }
    }

    private var targetControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Target note value")
                    .zFont(.medium, size: 13, style: Design.Text.tertiary)
                Spacer()
                if store.noisePrep.targetNoteValue != VoteNoiseFeature.defaultTargetNoteValue {
                    Button("Reset") {
                        store.send(.noisePrepResetTargetNoteValue)
                    }
                    .zFont(.semiBold, size: 13, style: Design.Btns.Ghost.fg)
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                TextField(
                    VoteNoiseFeature.zecString(VoteNoiseFeature.defaultTargetNoteValue),
                    text: Binding(
                        get: { store.noisePrep.targetNoteValueText },
                        set: { store.send(.noisePrepTargetNoteValueChanged($0)) }
                    )
                )
                .keyboardType(.decimalPad)
                .zFont(.semiBold, size: 14, style: Design.Text.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: Design.Radius._md)
                        .fill(Design.Surfaces.bgSecondary.color(colorScheme))
                )
                Text("ZEC")
                    .zFont(.medium, size: 14, style: Design.Text.tertiary)
            }
            Text("Split uses this target. Voting always uses exact 0.125 ZEC notes.")
                .zFont(.medium, size: 12, style: Design.Text.tertiary)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Design.Surfaces.strokeSecondary.color(colorScheme))
            .frame(height: 1)
    }

    private func metricRow(_ title: String, value: String, emphasize: Bool = false) -> some View {
        HStack {
            Text(title)
                .zFont(.medium, size: 14, style: Design.Text.tertiary)
            Spacer()
            Text(value)
                .zFont(
                    emphasize ? .semiBold : .medium,
                    size: emphasize ? 16 : 14,
                    style: Design.Text.primary
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: Banner

    private enum BannerStyle {
        case info
        case error
    }

    private func banner(text: String, style: BannerStyle) -> some View {
        let palette = bannerPalette(for: style)
        return Text(text)
            .zFont(.medium, size: 13, style: palette.fg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(palette.bg.color(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Design.Radius._md))
            .overlay(
                RoundedRectangle(cornerRadius: Design.Radius._md)
                    .stroke(palette.stroke.color(colorScheme), lineWidth: 1)
            )
    }

    private func bannerPalette(for style: BannerStyle) -> (fg: Colorable, bg: Colorable, stroke: Colorable) {
        switch style {
        case .info:
            return (Design.Text.primary, Design.Surfaces.bgSecondary, Design.Surfaces.strokeSecondary)
        case .error:
            return (Design.Utility.ErrorRed._700, Design.Utility.ErrorRed._50, Design.Utility.ErrorRed._200)
        }
    }

    private var syncingBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text("Syncing wallet…")
                    .zFont(.semiBold, size: 14, style: Design.Text.primary)
                Text("Waiting for your transaction to mine and the wallet to scan. Takes ~1–2 minutes on mainnet.")
                    .zFont(.medium, size: 12, style: Design.Text.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Design.Surfaces.bgSecondary.color(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius._md))
        .overlay(
            RoundedRectangle(cornerRadius: Design.Radius._md)
                .stroke(Design.Surfaces.strokeSecondary.color(colorScheme), lineWidth: 1)
        )
    }

    // MARK: Action section

    @ViewBuilder
    private var actionSection: some View {
        if let pending = store.noisePrep.pendingOperation {
            pendingProposalCard(pending)
        } else {
            VStack(spacing: 10) {
                ZashiButton(splitButtonTitle, type: .primary) {
                    store.send(.noisePrepSplitTapped)
                }
                .disabled(splitDisabled)

                ZashiButton(consolidateButtonTitle, type: .secondary) {
                    store.send(.noisePrepNormalizeTapped)
                }
                .disabled(consolidateDisabled)
            }
        }
    }

    private var splitButtonTitle: String {
        if store.noisePrep.isPreparingProposal {
            return "Preparing…"
        }
        let targetText = VoteNoiseFeature.zecString(store.noisePrep.displayTargetNoteValue)
        guard let projected = store.noisePrep.projectedSplitOutputCount else {
            return "Split into \(targetText) ZEC notes"
        }
        if let gain = store.noisePrep.projectedSplitNetGain, gain <= 0 {
            return "Already at \(projected) × \(targetText) ZEC"
        }
        return "Split into \(projected) × \(targetText) ZEC"
    }

    private var splitDisabled: Bool {
        store.noisePrep.isLoading
            || store.noisePrep.isPreparingProposal
            || store.noisePrep.notes.isEmpty
            || store.noisePrep.projectedSplitOutputCount == nil
            || (store.noisePrep.projectedSplitNetGain ?? 0) <= 0
    }

    private var consolidateDisabled: Bool {
        store.noisePrep.isLoading
            || store.noisePrep.isPreparingProposal
            || store.noisePrep.notes.isEmpty
            || !store.noisePrep.canConsolidateMeaningfully
    }

    private var consolidateButtonTitle: String {
        if store.noisePrep.isPreparingProposal {
            return "Preparing…"
        }
        guard store.noisePrep.canConsolidateMeaningfully else {
            return "Already consolidated"
        }
        return "Consolidate notes"
    }

    private func pendingProposalCard(_ pending: Voting.State.NoisePrepPendingOperation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(pending.kind.title)
                    .zFont(.semiBold, size: 16, style: Design.Text.primary)
                Text(pending.summary)
                    .zFont(.medium, size: 14, style: Design.Text.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text("Fee")
                    .zFont(.medium, size: 14, style: Design.Text.tertiary)
                Spacer()
                Text("\(pending.fee.decimalZashiFullFormatted()) ZEC")
                    .zFont(.semiBold, size: 14, style: Design.Text.primary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Design.Surfaces.bgSecondary.color(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Design.Radius._md))

            VStack(spacing: 10) {
                ZashiButton(
                    store.noisePrep.isSubmitting ? "Submitting…" : "Confirm",
                    type: .primary
                ) {
                    store.send(.noisePrepConfirmProposalTapped)
                }
                .disabled(store.noisePrep.isSubmitting)

                ZashiButton(
                    "Cancel",
                    type: .tertiary
                ) {
                    store.send(.noisePrepCancelProposalTapped)
                }
                .disabled(store.noisePrep.isSubmitting)
            }
        }
        .padding(Design.Spacing._xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.Surfaces.bgPrimary.color(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius._2xl))
        .overlay(
            RoundedRectangle(cornerRadius: Design.Radius._2xl)
                .stroke(Design.Surfaces.strokeSecondary.color(colorScheme), lineWidth: 1)
        )
    }

    // MARK: Note list

    private var noteListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Current notes")
                    .zFont(.semiBold, size: 16, style: Design.Text.primary)
                Spacer()
                if store.noisePrep.dustCount > 0 {
                    dustToggle
                }
            }

            let displayed = store.noisePrep.displayedNotes
            if displayed.isEmpty {
                Text(noteListEmptyMessage)
                    .zFont(.medium, size: 14, style: Design.Text.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                let sortedNotes = displayed.sorted { $0.value > $1.value }
                VStack(spacing: 0) {
                    ForEach(Array(sortedNotes.enumerated()), id: \.element.position) { offset, note in
                        if offset > 0 {
                            divider
                        }
                        noteRow(note)
                    }
                }
            }

            if store.noisePrep.dustCount > 0 {
                Text(dustFootnote)
                    .zFont(.medium, size: 12, style: Design.Text.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Design.Spacing._xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.Surfaces.bgPrimary.color(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius._2xl))
        .overlay(
            RoundedRectangle(cornerRadius: Design.Radius._2xl)
                .stroke(Design.Surfaces.strokeSecondary.color(colorScheme), lineWidth: 1)
        )
    }

    private var dustToggle: some View {
        Button {
            store.send(.noisePrepToggleShowDust(!store.noisePrep.showDustNotes))
        } label: {
            HStack(spacing: 4) {
                Image(systemName: store.noisePrep.showDustNotes ? "eye.slash" : "eye")
                    .font(.system(size: 12, weight: .semibold))
                Text(store.noisePrep.showDustNotes ? "Hide dust" : "Show dust (\(store.noisePrep.dustCount))")
                    .zFont(.semiBold, size: 13, style: Design.Btns.Ghost.fg)
            }
            .foregroundStyle(Design.Btns.Ghost.fg.color(colorScheme))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.noisePrep.showDustNotes ? "Hide dust notes" : "Show \(store.noisePrep.dustCount) dust notes")
    }

    private var noteListEmptyMessage: String {
        if store.noisePrep.notes.isEmpty {
            return "No wallet notes found at this scan height."
        }
        // We have notes but they're all dust and the toggle is off.
        return "Only dust notes remain. Tap Show dust to view them."
    }

    private var dustFootnote: String {
        let dustZec = VoteNoiseFeature.zecString(store.noisePrep.dustValue)
        let threshold = VoteNoiseFeature.zecString(VoteNoiseFeature.dustThresholdZatoshi)
        return "Hidden by default: \(store.noisePrep.dustCount) note(s) ≤ \(threshold) ZEC totalling \(dustZec) ZEC — too small to spend on their own."
    }

    private func noteRow(_ note: NoteInfo) -> some View {
        HStack {
            Text("#\(note.position)")
                .zFont(.medium, size: 13, style: Design.Text.tertiary)
                .lineLimit(1)
            Spacer()
            Text("\(VoteNoiseFeature.zecString(note.value)) ZEC")
                .zFont(.semiBold, size: 14, style: Design.Text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
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

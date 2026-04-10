//
//  PIRSetupStore.swift
//  Zashi
//

import ComposableArchitecture

import Generated
import WalletStorage
import Models

@Reducer
public struct PIRSetup {
    @ObservableState
    public struct State: Equatable {
        public enum SettingsOptions: CaseIterable {
            case optIn
            case optOut

            public func title() -> String {
                switch self {
                case .optIn: return String(localizable: .currencyConversionEnable)
                case .optOut: return String(localizable: .currencyConversionLearnMoreOptionDisable)
                }
            }

            public func subtitle() -> String {
                switch self {
                case .optIn: return "Speed up transactions by checking spendability in the background using private information retrieval."
                case .optOut: return "Disable background spendability checks. Transactions may take longer to confirm as spendable."
                }
            }

            public func icon() -> ImageAsset {
                switch self {
                case .optIn: return Asset.Assets.check
                case .optOut: return Asset.Assets.buttonCloseX
                }
            }
        }

        public var activeSettingsOption: SettingsOptions?
        public var currentSettingsOption = SettingsOptions.optOut
        public var isSettingsView: Bool = false
        @Shared(.inMemory(.pirUserEnabled)) public var pirUserEnabled: Bool = true

        public var isSaveButtonDisabled: Bool {
            currentSettingsOption == activeSettingsOption
        }

        public init(
            activeSettingsOption: SettingsOptions? = nil,
            currentSettingsOption: SettingsOptions = .optOut,
            isSettingsView: Bool = false
        ) {
            self.activeSettingsOption = activeSettingsOption
            self.currentSettingsOption = currentSettingsOption
            self.isSettingsView = isSettingsView
        }
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<PIRSetup.State>)
        case backToHomeTapped
        case onAppear
        case saveChangesTapped
        case settingsOptionTapped(State.SettingsOptions)
    }

    @Dependency(\.walletStorage) var walletStorage

    public init() { }

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .onAppear:
                if let pirEnabled = walletStorage.exportPIRFlag() {
                    let option: State.SettingsOptions = pirEnabled ? .optIn : .optOut
                    state.activeSettingsOption = option
                    state.currentSettingsOption = option
                } else {
                    state.activeSettingsOption = .optIn
                    state.currentSettingsOption = .optIn
                }
                return .none

            case .backToHomeTapped:
                return .none

            case .binding:
                return .none

            case .settingsOptionTapped(let newOption):
                state.currentSettingsOption = newOption
                return .none

            case .saveChangesTapped:
                let newFlag = state.currentSettingsOption == .optIn
                try? walletStorage.importPIRFlag(newFlag)
                state.$pirUserEnabled.withLock { $0 = newFlag }
                state.activeSettingsOption = state.currentSettingsOption
                return .send(.backToHomeTapped)
            }
        }
    }
}

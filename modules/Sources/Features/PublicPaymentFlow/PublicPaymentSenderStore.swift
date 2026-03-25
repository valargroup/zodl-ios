//
//  PublicPaymentSenderStore.swift
//  Zashi
//

import ComposableArchitecture
import Foundation
import PaymentServiceClient

@Reducer
public struct PublicPaymentSender {
    private enum CancelID { case stepping }

    @ObservableState
    public struct State: Equatable {
        public enum RelayStep: Equatable {
            case confirm
            case talkingToRelay
            case sawCommunication
            case relayerFinished
            case sending
            case sent
        }

        public var recipientAddress: String = ""
        public var amount: String = ""
        public var relayStep: RelayStep = .confirm
        public var relayFee: String = "0.0001"
        public var error: String?

        public var totalAmount: String {
            guard let amt = Double(amount), let fee = Double(relayFee) else { return amount }
            return String(format: "%.4f", amt + fee)
        }

        public init() {}
        public static let initial = State()
    }

    public enum Action: Equatable {
        case confirmTapped
        case advanceStep
        case closeTapped
        case backTapped
    }

    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .confirmTapped:
                state.relayStep = .talkingToRelay
                return .run { send in
                    try await clock.sleep(for: .seconds(2))
                    await send(.advanceStep)
                }
                .cancellable(id: CancelID.stepping)

            case .advanceStep:
                switch state.relayStep {
                case .talkingToRelay:
                    state.relayStep = .sawCommunication
                    return .run { send in
                        try await clock.sleep(for: .seconds(2))
                        await send(.advanceStep)
                    }
                    .cancellable(id: CancelID.stepping)

                case .sawCommunication:
                    state.relayStep = .relayerFinished
                    return .run { send in
                        try await clock.sleep(for: .seconds(2))
                        await send(.advanceStep)
                    }
                    .cancellable(id: CancelID.stepping)

                case .relayerFinished:
                    state.relayStep = .sending
                    return .run { send in
                        try await clock.sleep(for: .seconds(1.5))
                        await send(.advanceStep)
                    }
                    .cancellable(id: CancelID.stepping)

                case .sending:
                    state.relayStep = .sent
                    return .cancel(id: CancelID.stepping)

                default:
                    return .none
                }

            case .closeTapped, .backTapped:
                return .cancel(id: CancelID.stepping)
            }
        }
    }
}

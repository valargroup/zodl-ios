//
//  PublicPaymentSenderStore.swift
//  Zashi
//

import ComposableArchitecture
import Foundation
import PaymentServiceClient

@Reducer
public struct PublicPaymentSender {
    private enum CancelID { case polling }

    @ObservableState
    public struct State: Equatable {
        public enum RelayStep: Equatable {
            case confirm
            case talkingToRelay
            case sawCommunication
            case relayerFinished
            case sending
            case sent
            case failed
        }

        public var recipientAddress: String = ""
        public var amount: String = ""
        public var relayStep: RelayStep = .confirm
        public var relayId: String?
        public var encapsId: String?
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
        case relayResolved(RegisterRelayResponse)
        case encapsPosted(RelayStatusResponse)
        case pollRelayStatus
        case statusUpdated(RelayStatusResponse)
        case failed(String)
        case closeTapped
        case backTapped
    }

    @Dependency(\.paymentServiceClient) var paymentServiceClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .confirmTapped:
                state.relayStep = .talkingToRelay
                let address = state.recipientAddress
                let amount = state.amount

                // Step 1: Resolve the pub1 address to a relay ID
                return .run { send in
                    let relay = try await paymentServiceClient.resolveRelayByAddress(address)
                    await send(.relayResolved(relay))
                } catch: { error, send in
                    await send(.failed(error.localizedDescription))
                }

            case let .relayResolved(relay):
                state.relayId = relay.relayId
                let relayId = relay.relayId
                let amount = state.amount
                let address = state.recipientAddress

                // Step 2: Post ML-KEM ciphertext to the relay
                return .run { send in
                    let request = RelayEncapsRequest(
                        ciphertext: "mock-mlkem-ct-\(UUID().uuidString.prefix(8))",
                        amount: amount,
                        senderAddress: address
                    )
                    let response = try await paymentServiceClient.postRelayEncaps(relayId, request)
                    await send(.encapsPosted(response))
                } catch: { error, send in
                    await send(.failed(error.localizedDescription))
                }

            case let .encapsPosted(response):
                state.encapsId = response.encapsId
                // Step 3: Start polling for relay status progression
                return .run { send in
                    try await clock.sleep(for: .seconds(2))
                    await send(.pollRelayStatus)
                }
                .cancellable(id: CancelID.polling)

            case .pollRelayStatus:
                guard let relayId = state.relayId,
                      let encapsId = state.encapsId else { return .none }

                return .run { [relayId, encapsId] send in
                    let response = try await paymentServiceClient.getRelayStatus(relayId, encapsId)
                    await send(.statusUpdated(response))
                } catch: { error, send in
                    await send(.failed(error.localizedDescription))
                }

            case let .statusUpdated(response):
                // Map server step numbers to UI steps
                switch response.step {
                case 1:
                    state.relayStep = .talkingToRelay
                case 2:
                    state.relayStep = .sawCommunication
                case 3:
                    state.relayStep = .relayerFinished
                case 4:
                    state.relayStep = .sent
                    return .cancel(id: CancelID.polling)
                default:
                    break
                }

                // Keep polling if not done
                if response.step < 4 {
                    return .run { send in
                        try await clock.sleep(for: .seconds(2))
                        await send(.pollRelayStatus)
                    }
                    .cancellable(id: CancelID.polling)
                }
                return .none

            case let .failed(message):
                state.error = message
                state.relayStep = .failed
                return .cancel(id: CancelID.polling)

            case .closeTapped, .backTapped:
                return .cancel(id: CancelID.polling)
            }
        }
    }
}

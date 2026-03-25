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
        case encapsPosted(RelayStatusResponse)
        case encapsFailed(String)
        case pollRelayStatus
        case statusUpdated(RelayStatusResponse)
        case pollFailed(String)
        case sendCompleted
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

                // Extract relay ID from pub1 address by querying relay
                // In a real app, the pub1 address would encode the relay ID
                // For the mock, we derive it from the address
                let address = state.recipientAddress
                let amount = state.amount

                return .run { send in
                    // Post encapsulation to relay
                    // For the mock, we need to find the relay ID from the address
                    // The mock service resolves pub1 addresses through the relay store
                    let request = RelayEncapsRequest(
                        ciphertext: "mock-mlkem-ct-\(UUID().uuidString.prefix(8))",
                        amount: amount,
                        senderAddress: address
                    )

                    // Try to find a relay matching this address
                    // For demo purposes, we'll use a hardcoded relay ID approach
                    // In production, the address itself encodes the relay info
                    let relayId = "demo-relay"
                    let response = try await paymentServiceClient.postRelayEncaps(relayId, request)
                    await send(.encapsPosted(response))
                } catch: { error, send in
                    await send(.encapsFailed(error.localizedDescription))
                }

            case let .encapsPosted(response):
                state.encapsId = response.encapsId
                state.relayStep = .talkingToRelay
                // Start polling
                return .run { send in
                    try await clock.sleep(for: .seconds(2))
                    await send(.pollRelayStatus)
                }
                .cancellable(id: CancelID.polling)

            case let .encapsFailed(message):
                state.error = message
                state.relayStep = .confirm
                return .none

            case .pollRelayStatus:
                guard let relayId = state.relayId ?? Optional("demo-relay"),
                      let encapsId = state.encapsId else { return .none }

                return .run { send in
                    let response = try await paymentServiceClient.getRelayStatus(relayId, encapsId)
                    await send(.statusUpdated(response))
                } catch: { error, send in
                    await send(.pollFailed(error.localizedDescription))
                }

            case let .statusUpdated(response):
                // Map the server step to our UI step
                switch response.step {
                case 1:
                    state.relayStep = .talkingToRelay
                case 2:
                    state.relayStep = .sawCommunication
                case 3:
                    state.relayStep = .relayerFinished
                case 4:
                    state.relayStep = .sent
                    return .send(.sendCompleted)
                default:
                    break
                }

                // Continue polling if not done
                if response.step < 4 {
                    return .run { send in
                        try await clock.sleep(for: .seconds(2))
                        await send(.pollRelayStatus)
                    }
                    .cancellable(id: CancelID.polling)
                }
                return .none

            case let .pollFailed(message):
                state.error = message
                return .none

            case .sendCompleted:
                state.relayStep = .sent
                return .cancel(id: CancelID.polling)

            case .closeTapped, .backTapped:
                return .cancel(id: CancelID.polling)
            }
        }
    }
}

//
//  PublicPaymentSenderView.swift
//  Zashi
//

import SwiftUI
import ComposableArchitecture
import Generated
import UIComponents

public struct PublicPaymentSenderView: View {
    @Environment(\.colorScheme) var colorScheme
    let store: StoreOf<PublicPaymentSender>
    let tokenName: String

    public init(store: StoreOf<PublicPaymentSender>, tokenName: String) {
        self.store = store
        self.tokenName = tokenName
    }

    public var body: some View {
        WithPerceptionTracking {
            switch store.relayStep {
            case .confirm:
                confirmView()
            case .talkingToRelay:
                relayProcessingView(
                    title: "Relaying...",
                    subtitle: "Talking to relayer"
                )
            case .sawCommunication:
                relayProcessingView(
                    title: "Relaying...",
                    subtitle: "Saw relayer communication to Bob in mempool"
                )
            case .relayerFinished, .sending:
                relayProcessingView(
                    title: "Sending...",
                    subtitle: "Sending the full payment to Bob.\nThe relayer has finished the setup."
                )
            case .sent:
                sentView()
            case .failed:
                failedView()
            }
        }
        .applyScreenBackground()
    }

    // MARK: - Confirm (PPS1)

    @ViewBuilder private func confirmView() -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Total Amount")
                    .zFont(size: 16, style: Design.Text.tertiary)

                Text("\(store.totalAmount) \(tokenName)")
                    .zFont(.bold, size: 42, style: Design.Text.primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .padding(.top, 40)

            // Details card
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Send to")
                        .zFont(size: 14, style: Design.Text.tertiary)
                    Text(store.recipientAddress)
                        .zFont(fontFamily: .robotoMono, size: 13, style: Design.Text.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                HStack {
                    Text("Amount to receive:")
                        .zFont(size: 15, style: Design.Text.primary)
                    Spacer()
                    Text("\(store.amount)")
                        .zFont(.semiBold, size: 15, style: Design.Text.primary)
                }

                HStack {
                    Text("Relayer Fee")
                        .zFont(size: 15, style: Design.Text.primary)
                    Spacer()
                    Text("\(store.relayFee)")
                        .zFont(.semiBold, size: 15, style: Design.Text.primary)
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Design.Surfaces.bgSecondary.color(colorScheme))
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            Spacer()

            ZashiButton("Send") {
                store.send(.confirmTapped)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .screenTitle("CONFIRMATION")
    }

    // MARK: - Relay Processing (PPS2, PPS3, PPS4)

    @ViewBuilder private func relayProcessingView(title: String, subtitle: String) -> some View {
        VStack(spacing: 0) {
            Spacer()

            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
                .padding(.bottom, 24)

            Text(title)
                .zFont(.semiBold, size: 28, style: Design.Text.primary)

            Text(subtitle)
                .zFont(size: 14, style: Design.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Sent

    @ViewBuilder private func sentView() -> some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Design.Text.primary.color(colorScheme))
                .padding(.bottom, 16)

            Text("Sent!")
                .zFont(.semiBold, size: 28, style: Design.Text.primary)

            Text("Your payment was sent via the relayer.\nThe recipient will see it when they come online.")
                .zFont(size: 14, style: Design.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 32)

            Spacer()

            ZashiButton("Close") {
                store.send(.closeTapped)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Failed

    @ViewBuilder private func failedView() -> some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Design.Utility.ErrorRed._600.color(colorScheme))
                .padding(.bottom, 16)

            Text("Relay Error")
                .zFont(.semiBold, size: 22, style: Design.Text.primary)

            if let error = store.error {
                Text(error)
                    .zFont(size: 14, style: Design.Text.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.horizontal, 32)
            }

            Spacer()

            ZashiButton("Close") {
                store.send(.closeTapped)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Placeholder

extension PublicPaymentSender {
    public static let placeholder = StoreOf<PublicPaymentSender>(
        initialState: .initial
    ) {
        PublicPaymentSender()
    }
}

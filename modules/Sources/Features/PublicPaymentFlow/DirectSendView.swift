//
//  DirectSendView.swift
//  Zashi
//
//  Send confirmation for Linkable Dynamic Address (dyn1) sends.
//  Simpler than the relay flow — PIR resolve → send → done.
//

import SwiftUI
import ComposableArchitecture
import Generated
import UIComponents

public struct DirectSendView: View {
    @Environment(\.colorScheme) var colorScheme
    let store: StoreOf<DirectSend>
    let tokenName: String

    public init(store: StoreOf<DirectSend>, tokenName: String) {
        self.store = store
        self.tokenName = tokenName
    }

    public var body: some View {
        WithPerceptionTracking {
            switch store.step {
            case .confirm:
                confirmView()
            case .resolving:
                processingView(
                    title: "Resolving...",
                    subtitle: "Looking up recipient via PIR"
                )
            case .sending:
                processingView(
                    title: "Sending...",
                    subtitle: "Sending shielded payment"
                )
            case .sent:
                sentView()
            case .failed:
                failedView()
            }
        }
        .applyScreenBackground()
    }

    // MARK: - Confirm

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
                    Text("Amount:")
                        .zFont(size: 15, style: Design.Text.primary)
                    Spacer()
                    Text(store.amount)
                        .zFont(.semiBold, size: 15, style: Design.Text.primary)
                }

                HStack {
                    Text("Network Fee")
                        .zFont(size: 15, style: Design.Text.primary)
                    Spacer()
                    Text(store.fee)
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
                store.send(.sendTapped)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .screenTitle("CONFIRMATION")
    }

    // MARK: - Processing

    @ViewBuilder private func processingView(title: String, subtitle: String) -> some View {
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

            Text("Your shielded payment was sent successfully.")
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

            Text("Send Failed")
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

extension DirectSend {
    public static let placeholder = StoreOf<DirectSend>(
        initialState: .initial
    ) {
        DirectSend()
    }
}

//
//  PublicPaymentRegistrationView.swift
//  Zashi
//

import SwiftUI
import ComposableArchitecture
import Generated
import UIComponents

public struct PublicPaymentRegistrationView: View {
    @Environment(\.colorScheme) var colorScheme
    let store: StoreOf<PublicPaymentRegistration>

    public init(store: StoreOf<PublicPaymentRegistration>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            switch store.screen {
            case .register:
                registerView()
            case .registering:
                processingView()
            case .noFunds:
                noFundsView()
            case .showAddress:
                showAddressView()
            }
        }
        .applyScreenBackground()
        .screenTitle("PUBLIC PAYMENT")
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Register

    @ViewBuilder private func registerView() -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Text("Create Public\nPayment Address")
                    .zFont(.semiBold, size: 24, style: Design.Text.primary)
                    .multilineTextAlignment(.center)

                Text("Register your payment key with a relay service.\nAnyone can send you payments by scanning the QR\n— even while you're offline.")
                    .zFont(size: 14, style: Design.Text.tertiary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Text("📡")
                .font(.system(size: 48))
                .padding(.bottom, 32)

            Spacer()

            ZashiButton("Register with Relay") {
                store.send(.registerTapped)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Registering

    @ViewBuilder private func processingView() -> some View {
        VStack(spacing: 0) {
            Spacer()

            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
                .padding(.bottom, 24)

            Text("Registering...")
                .zFont(.semiBold, size: 28, style: Design.Text.primary)

            Text("Setting up your public payment address with the relay")
                .zFont(size: 14, style: Design.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - No Funds

    @ViewBuilder private func noFundsView() -> some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Design.Utility.WarningYellow._100.color(colorScheme))
                    .frame(width: 56, height: 56)
                Text("!")
                    .zFont(.bold, size: 28, style: Design.Text.primary)
            }
            .padding(.bottom, 16)

            Text("No ZEC in Wallet")
                .zFont(.bold, size: 22, style: Design.Text.primary)

            Text("Please send ZEC to your wallet before\ncreating a public payment address.")
                .zFont(size: 14, style: Design.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            Spacer()

            ZashiButton("Go to Home") {
                store.send(.goHomeTapped)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Show Address

    @ViewBuilder private func showAddressView() -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Your Public Payment Address")
                    .zFont(.semiBold, size: 24, style: Design.Text.primary)

                if let url = store.relayURL {
                    Text(url)
                        .zFont(size: 12, style: Design.Text.tertiary)
                }
            }
            .padding(.top, 24)

            Spacer()

            // QR placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .frame(width: 200, height: 200)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 48))
                            .foregroundStyle(Design.Text.tertiary.color(colorScheme))
                        Text("QR Code")
                            .zFont(.medium, size: 14, style: Design.Text.tertiary)
                    }
                }

            Spacer()

            VStack(spacing: 12) {
                ZashiButton("Share Link") {
                    store.send(.shareLinkTapped)
                }

                ZashiButton("Share QR Code", type: .ghost) {
                    store.send(.shareQRTapped)
                }

                ZashiButton("Revoke Public Payment Address", type: .destructive1) {
                    store.send(.revokeTapped)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Placeholder

extension PublicPaymentRegistration {
    public static let placeholder = StoreOf<PublicPaymentRegistration>(
        initialState: .initial
    ) {
        PublicPaymentRegistration()
    }
}

//
//  PIRSetupView.swift
//  Zashi
//

import SwiftUI
import ComposableArchitecture
import Generated
import UIComponents

public struct PIRSetupView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Perception.Bindable var store: StoreOf<PIRSetup>

    public init(store: StoreOf<PIRSetup>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            VStack {
                ScrollView {
                    settingsLayout()
                }
                .padding(.vertical, 1)

                Spacer()

                settingsFooter()
            }
            .onAppear { store.send(.onAppear) }
            .zashiBack() { store.send(.backToHomeTapped) }
        }
        .navigationBarTitleDisplayMode(.inline)
        .applyScreenBackground()
    }

    private func settingsLayout() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header()
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

            ForEach(PIRSetup.State.SettingsOptions.allCases, id: \.self) { option in
                Button {
                    store.send(.settingsOptionTapped(option))
                } label: {
                    HStack(alignment: .top, spacing: 0) {
                        optionIcon(option.icon().image)
                        optionVStack(option.title(), subtitle: option.subtitle())

                        Spacer()

                        if option == store.currentSettingsOption {
                            Circle()
                                .fill(Design.Checkboxes.onBg.color(colorScheme))
                                .frame(width: 20, height: 20)
                                .overlay {
                                    Circle()
                                        .fill(Design.Checkboxes.onFg.color(colorScheme))
                                        .frame(width: 10, height: 10)
                                }
                        } else {
                            Circle()
                                .fill(Design.Checkboxes.offBg.color(colorScheme))
                                .frame(width: 20, height: 20)
                                .overlay {
                                    Circle()
                                        .stroke(Design.Checkboxes.offStroke.color(colorScheme))
                                        .frame(width: 20, height: 20)
                                }
                        }
                    }
                    .frame(minHeight: 40)
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: Design.Radius._xl)
                            .stroke(Design.Surfaces.strokeSecondary.color(colorScheme))
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 8)
    }

    private func settingsFooter() -> some View {
        ZashiButton(String(localizable: .currencyConversionSaveBtn)) {
            store.send(.saveChangesTapped)
        }
        .disabled(store.isSaveButtonDisabled)
        .screenHorizontalPadding()
        .padding(.bottom, 24)
    }
}

// MARK: - UI components

extension PIRSetupView {
    private func icons() -> some View {
        RoundedRectangle(cornerRadius: Design.Radius._full)
            .fill(Design.Surfaces.bgTertiary.color(colorScheme))
            .frame(width: 64, height: 64)
            .overlay {
                Asset.Assets.Illustrations.lightning.image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
            }
            .padding(.top, 24)
    }

    private func title() -> some View {
        Text("Instant Spendability")
            .zFont(.semiBold, size: 24, style: Design.Text.primary)
    }

    private func optionVStack(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .zFont(.semiBold, size: 14, style: Design.Text.primary)

            Text(subtitle)
                .zFont(size: 14, style: Design.Text.tertiary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        }
        .padding(.trailing, 16)
    }

    private func optionIcon(_ icon: Image) -> some View {
        icon
            .zImage(size: 20, style: Design.Text.primary)
            .padding(10)
            .background {
                Circle()
                    .fill(Design.Surfaces.bgTertiary.color(colorScheme))
            }
            .padding(.trailing, 16)
    }

    private func header() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                icons()
                    .padding(.bottom, 24)
                    .padding(.top, 12)

                Spacer()
            }

            title()
                .padding(.bottom, 8)

            Text("Check whether received funds are spendable using private information retrieval, so your transactions can be sent faster.")
                .zFont(size: 14, style: Design.Text.tertiary)
                .padding(.bottom, 16)

            Text("This runs automatically in the background without revealing which notes belong to you.")
                .zFont(size: 14, style: Design.Text.tertiary)
                .padding(.bottom, 12)
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationView {
        PIRSetupView(store: PIRSetup.initial)
    }
}

// MARK: - Store

extension PIRSetup {
    public static var initial = StoreOf<PIRSetup>(
        initialState: .init(isSettingsView: true)
    ) {
        PIRSetup()
    }
}

// MARK: - Placeholders

extension PIRSetup.State {
    public static let initial = PIRSetup.State()
}

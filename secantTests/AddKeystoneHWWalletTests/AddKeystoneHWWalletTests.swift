//
//  AddKeystoneHWWalletTests.swift
//  secantTests
//
//  Created by Adam Tucker on 2026-04-04.
//

import XCTest
import ComposableArchitecture
import KeystoneSDK
import ZcashLightClientKit
import AddKeystoneHWWallet
import CoordFlows
import WalletBirthday
@testable import secant_testnet

@MainActor
final class AddKeystoneHWWalletTests: XCTestCase {

    private func makeZcashAccounts() throws -> ZcashAccounts {
        let json = """
        {
            "seedFingerprint": "aabb",
            "accounts": [{"ufvk": "utest1fakefvk", "index": 0, "name": "Test"}]
        }
        """
        return try JSONDecoder().decode(ZcashAccounts.self, from: Data(json.utf8))
    }

    // Verifies that .unlockTapped produces no state changes or effects in the reducer.
    // The coordinator intercepts this action to navigate to the birthday picker instead.
    func testUnlockTapped_isNoOp() async throws {
        let store = TestStore(
            initialState: .initial
        ) {
            AddKeystoneHWWallet()
        }

        store.dependencies.keystoneHandler = .noOp

        await store.send(.unlockTapped)

        await store.finish()
    }

    // Verifies that .importAccount calls sdkSynchronizer.importAccount.
    func testImportAccount_callsSDK() async throws {
        let importCalled = ActorIsolated(false)

        var state = AddKeystoneHWWallet.State.initial
        state.zcashAccounts = try makeZcashAccounts()

        let store = TestStore(
            initialState: state
        ) {
            AddKeystoneHWWallet()
        }

        store.dependencies.keystoneHandler = .noOp
        store.dependencies.sdkSynchronizer = .mocked(
            importAccount: { _, _, _, _, _, _ in
                await importCalled.setValue(true)
                return nil
            }
        )

        await store.send(.importAccount)

        await store.finish()

        let called = await importCalled.value
        XCTAssertTrue(called, "importAccount should call sdkSynchronizer.importAccount")
    }

    // Verifies the guard clause: when no zcashAccounts are set on state,
    // .importAccount produces no effects and does not call the SDK.
    func testImportAccount_withNoAccounts_isNoOp() async throws {
        let store = TestStore(
            initialState: .initial
        ) {
            AddKeystoneHWWallet()
        }

        store.dependencies.keystoneHandler = .noOp

        await store.send(.importAccount)

        await store.finish()
    }

    // End-to-end coordinator test: simulates the full birthday picker flow.
    // Sets up the navigation path with an account selection and a wallet birthday,
    // then sends .restoreTapped. Verifies the coordinator calls importAccount.
    func testCoordinator_restoreTapped_callsImportAccount() async throws {
        let importCalled = ActorIsolated(false)

        var accountSelectionState = AddKeystoneHWWallet.State.initial
        accountSelectionState.zcashAccounts = try makeZcashAccounts()

        var walletBirthdayState = WalletBirthday.State.initial
        walletBirthdayState.estimatedHeight = BlockHeight(1_700_000)

        var state = AddKeystoneHWWalletCoordFlow.State()
        state.path.append(.accountHWWalletSelection(accountSelectionState))
        state.path.append(.walletBirthday(walletBirthdayState))

        let walletBirthdayID = state.path.ids.last!

        let store = Store(
            initialState: state
        ) {
            AddKeystoneHWWalletCoordFlow()
        } withDependencies: {
            $0.keystoneHandler = .noOp
            $0.sdkSynchronizer = .mocked(
                importAccount: { _, _, _, _, _, _ in
                    await importCalled.setValue(true)
                    return nil
                }
            )
        }

        await store.send(.path(.element(id: walletBirthdayID, action: .walletBirthday(.restoreTapped))))

        // Give the effect time to run
        try await Task.sleep(nanoseconds: 200_000_000)

        let called = await importCalled.value
        XCTAssertTrue(called, "Coordinator should call importAccount")
    }
}

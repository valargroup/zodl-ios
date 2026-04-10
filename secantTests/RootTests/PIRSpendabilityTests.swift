//
//  PIRSpendabilityTests.swift
//  secantTests
//
//  Created by Roman on 2026-04-03.
//

import XCTest
import Combine
import ComposableArchitecture
import Root
import Models
@testable import secant_testnet
@testable import ZcashLightClientKit

@MainActor
class PIRSpendabilityTests: XCTestCase {

    private func stateWithPirEnabled() -> Root.State {
        var state = Root.State.initial
        var flags = state.walletConfig.flags
        flags[.pirSpendability] = true
        state.walletConfig = WalletConfig(flags: flags)
        return state
    }

    // MARK: - checkSpendabilityPIR

    func testCheckSpendabilityPIR_Success() async throws {
        let expectedResult = SpendabilityResult(
            earliestHeight: 100,
            latestHeight: 200,
            spentNoteIds: [1, 2],
            totalSpentValue: 50_000
        )

        let store = TestStore(
            initialState: stateWithPirEnabled()
        ) {
            Root()
        }
        store.exhaustivity = .off

        store.dependencies.sdkSynchronizer = .noOp
        store.dependencies.sdkSynchronizer.checkWalletSpendability = { _, _ in expectedResult }

        await store.send(.initialization(.checkSpendabilityPIR))

        await store.receive(.initialization(.checkSpendabilityPIRResult(expectedResult))) { state in
            state.pirSpendabilityResult = expectedResult
        }
    }

    func testCheckSpendabilityPIR_Failure() async throws {
        struct PIRError: Error {}

        let store = TestStore(
            initialState: stateWithPirEnabled()
        ) {
            Root()
        }
        store.exhaustivity = .off

        store.dependencies.sdkSynchronizer = .noOp
        store.dependencies.sdkSynchronizer.checkWalletSpendability = { _, _ in throw PIRError() }

        await store.send(.initialization(.checkSpendabilityPIR))

        await store.receive(.initialization(.checkSpendabilityPIRResult(nil)))
    }

    func testCheckSpendabilityPIR_NoOpWhenFlagOff() async throws {
        let store = TestStore(
            initialState: .initial
        ) {
            Root()
        }
        store.exhaustivity = .off

        store.dependencies.sdkSynchronizer = .noOp

        await store.send(.initialization(.checkSpendabilityPIR))
    }

    func testCheckSpendabilityPIRResult_TriggersTransactionRefresh() async throws {
        let result = SpendabilityResult(
            earliestHeight: 100,
            latestHeight: 200,
            spentNoteIds: [1],
            totalSpentValue: 10_000
        )

        let store = TestStore(
            initialState: .initial
        ) {
            Root()
        }
        store.exhaustivity = .off

        store.dependencies.sdkSynchronizer = .noOp

        await store.send(.initialization(.checkSpendabilityPIRResult(result))) { state in
            state.pirSpendabilityResult = result
        }

        await store.receive(.fetchTransactionsForTheSelectedAccount)
        await store.receive(.home(.walletBalances(.updateBalances)))
    }

    // MARK: - foundTransactions / syncReachedUpToDate do NOT trigger PIR

    func testFoundTransactions_DoesNotTriggerPIRCheck() async throws {
        let store = TestStore(
            initialState: stateWithPirEnabled()
        ) {
            Root()
        }
        store.exhaustivity = .off

        store.dependencies.sdkSynchronizer = .noOp

        await store.send(.foundTransactions([]))

        await store.receive(.fetchTransactionsForTheSelectedAccount)
    }

    func testSyncReachedUpToDate_DoesNotTriggerPIRCheck() async throws {
        let store = TestStore(
            initialState: stateWithPirEnabled()
        ) {
            Root()
        }
        store.exhaustivity = .off

        store.dependencies.sdkSynchronizer = .noOp

        await store.send(.syncReachedUpToDate)

        await store.receive(.fetchTransactionsForTheSelectedAccount)
    }

}

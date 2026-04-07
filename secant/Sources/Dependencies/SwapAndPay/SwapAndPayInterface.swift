//
//  SwapAndPayInterface.swift
//  Zashi
//
//  Created by Lukáš Korba on 05-15-2025.
//

import ComposableArchitecture

extension DependencyValues {
    var swapAndPay: SwapAndPayClient {
        get { self[SwapAndPayClient.self] }
        set { self[SwapAndPayClient.self] = newValue }
    }
}

@DependencyClient
struct SwapAndPayClient {
    enum EndpointError: Equatable, Error {
        case message(String)
    }
    
    enum Constants {
        /// Affiliate fee in basis points
        static let zashiFeeBps = 67
    }
    
    let submitDepositTxId: (String, String) async throws -> Void
    let swapAssets: () async throws -> IdentifiedArrayOf<SwapAsset>
    let quote: (Bool, Bool, Bool, Int, SwapAsset, SwapAsset, String, String, String) async throws -> SwapQuote
    let status: (String, Bool) async throws -> SwapDetails
}

//
//  ReviewRequestInterface.swift
//  Zashi
//
//  Created by Lukáš Korba on 3.4.2023.
//

import ComposableArchitecture

extension DependencyValues {
    var reviewRequest: ReviewRequestClient {
        get { self[ReviewRequestClient.self] }
        set { self[ReviewRequestClient.self] = newValue }
    }
}

@DependencyClient
struct ReviewRequestClient {
    let canRequestReview: () -> Bool
    let foundTransactions: () -> Void
    let reviewRequested: () -> Void
    let syncFinished: () -> Void
}

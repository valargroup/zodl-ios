//
//  FeedbackGeneratorInterface.swift
//  Zashi
//
//  Created by Lukáš Korba on 14.11.2022.
//

import ComposableArchitecture

extension DependencyValues {
    var feedbackGenerator: FeedbackGeneratorClient {
        get { self[FeedbackGeneratorClient.self] }
        set { self[FeedbackGeneratorClient.self] = newValue }
    }
}

@DependencyClient
struct FeedbackGeneratorClient {
    let generateSuccessFeedback: () -> Void
    let generateWarningFeedback: () -> Void
    let generateErrorFeedback: () -> Void
}

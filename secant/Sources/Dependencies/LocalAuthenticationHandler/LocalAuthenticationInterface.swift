//
//  LocalAuthenticationInterface.swift
//  Zashi
//
//  Created by Lukáš Korba on 12.11.2022.
//

import ComposableArchitecture

extension DependencyValues {
    var localAuthentication: LocalAuthenticationClient {
        get { self[LocalAuthenticationClient.self] }
        set { self[LocalAuthenticationClient.self] = newValue }
    }
}

@DependencyClient
struct LocalAuthenticationClient {
    enum Method: Equatable {
        case faceID
        case none
        case passcode
        case touchID
    }
    
    let authenticate: @Sendable () async -> Bool
    let method: @Sendable () -> Method
}

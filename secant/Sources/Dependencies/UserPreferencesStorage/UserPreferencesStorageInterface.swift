//
//  UserPreferencesStorageInterface.swift
//  Zashi
//
//  Created by Francisco Gindre on 2/6/23.
//

import Foundation
import ComposableArchitecture

extension DependencyValues {
    var userStoredPreferences: UserPreferencesStorageClient {
        get { self[UserPreferencesStorageClient.self] }
        set { self[UserPreferencesStorageClient.self] = newValue }
    }
}

@DependencyClient
struct UserPreferencesStorageClient {
    var server: () -> UserPreferencesStorage.ServerConfig?
    var setServer: (UserPreferencesStorage.ServerConfig) throws -> Void

    var exchangeRate: () -> UserPreferencesStorage.ExchangeRate?
    var setExchangeRate: (UserPreferencesStorage.ExchangeRate) throws -> Void

    var removeAll: () -> Void
}

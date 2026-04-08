//
//  AppVersionInterface.swift
//  Zashi
//
//  Created by Lukáš Korba on 12.11.2022.
//

import ComposableArchitecture

extension DependencyValues {
    var appVersion: AppVersionClient {
        get { self[AppVersionClient.self] }
        set { self[AppVersionClient.self] = newValue }
    }
}

@DependencyClient
struct AppVersionClient {
    let appVersion: () -> String
    let appBuild: () -> String
    
    init(appVersion: @escaping () -> String, appBuild: @escaping () -> String) {
        self.appVersion = appVersion
        self.appBuild = appBuild
    }
}

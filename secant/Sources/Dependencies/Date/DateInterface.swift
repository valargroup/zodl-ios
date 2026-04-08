//
//  DateClient.swift
//  Zashi
//
//  Created by Lukáš Korba on 04.04.2023.
//

import Foundation
import ComposableArchitecture

extension DependencyValues {
    var date: DateClient {
        get { self[DateClient.self] }
        set { self[DateClient.self] = newValue }
    }
}

@DependencyClient
struct DateClient {
    let now: () -> Date
    
    init(now: @escaping () -> Date) {
        self.now = now
    }
}

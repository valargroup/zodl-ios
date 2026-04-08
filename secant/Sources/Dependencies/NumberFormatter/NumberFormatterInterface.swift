//
//  NumberFormatterInterface.swift
//  Zashi
//
//  Created by Lukáš Korba on 12.11.2022.
//

import Foundation
import ComposableArchitecture

extension DependencyValues {
    var numberFormatter: NumberFormatterClient {
        get { self[NumberFormatterClient.self] }
        set { self[NumberFormatterClient.self] = newValue }
    }
}

@DependencyClient
struct NumberFormatterClient {
    var string: (NSDecimalNumber) -> String?
    var number: (String) -> NSNumber?
    var convertUSToLocale: (String) -> String?
}

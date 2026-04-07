//
//  CaptureDeviceTestKey.swift
//  Zashi
//
//  Created by Lukáš Korba on 11.11.2022.
//

import ComposableArchitecture
import XCTestDynamicOverlay

extension CaptureDeviceClient: TestDependencyKey {
    static let testValue = Self(
        isAuthorized: unimplemented("\(Self.self).isAuthorized", placeholder: false),
        isTorchAvailable: unimplemented("\(Self.self).isTorchAvailable", placeholder: false),
        torch: unimplemented("\(Self.self).torch", placeholder: {}())
    )
}

extension CaptureDeviceClient {
    static let noOp = Self(
        isAuthorized: { false },
        isTorchAvailable: { false },
        torch: { _ in }
    )
}

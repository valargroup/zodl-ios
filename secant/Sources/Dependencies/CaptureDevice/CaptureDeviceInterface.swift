//
//  CaptureDeviceInterface.swift
//  Zashi
//
//  Created by Lukáš Korba on 11.11.2022.
//

import ComposableArchitecture

extension DependencyValues {
    var captureDevice: CaptureDeviceClient {
        get { self[CaptureDeviceClient.self] }
        set { self[CaptureDeviceClient.self] = newValue }
    }
}

@DependencyClient
struct CaptureDeviceClient {
    enum CaptureDeviceClientError: Error {
        case authorizationStatus
        case captureDevice
        case lockForConfiguration
        case torchUnavailable
    }

    let isAuthorized: () -> Bool
    let isTorchAvailable: () -> Bool
    let torch: (Bool) throws -> Void
}

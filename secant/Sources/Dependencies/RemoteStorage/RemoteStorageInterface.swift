//
//  RemoteStorageInterface.swift
//  Zashi
//
//  Created by Lukáš Korba on 09-27-2024.
//

import Foundation
import ComposableArchitecture

extension DependencyValues {
    var remoteStorage: RemoteStorageClient {
        get { self[RemoteStorageClient.self] }
        set { self[RemoteStorageClient.self] = newValue }
    }
}

@DependencyClient
struct RemoteStorageClient {
    let loadDataFromFile: (String) throws -> Data
    let storeDataToFile: (Data, String) throws -> Void
    let removeFile: (String) throws -> Void
}

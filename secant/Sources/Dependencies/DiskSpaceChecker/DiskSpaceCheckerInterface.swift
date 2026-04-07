//
//  DiskSpaceCheckerInterface.swift
//  Zashi
//
//  Created by Lukáš Korba on 10.11.2022.
//

import ComposableArchitecture

extension DependencyValues {
    var diskSpaceChecker: DiskSpaceCheckerClient {
        get { self[DiskSpaceCheckerClient.self] }
        set { self[DiskSpaceCheckerClient.self] = newValue }
    }
}

@DependencyClient
struct DiskSpaceCheckerClient {
    var freeSpaceRequiredForSync: () -> Int64 = { 0 }
    var hasEnoughFreeSpaceForSync: () -> Bool = { false }
    var freeSpace: () -> Int64 = { 0 }
}

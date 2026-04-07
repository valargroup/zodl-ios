//
//  ReadTransactionsStorageInterface.swift
//  
//
//  Created by Lukáš Korba on 11.11.2023.
//

import Foundation
import ComposableArchitecture

extension DependencyValues {
    var readTransactionsStorage: ReadTransactionsStorageClient {
        get { self[ReadTransactionsStorageClient.self] }
        set { self[ReadTransactionsStorageClient.self] = newValue }
    }
}

@DependencyClient
struct ReadTransactionsStorageClient {
    enum Constants {
        static let entityName = "ReadTransactionsStorageEntity"
        static let modelName = "ReadTransactionsStorageModel"
        static let availabilityEntityName = "ReadTransactionsStorageAvailabilityTimestampEntity"
    }
    
    enum ReadTransactionsStorageError: Error {
        case createEntity
        case availability
    }
    
    let markIdAsRead: (RedactableString) throws -> Void
    var readIds: () throws -> [RedactableString: Bool]
    var availabilityTimestamp: () throws -> TimeInterval
    var resetZashi: () throws -> Void
}

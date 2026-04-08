//
//  LogsHandlerInterface.swift
//  Zashi
//
//  Created by Lukáš Korba on 30.01.2023.
//

import Foundation
import ComposableArchitecture

extension DependencyValues {
    var logsHandler: LogsHandlerClient {
        get { self[LogsHandlerClient.self] }
        set { self[LogsHandlerClient.self] = newValue }
    }
}

@DependencyClient
struct LogsHandlerClient {
    let exportAndStoreLogs: (String, String, String) async throws -> URL?
    
    init(exportAndStoreLogs: @escaping (String, String, String) async throws -> URL?) {
        self.exportAndStoreLogs = exportAndStoreLogs
    }
}

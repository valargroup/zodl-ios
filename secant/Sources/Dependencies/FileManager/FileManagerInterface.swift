//
//  FileManagerClient.swift
//  Zashi
//
//  Created by Lukáš Korba on 07.04.2022.
//

import Foundation

struct FileManagerClient {
    let url: (FileManager.SearchPathDirectory, FileManager.SearchPathDomainMask, URL?, Bool) throws -> URL
    let fileExists: (String) -> Bool
    let removeItem: (URL) throws -> Void
    
    init(
        url: @escaping (FileManager.SearchPathDirectory, FileManager.SearchPathDomainMask, URL?, Bool) throws -> URL,
        fileExists: @escaping (String) -> Bool,
        removeItem: @escaping (URL) throws -> Void)
    {
        self.url = url
        self.fileExists = fileExists
        self.removeItem = removeItem
    }
}

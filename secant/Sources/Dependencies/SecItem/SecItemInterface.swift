//
//  SecItemClient.swift
//  Zashi
//
//  Created by Lukáš Korba on 12.04.2022.
//

import Foundation
import Security

struct SecItemClient {
    let copyMatching: (CFDictionary, inout CFTypeRef?) -> OSStatus
    let add: (CFDictionary, inout CFTypeRef?) -> OSStatus
    let update: (CFDictionary, CFDictionary) -> OSStatus
    let delete: (CFDictionary) -> OSStatus
    
    init(
        copyMatching: @escaping (CFDictionary, inout CFTypeRef?) -> OSStatus,
        add: @escaping (CFDictionary, inout CFTypeRef?) -> OSStatus,
        update: @escaping (CFDictionary, CFDictionary) -> OSStatus,
        delete: @escaping (CFDictionary) -> OSStatus
    ) {
        self.copyMatching = copyMatching
        self.add = add
        self.update = update
        self.delete = delete
    }
}

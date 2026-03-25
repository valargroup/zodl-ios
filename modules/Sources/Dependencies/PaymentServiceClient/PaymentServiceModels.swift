import Foundation

// MARK: - PIR

public struct PIRResolveResult: Codable, Equatable {
    public let unifiedAddress: String
    public let publicKey: String

    enum CodingKeys: String, CodingKey {
        case unifiedAddress = "unified_address"
        case publicKey = "public_key"
    }
}

// MARK: - Payment Link

public struct PaymentLinkCreateRequest: Codable {
    public let amount: String
    public let senderAddress: String
    public let description: String?

    public init(amount: String, senderAddress: String, description: String? = nil) {
        self.amount = amount
        self.senderAddress = senderAddress
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case amount
        case senderAddress = "sender_address"
        case description
    }
}

public struct PaymentLinkResponse: Codable, Equatable {
    public let id: String
    public let amount: String
    public let status: PaymentLinkStatus
    public let ephemeralAddress: String
    public let ephemeralKey: String
    public let description: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, status, description
        case ephemeralAddress = "ephemeral_address"
        case ephemeralKey = "ephemeral_key"
    }
}

public enum PaymentLinkStatus: String, Codable, Equatable {
    case pending
    case claimed
    case revoked
}

public struct ClaimPaymentLinkRequest: Codable {
    public let recipientAddress: String

    public init(recipientAddress: String) {
        self.recipientAddress = recipientAddress
    }

    enum CodingKeys: String, CodingKey {
        case recipientAddress = "recipient_address"
    }
}

// MARK: - Relay

public struct RegisterRelayRequest: Codable {
    public let ownerAddress: String
    public let publicKey: String

    public init(ownerAddress: String, publicKey: String) {
        self.ownerAddress = ownerAddress
        self.publicKey = publicKey
    }

    enum CodingKeys: String, CodingKey {
        case ownerAddress = "owner_address"
        case publicKey = "public_key"
    }
}

public struct RegisterRelayResponse: Codable, Equatable {
    public let relayId: String
    public let relayUrl: String
    public let publicAddress: String

    enum CodingKeys: String, CodingKey {
        case relayId = "relay_id"
        case relayUrl = "relay_url"
        case publicAddress = "public_address"
    }
}

public struct RelayPubkeyResponse: Codable, Equatable {
    public let publicKey: String
    public let publicAddress: String

    enum CodingKeys: String, CodingKey {
        case publicKey = "public_key"
        case publicAddress = "public_address"
    }
}

public struct RelayEncapsRequest: Codable {
    public let ciphertext: String
    public let amount: String
    public let senderAddress: String

    public init(ciphertext: String, amount: String, senderAddress: String) {
        self.ciphertext = ciphertext
        self.amount = amount
        self.senderAddress = senderAddress
    }

    enum CodingKeys: String, CodingKey {
        case ciphertext, amount
        case senderAddress = "sender_address"
    }
}

public struct RelayStatusResponse: Codable, Equatable {
    public let encapsId: String
    public let step: Int
    public let stepName: String
    public let description: String
    public let amount: String

    enum CodingKeys: String, CodingKey {
        case encapsId = "encaps_id"
        case step
        case stepName = "step_name"
        case description, amount
    }
}

// MARK: - Transfer

public struct TransferRequest: Codable, Equatable {
    public let senderAddress: String
    public let recipientAddress: String
    public let amount: String

    public init(senderAddress: String, recipientAddress: String, amount: String) {
        self.senderAddress = senderAddress
        self.recipientAddress = recipientAddress
        self.amount = amount
    }

    enum CodingKeys: String, CodingKey {
        case senderAddress = "sender_address"
        case recipientAddress = "recipient_address"
        case amount
    }
}

public struct TransferResponse: Codable, Equatable {
    public let senderAddress: String
    public let recipientAddress: String
    public let amount: String
    public let senderBalance: String
    public let recipientBalance: String
    public let txId: String

    enum CodingKeys: String, CodingKey {
        case senderAddress = "sender_address"
        case recipientAddress = "recipient_address"
        case amount
        case senderBalance = "sender_balance"
        case recipientBalance = "recipient_balance"
        case txId = "tx_id"
    }
}

// MARK: - Address Alias

public struct RegisterAliasRequest: Codable {
    public let alias: String
    public let owner: String

    public init(alias: String, owner: String) {
        self.alias = alias
        self.owner = owner
    }
}

// MARK: - Balance

public struct MockBalanceResponse: Codable, Equatable {
    public let address: String
    public let balance: String
    public let balanceZatoshi: UInt64

    enum CodingKeys: String, CodingKey {
        case address, balance
        case balanceZatoshi = "balance_zatoshi"
    }
}

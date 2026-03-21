import Foundation

/// CDN-hosted config listing vote servers and PIR servers.
/// Fetched at startup from `VotingServiceConfig.cdnURL`.
/// A local override file (`voting-config-local.json` in the app bundle) takes priority
/// to simplify testing against a local chain.
public struct VotingServiceConfig: Codable, Equatable, Sendable {
    public let version: Int
    public let voteServers: [ServiceEndpoint]
    public let pirServers: [ServiceEndpoint]

    public struct ServiceEndpoint: Codable, Equatable, Sendable {
        public let url: String
        public let label: String
        /// Optional `X-Helper-Token` for authenticated helper endpoints.
        /// Empty or absent = no auth (the default for public-facing helpers).
        public let helperApiToken: String?

        public init(url: String, label: String, helperApiToken: String? = nil) {
            self.url = url
            self.label = label
            self.helperApiToken = helperApiToken
        }

        enum CodingKeys: String, CodingKey {
            case url, label
            case helperApiToken = "helper_api_token"
        }
    }

    public init(version: Int, voteServers: [ServiceEndpoint], pirServers: [ServiceEndpoint]) {
        self.version = version
        self.voteServers = voteServers
        self.pirServers = pirServers
    }

    enum CodingKeys: String, CodingKey {
        case version
        case voteServers = "vote_servers"
        case pirServers = "pir_servers"
    }

    /// CDN URL for the production config (served from Vercel Edge Config).
    public static let cdnURL = URL(string: "https://shielded-vote.vercel.app/api/voting-config")!

    /// Filename for a local override bundled in the app (takes priority over CDN).
    public static let localOverrideFilename = "voting-config-local.json"

    /// Default config used when both local override and CDN are unavailable.
    /// Vote API points at local `svoted` REST (see vote-sdk default port 1318). PIR stays on the
    /// hosted nullifier service unless you override via CDN or `voting-config-local.json`.
    /// On a physical device, replace `127.0.0.1` with your Mac's LAN IP.
    public static let fallback = VotingServiceConfig(
        version: 1,
        voteServers: [ServiceEndpoint(url: "http://127.0.0.1:1318", label: "Local")],
        pirServers: [ServiceEndpoint(url: "https://46-101-255-48.sslip.io/nullifier", label: "PIR Server")]
    )
}

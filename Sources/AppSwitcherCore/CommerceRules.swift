import Foundation
import CryptoKit

/// Shared with CONTRACT-002. All dates on the wire are integer Unix seconds.
public struct CommerceAccount: Codable, Equatable, Sendable {
    public let id: String
    public let email: String
}

public struct CommerceEntitlement: Codable, Equatable, Sendable {
    public let status: String
    public let trialEndsAt: Int64?
    public let paidUntil: Int64?
    public let validUntil: Int64?
}

public struct CommerceMe: Codable, Sendable {
    public let account: CommerceAccount
    public let entitlement: CommerceEntitlement
    public let license: String?
}

public struct CommerceTokens: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: Int
    public let sessionId: String
    public let account: CommerceAccount
}

public struct CommerceLicense: Codable, Equatable, Sendable {
    public let iss: String
    public let aud: String
    public let sub: String
    public let sid: String
    public let iat: Int64
    public let nbf: Int64
    public let exp: Int64
    public let entitlementUntil: Int64
    public let status: String
}

public enum CommerceFailure: Error, Equatable, Sendable {
    case configuration, invalidLicense, expiredLicense, clockChanged
    case network, response, signInRequired, secureStorage, cancelled, invalidCallback
    case server(Int, String)
}

public enum CommerceEncoding {
    public static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    public static func decodeBase64URL(_ string: String) -> Data? {
        guard !string.isEmpty, string.utf8.allSatisfy({
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }), string.count % 4 != 1 else { return nil }
        let padded = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            + String(repeating: "=", count: (4 - string.count % 4) % 4)
        guard let data = Data(base64Encoded: padded), base64URL(data) == string else { return nil }
        return data
    }

    public static func challenge(verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }
}

public struct CommerceLicenseVerifier: Sendable {
    private let key: Curve25519.Signing.PublicKey
    private let issuer: String

    public init(publicKey: Data, issuer: String) throws {
        guard publicKey.count == 32 else { throw CommerceFailure.configuration }
        self.key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        self.issuer = issuer
    }

    /// Authenticity and all identity/period constraints are checked even for an expired cache.
    public func verify(_ compact: String, accountID: String, sessionID: String, now: Int64,
                       requireCurrent: Bool = true) throws -> CommerceLicense {
        let latestUnixTime: Int64 = 253_402_300_799 // 9999-12-31; bounds arithmetic and malformed server data.
        guard compact.utf8.count <= 16_384, now > 0, now <= latestUnixTime - 120 else {
            throw CommerceFailure.invalidLicense
        }
        let parts = compact.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              let header = CommerceEncoding.decodeBase64URL(parts[0]),
              let payload = CommerceEncoding.decodeBase64URL(parts[1]),
              let signature = CommerceEncoding.decodeBase64URL(parts[2]), signature.count == 64,
              let fields = try? JSONSerialization.jsonObject(with: header) as? [String: String],
              fields == ["alg": "EdDSA", "typ": "JWT", "kid": "license-v1"],
              key.isValidSignature(signature, for: Data((parts[0] + "." + parts[1]).utf8)),
              let claims = try? JSONDecoder().decode(CommerceLicense.self, from: payload),
              claims.iss == issuer, claims.aud == "appswitcher", claims.sub == accountID,
              claims.sid == sessionID, !accountID.isEmpty, !sessionID.isEmpty,
              ["trial", "paid"].contains(claims.status),
              [claims.iat, claims.nbf, claims.exp, claims.entitlementUntil].allSatisfy({ $0 > 0 && $0 <= latestUnixTime }),
              claims.nbf <= claims.iat,
              claims.exp > claims.iat, claims.entitlementUntil >= claims.exp,
              claims.exp - claims.iat <= 604_800,
              claims.iat <= now + 120, claims.nbf <= now + 120 else {
            throw CommerceFailure.invalidLicense
        }
        if requireCurrent && now >= claims.exp { throw CommerceFailure.expiredLicense }
        return claims
    }
}

/// Uptime anchors prevent freezing the wall clock within a boot; a persisted floor detects rollback
/// across launches/reboots. This bounds an ordinary offline lease, not tamper-proof DRM.
public struct CommerceClock: Codable, Equatable, Sendable {
    public private(set) var highestTime: Int64
    public private(set) var anchorTime: Int64
    public private(set) var anchorUptime: Double
    public private(set) var bootID: String

    public init(wallTime: Int64, uptime: Double, bootID: String) {
        highestTime = wallTime; anchorTime = wallTime; anchorUptime = uptime; self.bootID = bootID
    }

    public mutating func observe(wallTime: Int64, uptime: Double, bootID currentBoot: String) -> (now: Int64, rollback: Bool) {
        let maximum: Int64 = 253_402_300_799
        let safeAnchor = max(0, min(anchorTime, maximum))
        let delta = uptime - anchorUptime
        let elapsed = currentBoot == bootID && delta.isFinite ? max(0, min(delta, Double(maximum))) : 0
        let monotonic = min(maximum, safeAnchor + Int64(elapsed))
        let floor = max(max(0, min(highestTime, maximum)), monotonic)
        let rollback = wallTime < floor - 120 || wallTime > maximum
        highestTime = min(maximum, max(wallTime, floor))
        if currentBoot != bootID {
            bootID = currentBoot; anchorUptime = uptime; anchorTime = highestTime
        }
        return (highestTime, rollback)
    }
}

public enum CommerceAccess: String, Sendable {
    case local, signedOut, eligible, trial, paid, expired, needsVerification, unavailable
    public var allowsSwitching: Bool { self == .local || self == .trial || self == .paid }
}

public enum CommerceAccessRules {
    public static func evaluate(license: CommerceLicense?, entitlement: CommerceEntitlement?,
                                authenticated: Bool, now: Int64, rollback: Bool,
                                confirmedAt: Int64?) -> CommerceAccess {
        guard authenticated else { return .signedOut }
        guard !rollback else { return .needsVerification }
        if let license, now < license.exp, now >= license.nbf - 120 {
            // The signed continuous grant can bridge a paid period queued after a trial.
            if license.status == "trial", let trialEnd = entitlement?.trialEndsAt, now >= trialEnd {
                return .paid
            }
            return license.status == "trial" ? .trial : .paid
        }
        if entitlement?.status == "eligible" { return .eligible }
        if entitlement?.status == "expired", let confirmedAt, now >= confirmedAt, now - confirmedAt < 120 {
            return .expired
        }
        return .needsVerification
    }
}

import AppKit
import CryptoKit
import AppSwitcherCore
import AppSwitcherKit

/// Synthetic security and boundary checks; no network, user Keychain, window enumeration or credentials.
@MainActor
enum CommerceProbe {
    static func verifyFixture(at url: URL) -> Int {
        struct Fixture: Decodable {
            let publicKey: String
            let issuer: String
            let accountId: String
            let sessionId: String
            let license: String
            let now: Int64
        }
        do {
            let data = try Data(contentsOf: url)
            guard data.count < 32_768 else { throw CommerceFailure.response }
            let fixture = try JSONDecoder().decode(Fixture.self, from: data)
            guard let key = Data(base64Encoded: fixture.publicKey) else { throw CommerceFailure.configuration }
            let verifier = try CommerceLicenseVerifier(publicKey: key, issuer: fixture.issuer)
            _ = try verifier.verify(fixture.license, accountID: fixture.accountId, sessionID: fixture.sessionId, now: fixture.now)
            print("PASS commerce: backend Ed25519 fixture accepted by CryptoKit with all identity/time constraints")
            return 0
        } catch {
            print("FAIL commerce: backend license fixture rejected (no credential contents logged)")
            return 1
        }
    }

    static func run() -> Int {
        var passed = 0
        var failed = 0
        func check(_ name: String, _ assertion: () throws -> Bool) {
            do {
                if try assertion() { passed += 1; print("PASS commerce: \(name)") }
                else { failed += 1; print("FAIL commerce: \(name)") }
            } catch { failed += 1; print("FAIL commerce: \(name)") }
        }
        func rejects(_ action: () throws -> Void) -> Bool {
            do { try action(); return false } catch { return true }
        }
        let key = Curve25519.Signing.PrivateKey()
        let foreignKey = Curve25519.Signing.PrivateKey()
        let clock: Int64 = 1_800_000_000
        let issuer = "https://test.appswitcher.invalid"
        let account = "account-fixture"
        let session = "session-fixture"
        func signed(_ overrides: [String: Any] = [:], header: [String: String]? = nil,
                    privateKey: Curve25519.Signing.PrivateKey? = nil) throws -> String {
            var payload: [String: Any] = ["iss": issuer, "aud": "appswitcher", "sub": account, "sid": session,
                                          "iat": clock, "nbf": clock, "exp": clock + 604_800,
                                          "entitlementUntil": clock + 2_592_000, "status": "paid"]
            overrides.forEach { payload[$0.key] = $0.value }
            let h = CommerceEncoding.base64URL(try JSONSerialization.data(withJSONObject: header ?? ["alg": "EdDSA", "typ": "JWT", "kid": "license-v1"]))
            let p = CommerceEncoding.base64URL(try JSONSerialization.data(withJSONObject: payload))
            let input = h + "." + p
            return input + "." + CommerceEncoding.base64URL(try (privateKey ?? key).signature(for: Data(input.utf8)))
        }
        let verifier = try! CommerceLicenseVerifier(publicKey: key.publicKey.rawRepresentation, issuer: issuer)
        func verify(_ compact: String, now: Int64 = clock) throws -> CommerceLicense {
            try verifier.verify(compact, accountID: account, sessionID: session, now: now)
        }
        check("valid Ed25519 license") { try verify(signed()).status == "paid" }
        check("wrong signature") { rejects { _ = try verify(signed(privateKey: foreignKey)) } }
        check("wrong issuer") { rejects { _ = try verify(signed(["iss": "https://foreign.invalid"])) } }
        check("wrong audience") { rejects { _ = try verify(signed(["aud": "other-product"])) } }
        check("wrong account") { rejects { _ = try verify(signed(["sub": "other-account"])) } }
        check("wrong session") { rejects { _ = try verify(signed(["sid": "other-session"])) } }
        check("reject alg none") { rejects { _ = try verify(signed(header: ["alg": "none", "typ": "JWT", "kid": "license-v1"])) } }
        check("reject unknown signing key") { rejects { _ = try verify(signed(header: ["alg": "EdDSA", "typ": "JWT", "kid": "untrusted"])) } }
        check("reject header key injection") { rejects { _ = try verify(signed(header: ["alg": "EdDSA", "typ": "JWT", "kid": "license-v1", "jku": "https://foreign.invalid"])) } }
        check("seven day boundary exclusive") { rejects { _ = try verify(signed(), now: clock + 604_800) } }
        check("reject longer offline lease") { rejects { _ = try verify(signed(["exp": clock + 604_801])) } }
        check("reject lease beyond paid term") { rejects { _ = try verify(signed(["entitlementUntil": clock + 1])) } }
        check("reject not yet valid") { rejects { _ = try verify(signed(["iat": clock + 121, "nbf": clock + 121])) } }
        check("reject unknown status") { rejects { _ = try verify(signed(["status": "admin"])) } }
        check("reject extreme timestamp without integer overflow") {
            rejects { _ = try verify(signed(["iat": Int64.max, "nbf": Int64.max, "exp": Int64.max])) }
                && rejects { _ = try verify(signed(), now: Int64.max) }
        }
        check("clock clamps corrupt extreme checkpoints") {
            var state = CommerceClock(wallTime: Int64.max, uptime: -Double.greatestFiniteMagnitude, bootID: "boot-a")
            let result = state.observe(wallTime: clock, uptime: Double.greatestFiniteMagnitude, bootID: "boot-a")
            return result.rollback && result.now == 253_402_300_799
        }
        check("Keychain namespace isolates staging and production") {
            CommerceSecureStore.serviceName(issuer: "http://localhost:8000") != CommerceSecureStore.serviceName(issuer: issuer)
                && CommerceSecureStore.serviceName(issuer: issuer) == CommerceSecureStore.serviceName(issuer: issuer)
        }
        check("reject malformed compact token") { rejects { _ = try verify("not.a.license.extra") } }
        check("canonical base64url") { CommerceEncoding.decodeBase64URL("A") == nil && CommerceEncoding.decodeBase64URL("YQ==") == nil }
        check("PKCE RFC 7636 S256 vector") {
            CommerceEncoding.challenge(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        }
        check("secure random verifier has 256-bit source") {
            let a = try CommerceSecureStore.randomToken(), b = try CommerceSecureStore.randomToken()
            return a.count == 43 && a != b
        }
        check("clock rollback across reboot") {
            var state = CommerceClock(wallTime: clock, uptime: 100, bootID: "boot-a")
            _ = state.observe(wallTime: clock + 1000, uptime: 1100, bootID: "boot-a")
            let observed = state.observe(wallTime: clock - 10, uptime: 10, bootID: "boot-b")
            return observed.rollback && observed.now == clock + 1000
        }
        check("frozen wall clock advances by uptime") {
            var state = CommerceClock(wallTime: clock, uptime: 100, bootID: "boot-a")
            let observed = state.observe(wallTime: clock, uptime: 700, bootID: "boot-a")
            return observed.rollback && observed.now == clock + 600
        }
        check("clock persists across relaunch") {
            let state = CommerceClock(wallTime: clock, uptime: 100, bootID: "boot-a")
            var restored = try JSONDecoder().decode(CommerceClock.self, from: JSONEncoder().encode(state))
            return restored.observe(wallTime: clock, uptime: 200, bootID: "boot-a").now == clock + 100
        }
        check("offline remains usable before lease expiry") {
            let claims = try verify(signed())
            return CommerceAccessRules.evaluate(license: claims, entitlement: nil, authenticated: true, now: clock + 600_000, rollback: false, confirmedAt: clock) == .paid
        }
        check("expired local lease is not purchase demand") {
            let claims = try verify(signed())
            return CommerceAccessRules.evaluate(license: claims, entitlement: nil, authenticated: true, now: clock + 604_800, rollback: false, confirmedAt: clock) == .needsVerification
        }
        check("signed out cannot reuse retained claim") {
            let claims = try verify(signed())
            return CommerceAccessRules.evaluate(license: claims, entitlement: nil, authenticated: false, now: clock, rollback: false, confirmedAt: clock) == .signedOut
        }
        check("clock rollback blocks an otherwise valid lease") {
            let claims = try verify(signed())
            return CommerceAccessRules.evaluate(license: claims, entitlement: nil, authenticated: true, now: clock, rollback: true, confirmedAt: clock) == .needsVerification
        }
        check("confirmed expiry becomes sync prompt when stale") {
            let data = Data("{\"status\":\"expired\",\"validUntil\":null,\"trialEndsAt\":null,\"paidUntil\":null}".utf8)
            let e = try JSONDecoder().decode(CommerceEntitlement.self, from: data)
            return CommerceAccessRules.evaluate(license: nil, entitlement: e, authenticated: true, now: clock, rollback: false, confirmedAt: clock) == .expired &&
                CommerceAccessRules.evaluate(license: nil, entitlement: e, authenticated: true, now: clock + 120, rollback: false, confirmedAt: clock) == .needsVerification
        }
        check("trial with prepaid continuation bridges offline") {
            let license = try verify(signed(["status": "trial"]))
            let e = try JSONDecoder().decode(CommerceEntitlement.self, from: Data("{\"status\":\"trial\",\"trialEndsAt\":1800000060,\"paidUntil\":1802592000,\"validUntil\":1802592000}".utf8))
            return CommerceAccessRules.evaluate(license: license, entitlement: e, authenticated: true, now: clock + 61, rollback: false, confirmedAt: clock) == .paid
        }
        let pending = CommercePendingLogin(verifier: "fixture-verifier", state: "fixture-state", expiresAt: clock + 300)
        check("valid browser callback") {
            try CommerceController.callbackCode(URL(string: "appswitcher://auth/callback?code=0123456789abcdef&state=fixture-state")!, pending: pending, now: clock) == "0123456789abcdef"
        }
        for (name, value) in [
            ("state mismatch", "appswitcher://auth/callback?code=0123456789abcdef&state=wrong"),
            ("duplicate code", "appswitcher://auth/callback?code=0123456789abcdef&code=0123456789abcdef&state=fixture-state"),
            ("wrong host", "appswitcher://evil/callback?code=0123456789abcdef&state=fixture-state"),
            ("wrong callback path", "appswitcher://auth/other?code=0123456789abcdef&state=fixture-state")
        ] {
            check("callback rejects " + name) { rejects { _ = try CommerceController.callbackCode(URL(string: value)!, pending: pending, now: clock) } }
        }
        check("callback expires after five minutes") {
            rejects { _ = try CommerceController.callbackCode(URL(string: "appswitcher://auth/callback?code=0123456789abcdef&state=fixture-state")!, pending: pending, now: clock + 300) }
        }
        check("release config rejects insecure external host") {
            rejects { _ = try CommerceConfiguration(serviceURL: URL(string: "http://example.com")!, publicKey: key.publicKey.rawRepresentation, allowLocalhost: true) }
        }
        check("release config rejects embedded credentials") {
            rejects { _ = try CommerceConfiguration(serviceURL: URL(string: "https://user:secret@example.com")!, publicKey: key.publicKey.rawRepresentation) }
        }
        check("release config rejects localhost unless explicit") {
            rejects { _ = try CommerceConfiguration(serviceURL: URL(string: "http://localhost:8000")!, publicKey: key.publicKey.rawRepresentation) }
        }
        check("same-origin authorization rejects foreign host") {
            let config = try CommerceConfiguration(serviceURL: URL(string: issuer)!, publicKey: key.publicKey.rawRepresentation)
            return config.sameOrigin(URL(string: issuer + "/desktop/authorize/")!) && !config.sameOrigin(URL(string: "https://other.invalid/desktop/authorize/")!)
        }
        check("authorization page preserves required trailing slash") {
            let config = try CommerceConfiguration(serviceURL: URL(string: issuer)!, publicKey: key.publicKey.rawRepresentation)
            let value = issuer + "/desktop/authorize/?request=00112233-4455-6677-8899-aabbccddeeff"
            return try config.authorizationURL(value).absoluteString == value
        }
        check("authorization page rejects alternative routes") {
            let config = try CommerceConfiguration(serviceURL: URL(string: issuer)!, publicKey: key.publicKey.rawRepresentation)
            return rejects { _ = try config.authorizationURL(issuer + "/desktop/authorize?request=00112233-4455-6677-8899-aabbccddeeff") }
                && rejects { _ = try config.authorizationURL(issuer + "/other/?request=00112233-4455-6677-8899-aabbccddeeff") }
                && rejects { _ = try config.authorizationURL("https://foreign.invalid/desktop/authorize/?request=00112233-4455-6677-8899-aabbccddeeff") }
        }
        check("version comparison handles numeric components") { CommerceController.isNewer("0.10.0", than: "0.9.9") && !CommerceController.isNewer("0.4.0", than: "0.4.0") }
        check("version comparison rejects malformed releases") { !CommerceController.isNewer("999.a.0", than: "0.4.0") && !CommerceController.isNewer("999.0.0-beta", than: "0.4.0") }
        print("Commerce probe: \(passed) passed, \(failed) failed. Synthetic only; no real login/payment/Keychain/UI distribution claim.")
        return failed == 0 ? 0 : 1
    }
}

#if DEBUG
/// Actual loopback HTTP contract test. Only a newly approved synthetic account fixture is accepted.
/// The release executable contains neither this entry point nor a runtime service override.
@MainActor
enum CommerceAPIProbe {
    static func run(fixtureURL: URL) async -> Int {
        struct Fixture: Decodable {
            let serviceURL: String
            let publicKey: String
            let code: String
            let codeVerifier: String
        }
        struct OK: Decodable, Sendable { let ok: Bool }
        var api: CommerceClient?
        var cleanupToken: String?
        var count = 0
        func pass(_ message: String) { count += 1; print("PASS commerce API: " + message) }
        do {
            let fixtureData = try Data(contentsOf: fixtureURL)
            guard fixtureData.count <= 32_768 else { throw CommerceFailure.response }
            let fixture = try JSONDecoder().decode(Fixture.self, from: fixtureData)
            guard let service = URL(string: fixture.serviceURL),
                  ["localhost", "127.0.0.1", "::1"].contains(service.host ?? ""),
                  let publicKey = Data(base64Encoded: fixture.publicKey) else { throw CommerceFailure.configuration }
            let config = try CommerceConfiguration(serviceURL: service, publicKey: publicKey, allowLocalhost: true)
            let client = CommerceClient(configuration: config)
            api = client
            let start: CommerceLoginStart = try await client.request("api/v1/desktop/start", method: "POST", body: [
                "codeChallenge": CommerceEncoding.challenge(verifier: try CommerceSecureStore.randomToken()),
                "state": try CommerceSecureStore.randomToken(), "deviceName": "Synthetic native start validation"
            ])
            _ = try config.authorizationURL(start.authorizeUrl)
            guard start.expiresIn == 300 else { throw CommerceFailure.response }
            pass("desktop/start returns a valid same-origin browser authorization URL")
            let tokens: CommerceTokens = try await client.request("api/v1/desktop/exchange", method: "POST",
                                                                  body: ["code": fixture.code, "codeVerifier": fixture.codeVerifier])
            cleanupToken = tokens.accessToken
            guard !tokens.sessionId.isEmpty, tokens.expiresIn == 3600 else { throw CommerceFailure.response }
            pass("one-time PKCE exchange decoded")
            let initial: CommerceMe = try await client.request("api/v1/me", token: tokens.accessToken)
            guard initial.account.id == tokens.account.id, initial.entitlement.status == "eligible", initial.license == nil else {
                throw CommerceFailure.response
            }
            pass("fresh account does not consume a trial during login")
            let trial: CommerceMe = try await client.request("api/v1/trial/start", method: "POST", body: [:], token: tokens.accessToken)
            let now = Int64(Date().timeIntervalSince1970)
            guard trial.entitlement.status == "trial", let end = trial.entitlement.trialEndsAt,
                  abs(end - now - 14 * 86_400) < 30, let license = trial.license else { throw CommerceFailure.response }
            let verifier = try CommerceLicenseVerifier(publicKey: publicKey, issuer: config.issuer)
            let claims = try verifier.verify(license, accountID: tokens.account.id, sessionID: tokens.sessionId, now: now)
            guard claims.entitlementUntil == trial.entitlement.validUntil, claims.exp - claims.iat == 7 * 86_400 else {
                throw CommerceFailure.invalidLicense
            }
            pass("explicit 14-day trial and Python-to-CryptoKit seven-day signed authorization")
            let refreshed: CommerceTokens = try await client.request("api/v1/desktop/refresh", method: "POST",
                                                                     body: ["refreshToken": tokens.refreshToken])
            cleanupToken = refreshed.accessToken
            guard refreshed.sessionId == tokens.sessionId, refreshed.account.id == tokens.account.id,
                  refreshed.refreshToken != tokens.refreshToken, refreshed.accessToken != tokens.accessToken else {
                throw CommerceFailure.response
            }
            let afterRefresh: CommerceMe = try await client.request("api/v1/me", token: refreshed.accessToken)
            guard afterRefresh.entitlement.trialEndsAt == end, let refreshedLicense = afterRefresh.license else {
                throw CommerceFailure.response
            }
            _ = try verifier.verify(refreshedLicense, accountID: tokens.account.id, sessionID: tokens.sessionId, now: Int64(Date().timeIntervalSince1970))
            pass("refresh rotates tokens, preserving the same account/session/trial")
            let logout: OK = try await client.request("api/v1/desktop/logout", method: "POST", body: [:], token: refreshed.accessToken)
            guard logout.ok else { throw CommerceFailure.response }
            cleanupToken = nil
            do {
                let _: CommerceMe = try await client.request("api/v1/me", token: refreshed.accessToken)
                throw CommerceFailure.response
            } catch CommerceFailure.signInRequired { pass("logout revokes bearer access (HTTP 401)") }
            do {
                let _: CommerceTokens = try await client.request("api/v1/desktop/refresh", method: "POST", body: ["refreshToken": refreshed.refreshToken])
                throw CommerceFailure.response
            } catch CommerceFailure.signInRequired { pass("logout also revokes refresh access (HTTP 401)") }
            print("Commerce API probe: \(count) passed, 0 failed. Local synthetic account only; no Keychain, hotkeys, app windows or real payments.")
            return 0
        } catch {
            if let api, let cleanupToken {
                let _: OK? = try? await api.request("api/v1/desktop/logout", method: "POST", body: [:], token: cleanupToken)
            }
            print("Commerce API probe: failed after \(count) checks. No credential/error payload was logged; regenerate the short-lived fixture if expired.")
            return 1
        }
    }
}
#endif

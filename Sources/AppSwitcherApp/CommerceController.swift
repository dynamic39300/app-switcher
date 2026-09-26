import AppKit
import Combine
import CryptoKit
import Darwin
import AppSwitcherCore
import AppSwitcherKit

@MainActor
final class CommerceController: NSObject, ObservableObject {
    @Published private(set) var access: CommerceAccess = .local
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    @Published private(set) var accountEmail: String?
    @Published private(set) var validUntil: Int64?
    @Published private(set) var localUntil: Int64?
    @Published private(set) var update: CommerceRelease?
    @Published private(set) var isCommercial = false
    var onShortcutSettings: (() -> Void)?

    var shouldShowAtLaunch: Bool { isCommercial && [.signedOut, .eligible, .unavailable].contains(access) }
    var renewalHint: String? {
        guard let end = stored.entitlement?.validUntil, end > now else { return nil }
        let remaining = end - now
        if access == .trial {
            if let paidUntil = stored.entitlement?.paidUntil, let trialEnd = stored.entitlement?.trialEndsAt, paidUntil > trialEnd {
                return "已购买的期限会接在试用之后，无需再次购买。"
            }
            if remaining <= 86_400 { return "试用将在 24 小时内结束。购买后继续使用，无自动扣款。" }
            if remaining <= 3 * 86_400 { return "试用还剩不到 3 天。可先查看套餐，所有配置都会保留。" }
        }
        if access == .paid, remaining <= 7 * 86_400 {
            let days = max(1, Int((remaining + 86_399) / 86_400))
            return "授权将在 \(days) 天内到期。提前续费会保留剩余期限，无自动扣款。"
        }
        return nil
    }

    func openShortcutSettings() { onShortcutSettings?() }
    func openAccessibilitySettings() { AccessibilityGate.openSettings() }

    private var store: CommerceSecureStore
    private var stored = CommerceStoredSession()
    private var configuration: CommerceConfiguration?
    private var client: CommerceClient?
    private var verifier: CommerceLicenseVerifier?
    private var claims: CommerceLicense?
    private var timerTask: Task<Void, Never>?
    private var lastSyncAttempt: Int64 = 0
    private var lastPersistence: Int64 = 0
    private var generation = 0
    private var accountWindow: CommerceAccountWindow?
    private var fatalStorage = false
    private var deferredCallback: URL?
    private var callbackTask: Task<Void, Never>?
    private var bootID: String

    init(bundle: Bundle = .main, store: CommerceSecureStore? = nil) {
        self.store = store ?? CommerceSecureStore()
        self.bootID = Self.currentBootID()
        super.init()
        let mode = bundle.object(forInfoDictionaryKey: "AppSwitcherCommerceMode") as? String
        if mode == nil || mode == "local" { return }
        isCommercial = true
        access = .unavailable
        do {
            guard mode == "commercial",
                  let service = bundle.object(forInfoDictionaryKey: "AppSwitcherServiceURL") as? String,
                  let url = URL(string: service),
                  let encodedKey = bundle.object(forInfoDictionaryKey: "AppSwitcherLicensePublicKey") as? String,
                  let publicKey = Data(base64Encoded: encodedKey) else { throw CommerceFailure.configuration }
            // Release packages only trust their signed Info.plist, never environment flags.
            #if DEBUG
            let allowLocalhost = true
            #else
            let allowLocalhost = false
            #endif
            let configuration = try CommerceConfiguration(serviceURL: url, publicKey: publicKey, allowLocalhost: allowLocalhost)
            self.configuration = configuration
            if store == nil { self.store = CommerceSecureStore(service: CommerceSecureStore.serviceName(issuer: configuration.issuer)) }
            self.client = CommerceClient(configuration: configuration)
            self.verifier = try CommerceLicenseVerifier(publicKey: publicKey, issuer: configuration.issuer)
            stored = try self.store.read()
            updateAccess()
        } catch { present(error) }
    }

    #if DEBUG
    init(preview access: CommerceAccess, longText: Bool = false) {
        self.store = CommerceSecureStore(service: "com.appswitcher.preview-unused")
        self.bootID = "synthetic-preview"
        super.init()
        self.isCommercial = true
        self.access = access
        if ![CommerceAccess.signedOut, .unavailable].contains(access) {
            let email = longText ? "a-long-test-account-for-layout@example.invalid" : "preview@example.invalid"
            let json = "{\"accessToken\":\"synthetic-unused\",\"refreshToken\":\"synthetic-unused\",\"expiresIn\":3600,\"sessionId\":\"fixture\",\"account\":{\"id\":\"fixture\",\"email\":\"" + email + "\"}}"
            stored.tokens = try? JSONDecoder().decode(CommerceTokens.self, from: Data(json.utf8))
            accountEmail = email
        }
        if [.trial, .paid].contains(access) {
            validUntil = 1_800_000_000
            localUntil = 1_799_900_000
        }
        if access == .needsVerification { message = "暂时无法连接账号服务。如已购买，请稍后同步，无需重复付款。" }
        if access == .unavailable { message = "此安装包的账号服务配置不完整，请从官网下载完整版本。" }
    }
    #endif

    func start() {
        guard isCommercial else { return }
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(openURL(_:withReplyEvent:)),
                                                     forEventClass: AEEventClass(kInternetEventClass),
                                                     andEventID: AEEventID(kAEGetURL))
        timerTask = Task { [weak self] in
            self?.synchronize()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake),
                                                          name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func didWake() { tick(forceSync: true) }

    private func tick(forceSync: Bool = false) {
        updateAccess()
        if forceSync || now - lastSyncAttempt >= 900 { synchronize() }
    }

    var isSignedIn: Bool { stored.tokens != nil }
    private var now: Int64 { Int64(Date().timeIntervalSince1970) }

    /// Called only at the beginning of an operation, never while a focus request is in flight.
    func canBeginSwitch() -> Bool {
        updateAccess()
        guard !access.allowsSwitching else { return true }
        if stored.dismissedState != "blocked" {
            stored.dismissedState = "blocked"
            persist()
            showAccount()
        }
        return false
    }

    func showAccount() {
        if accountWindow == nil { accountWindow = CommerceAccountWindow(model: self) }
        accountWindow?.show()
    }

    private func updateAccess() {
        guard isCommercial else { access = .local; return }
        guard configuration != nil, verifier != nil, !fatalStorage else { access = .unavailable; return }
        if stored.clock == nil {
            stored.clock = CommerceClock(wallTime: now, uptime: ProcessInfo.processInfo.systemUptime, bootID: bootID)
        }
        let observation = stored.clock!.observe(wallTime: now, uptime: ProcessInfo.processInfo.systemUptime, bootID: bootID)
        accountEmail = stored.tokens?.account.email
        validUntil = stored.entitlement?.validUntil
        claims = nil
        if let compact = stored.license, let tokens = stored.tokens {
            claims = try? verifier?.verify(compact, accountID: tokens.account.id, sessionID: tokens.sessionId,
                                           now: observation.now, requireCurrent: false)
        }
        localUntil = claims?.exp
        let next = CommerceAccessRules.evaluate(license: claims, entitlement: stored.entitlement,
                                                authenticated: stored.tokens != nil, now: observation.now,
                                                rollback: observation.rollback, confirmedAt: stored.confirmedAt)
        if next.allowsSwitching { stored.dismissedState = nil }
        access = next
        if observation.rollback { message = "系统时间发生变化。请校准时间并联网同步授权。" }
        if now - lastPersistence >= 60 || observation.rollback { persist() }
    }

    @discardableResult private func persist() -> Bool {
        do {
            try store.write(stored)
            lastPersistence = now
            return true
        } catch {
            fatalStorage = true
            access = .unavailable
            message = "无法安全保存账号信息。请检查钥匙串访问权限后重新启动 AppSwitcher。"
            return false
        }
    }

    func signIn() {
        guard let client, let configuration, !busy, !fatalStorage else { return }
        busy = true; message = nil
        generation += 1
        let operation = generation
        Task {
            defer { if operation == generation { busy = false } }
            do {
                let pending = CommercePendingLogin(verifier: try CommerceSecureStore.randomToken(),
                                                   state: try CommerceSecureStore.randomToken(), expiresAt: now + 300)
                stored.pending = pending
                guard persist() else { return }
                let response: CommerceLoginStart = try await client.request("api/v1/desktop/start", method: "POST", body: [
                    "codeChallenge": CommerceEncoding.challenge(verifier: pending.verifier),
                    "state": pending.state,
                    // A generic label avoids uploading the user's potentially identifying computer name.
                    "deviceName": "AppSwitcher · macOS"
                ])
                guard operation == generation else { return }
                guard response.expiresIn > 0, response.expiresIn <= 300 else { throw CommerceFailure.response }
                let url = try configuration.authorizationURL(response.authorizeUrl)
                guard NSWorkspace.shared.open(url) else { throw CommerceFailure.response }
                message = "请在浏览器完成登录并确认授权，然后返回 AppSwitcher。登录链接 5 分钟内有效。"
            } catch { if operation == generation { present(error) } }
        }
    }

    @objc private func openURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let value = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              value.utf8.count < 4096, let url = URL(string: value) else { return }
        handleCallback(url)
    }

    func handleCallback(_ url: URL) {
        guard isCommercial, let client, let pending = stored.pending else { return }
        do {
            let code = try Self.callbackCode(url, pending: pending, now: now)
            if busy {
                // A background refresh must not swallow a browser callback. At most one waiter.
                deferredCallback = url
                if callbackTask == nil {
                    callbackTask = Task { [weak self] in
                        while self?.busy == true {
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            guard !Task.isCancelled else { return }
                        }
                        guard let self else { return }
                        self.callbackTask = nil
                        let callback = self.deferredCallback
                        self.deferredCallback = nil
                        if let callback { self.handleCallback(callback) }
                    }
                }
                return
            }
            generation += 1
            let operation = generation
            busy = true
            // Consume locally before I/O. An uncertain exchange is recovered by a new browser login.
            stored.pending = nil
            guard persist() else { busy = false; return }
            showAccount()
            message = "正在完成登录…"
            Task {
                defer { if operation == generation { busy = false } }
                do {
                    let tokens: CommerceTokens = try await client.request("api/v1/desktop/exchange", method: "POST",
                                                                         body: ["code": code, "codeVerifier": pending.verifier])
                    guard operation == generation else { return }
                    try accept(tokens)
                    try await synchronizeNow(operation: operation)
                    if operation == generation { message = "登录成功。账号可在多台设备使用。" }
                } catch { if operation == generation { present(error) } }
            }
        } catch { present(error); showAccount() }
    }

    static func callbackCode(_ url: URL, pending: CommercePendingLogin, now: Int64) throws -> String {
        guard now < pending.expiresAt, now >= pending.expiresAt - 420,
              url.scheme == "appswitcher", url.host == "auth", url.path == "/callback",
              url.user == nil, url.password == nil, url.port == nil, url.fragment == nil,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              items.count == 2, Set(items.map(\.name)) == Set(["code", "state"]),
              let state = items.first(where: { $0.name == "state" })?.value, state == pending.state,
              let code = items.first(where: { $0.name == "code" })?.value, (16...512).contains(code.utf8.count),
              code.utf8.allSatisfy({ (33...126).contains($0) }) else { throw CommerceFailure.invalidCallback }
        return code
    }

    private func accept(_ tokens: CommerceTokens) throws {
        guard (1...3600).contains(tokens.expiresIn), (16...4096).contains(tokens.accessToken.utf8.count),
              (16...4096).contains(tokens.refreshToken.utf8.count), !tokens.sessionId.isEmpty,
              !tokens.account.id.isEmpty, tokens.account.email.utf8.count <= 320 else { throw CommerceFailure.response }
        if let previous = stored.tokens,
           previous.account.id != tokens.account.id || previous.sessionId != tokens.sessionId {
            stored.license = nil; stored.entitlement = nil; stored.confirmedAt = nil
        }
        stored.tokens = tokens
        stored.tokenExpiresAt = now + Int64(tokens.expiresIn)
        guard persist() else { throw CommerceFailure.secureStorage }
        updateAccess()
    }

    func synchronize() {
        guard stored.tokens != nil, client != nil, !busy, !fatalStorage else { return }
        busy = true; message = nil
        let operation = generation
        Task {
            defer { if operation == generation { busy = false } }
            do {
                try await synchronizeNow(operation: operation)
                if operation == generation { message = "已同步账号权益。" }
            } catch { if operation == generation { present(error) } }
        }
    }

    private func refreshIfNeeded(force: Bool, operation: Int) async throws {
        guard let client, let tokens = stored.tokens else { throw CommerceFailure.signInRequired }
        if !force, let expiry = stored.tokenExpiresAt, expiry > now + 60 { return }
        let next: CommerceTokens = try await client.request("api/v1/desktop/refresh", method: "POST",
                                                            body: ["refreshToken": tokens.refreshToken])
        guard operation == generation else { throw CommerceFailure.cancelled }
        guard next.sessionId == tokens.sessionId, next.account.id == tokens.account.id else { throw CommerceFailure.response }
        try accept(next)
    }

    private func synchronizeNow(operation: Int) async throws {
        guard let client, let verifier else { throw CommerceFailure.configuration }
        lastSyncAttempt = now
        try await refreshIfNeeded(force: false, operation: operation)
        let me: CommerceMe
        do {
            me = try await client.request("api/v1/me", token: stored.tokens?.accessToken)
        } catch CommerceFailure.signInRequired {
            try await refreshIfNeeded(force: true, operation: operation)
            me = try await client.request("api/v1/me", token: stored.tokens?.accessToken)
        }
        guard operation == generation else { throw CommerceFailure.cancelled }
        guard let tokens = stored.tokens, me.account.id == tokens.account.id,
              ["eligible", "trial", "paid", "expired"].contains(me.entitlement.status),
              [me.entitlement.validUntil, me.entitlement.trialEndsAt, me.entitlement.paidUntil]
                .compactMap({ $0 }).allSatisfy({ $0 > 0 && $0 <= 253_402_300_799 }) else { throw CommerceFailure.response }
        if let compact = me.license {
            let verified = try verifier.verify(compact, accountID: tokens.account.id, sessionID: tokens.sessionId, now: now)
            guard me.entitlement.validUntil == verified.entitlementUntil else { throw CommerceFailure.response }
        } else if ["trial", "paid"].contains(me.entitlement.status) { throw CommerceFailure.invalidLicense }
        stored.license = me.license
        stored.entitlement = me.entitlement
        stored.confirmedAt = now
        stored.clock = CommerceClock(wallTime: now, uptime: ProcessInfo.processInfo.systemUptime, bootID: bootID)
        guard persist() else { throw CommerceFailure.secureStorage }
        updateAccess()
    }

    func startTrial() {
        guard access == .eligible, !busy, let client else { return }
        busy = true; message = nil
        let operation = generation
        Task {
            defer { if operation == generation { busy = false } }
            do {
                try await refreshIfNeeded(force: false, operation: operation)
                let _: CommerceMe = try await client.request("api/v1/trial/start", method: "POST", body: [:],
                                                             token: stored.tokens?.accessToken)
                guard operation == generation else { return }
                try await synchronizeNow(operation: operation)
                if operation == generation { message = "14 天全功能试用已开始。无需绑定付款方式。" }
            } catch { if operation == generation { present(error) } }
        }
    }

    func signOut() {
        guard !busy, let client else { return }
        generation += 1
        let tokens = stored.tokens
        let tokenExpiry = stored.tokenExpiresAt
        stored = CommerceStoredSession()
        claims = nil
        do { try store.clear(); fatalStorage = false }
        catch { present(CommerceFailure.secureStorage); return }
        updateAccess()
        message = "已退出本机账号，快捷键与其他设备保持不变。"
        if let tokens {
            busy = true
            let operation = generation
            Task {
                defer { if operation == generation { busy = false } }
                do {
                    var token = tokens.accessToken
                    if (tokenExpiry ?? 0) <= now {
                        let next: CommerceTokens = try await client.request("api/v1/desktop/refresh", method: "POST", body: ["refreshToken": tokens.refreshToken])
                        guard next.account.id == tokens.account.id, next.sessionId == tokens.sessionId else { throw CommerceFailure.response }
                        token = next.accessToken
                    }
                    let _: CommerceOK = try await client.request("api/v1/desktop/logout", method: "POST", body: [:], token: token)
                } catch {
                    if operation == generation { message = "已清除本机登录信息。暂时未能通知服务器，可在官网账号页撤销此会话。" }
                }
            }
        }
    }

    func openAccount() { openPage("account/") }
    func openPurchase() { openPage("pricing/") }
    func openSupport() { openPage("support/") }
    func openDownload() { openPage("download/") }

    private func openPage(_ path: String) {
        guard let url = configuration?.page(path), NSWorkspace.shared.open(url) else {
            message = "暂时无法打开官网，请稍后重试。"; showAccount(); return
        }
    }

    func checkUpdates() {
        showAccount()
        guard let client, !busy else { return }
        busy = true; message = nil
        let operation = generation
        Task {
            defer { if operation == generation { busy = false } }
            do {
                let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.4.0"
                let release: CommerceRelease = try await client.request("api/v1/releases/latest",
                                                                        query: [URLQueryItem(name: "version", value: current)])
                guard operation == generation else { return }
                if release.available, let version = release.version, Self.isNewer(version, than: current),
                   let sha = release.sha256, sha.count == 64, sha.allSatisfy(\.isHexDigit),
                   let rawURL = release.url, let url = URL(string: rawURL), url.scheme == "https" {
                    update = release
                    message = "发现新版本 \(version)。请从官网下载并替换应用，已有配置会保留。"
                } else {
                    update = nil
                    message = release.available ? "当前已是最新可用版本。" : "暂未发布可下载的正式版本。"
                }
            } catch { if operation == generation { present(error) } }
        }
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        func version(_ text: String) -> [Int]? {
            let parts = text.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 3 else { return nil }
            let values = parts.compactMap { part -> Int? in
                guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
                return Int(part)
            }
            return values.count == 3 ? values : nil
        }
        guard let lhs = version(candidate), let rhs = version(current) else { return false }
        return rhs.lexicographicallyPrecedes(lhs)
    }

    private func present(_ error: Error) {
        switch error as? CommerceFailure {
        case .configuration:
            access = .unavailable
            message = "此安装包的账号服务配置不完整，请从官网下载完整版本。"
        case .secureStorage:
            fatalStorage = true; access = .unavailable
            message = "无法访问系统钥匙串。请检查访问权限并重新启动 AppSwitcher。"
        case .signInRequired:
            stored.tokens = nil; stored.license = nil; stored.entitlement = nil; stored.confirmedAt = nil
            persist(); updateAccess()
            message = "本机登录已失效，请重新在浏览器登录。其他设备不受影响。"
        case .invalidCallback:
            message = "登录链接已失效或不属于本次登录。请重新点击“浏览器登录”。"
        case .invalidLicense, .expiredLicense, .clockChanged:
            message = "暂时无法验证账号授权。请检查系统时间并重新同步；如已购买，无需重复付款。"
        case .server(429, _): message = "操作较频繁，请稍后再试。"
        case .server(409, _): message = "账号状态已变化，请同步权益后重试。"
        case .response: message = "账号服务返回的信息暂时无法处理，请稍后重试。"
        case .cancelled: break
        default:
            updateAccess()
            message = "暂时无法连接账号服务。有效的本机授权仍可使用；如已购买，请稍后同步，无需重复付款。"
        }
    }

    private static func currentBootID() -> String {
        var length = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &length, nil, 0) == 0, length > 0 else { return "unknown-boot" }
        var bytes = [CChar](repeating: 0, count: length)
        guard sysctlbyname("kern.bootsessionuuid", &bytes, &length, nil, 0) == 0 else { return "unknown-boot" }
        return String(cString: bytes)
    }
}

private struct CommerceOK: Decodable, Sendable { let ok: Bool }

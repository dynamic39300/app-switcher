import Foundation
import AppSwitcherCore

public struct CommerceConfiguration: Sendable {
    public let serviceURL: URL
    public let publicKey: Data
    public var issuer: String { serviceURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }

    public init(serviceURL: URL, publicKey: Data, allowLocalhost: Bool = false) throws {
        let developmentHost = ["localhost", "127.0.0.1", "::1"].contains(serviceURL.host ?? "")
        guard serviceURL.scheme == "https" || (allowLocalhost && developmentHost && serviceURL.scheme == "http"),
              serviceURL.host != nil, serviceURL.user == nil, serviceURL.password == nil,
              serviceURL.query == nil, serviceURL.fragment == nil,
              serviceURL.path.isEmpty || serviceURL.path == "/", publicKey.count == 32 else {
            throw CommerceFailure.configuration
        }
        self.serviceURL = URL(string: serviceURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))!
        self.publicKey = publicKey
    }

    public func sameOrigin(_ url: URL) -> Bool {
        url.scheme == serviceURL.scheme && url.host == serviceURL.host && url.port == serviceURL.port
            && url.user == nil && url.password == nil
    }

    public func authorizationURL(_ raw: String) throws -> URL {
        guard let parts = URLComponents(string: raw), let url = parts.url, sameOrigin(url),
              parts.percentEncodedPath == "/desktop/authorize/", parts.fragment == nil,
              let items = parts.queryItems, items.count == 1, items[0].name == "request",
              let request = items[0].value, UUID(uuidString: request) != nil else { throw CommerceFailure.response }
        return url
    }

    public func page(_ path: String) -> URL { serviceURL.appendingPathComponent(path) }
}

private final class CommerceRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Neither a bearer credential nor a refresh token may follow a server redirect.
        completionHandler(nil)
    }
}

public struct CommerceLoginStart: Decodable, Sendable {
    public let authorizeUrl: String
    public let expiresIn: Int
}

public struct CommerceRelease: Decodable, Sendable {
    public let available: Bool
    public let version: String?
    public let url: String?
    public let notes: String
    public let minimumOS: String
    public let sha256: String?
}

private struct CommerceErrorBody: Decodable {
    struct Detail: Decodable { let code: String }
    let error: Detail
}

public actor CommerceClient {
    public let configuration: CommerceConfiguration
    private let session: URLSession
    private let redirectGuard: CommerceRedirectGuard

    public init(configuration: CommerceConfiguration) {
        self.configuration = configuration
        let options = URLSessionConfiguration.ephemeral
        options.httpCookieStorage = nil
        options.httpShouldSetCookies = false
        options.urlCache = nil
        options.timeoutIntervalForRequest = 15
        options.timeoutIntervalForResource = 25
        let guardDelegate = CommerceRedirectGuard()
        self.redirectGuard = guardDelegate
        self.session = URLSession(configuration: options, delegate: guardDelegate, delegateQueue: nil)
    }

    public func request<Response: Decodable & Sendable>(_ path: String, method: String = "GET",
                                                       body: [String: String]? = nil, token: String? = nil,
                                                       query: [URLQueryItem] = []) async throws -> Response {
        var components = URLComponents(url: configuration.page(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AppSwitcher/0.4.0", forHTTPHeaderField: "User-Agent")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse, response.url == request.url else {
                throw CommerceFailure.response
            }
            var data = Data()
            for try await byte in bytes {
                guard data.count < 262_144 else { throw CommerceFailure.response }
                data.append(byte)
            }
            if response.statusCode == 401 { throw CommerceFailure.signInRequired }
            guard (200..<300).contains(response.statusCode) else {
                let code = (try? JSONDecoder().decode(CommerceErrorBody.self, from: data).error.code) ?? "request_failed"
                // Only stable codes are retained; user emails, token fields or raw server errors never enter logs.
                throw CommerceFailure.server(response.statusCode, String(code.prefix(80)))
            }
            guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { throw CommerceFailure.response }
            return decoded
        } catch let failure as CommerceFailure { throw failure }
        catch is CancellationError { throw CommerceFailure.cancelled }
        catch { throw CommerceFailure.network }
    }
}

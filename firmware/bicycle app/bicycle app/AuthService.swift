//
//  AuthService.swift
//  bicycle app
//

import Foundation

let appBackendBaseURL = "http://172.16.23.215:3000"

struct AppUser: Codable {
    let id: String
    let username: String
    let role: String
    let inviteCode: String?
    let watchList: [String]?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case username, role, inviteCode, watchList
    }

    var hasWatchList: Bool {
        guard let list = watchList else { return false }
        return !list.isEmpty
    }
}

struct WatchListItem: Codable, Identifiable {
    let id: String
    let username: String
    let inviteCode: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case username, inviteCode
    }
}

@Observable
final class AuthService {
    static let shared = AuthService()
    nonisolated static let baseURL = appBackendBaseURL

    var token: String?
    var currentUser: AppUser?
    var isLoading = false
    var errorMessage = ""

    var isLoggedIn: Bool { token != nil && currentUser != nil }

    private let tokenKey = "auth_token"

    private init() {
        token = UserDefaults.standard.string(forKey: tokenKey)
        if token == nil { return }
        Task { await refreshMe() }
    }

    func login(username: String, password: String) async -> Bool {
        await auth(path: "/api/auth/login", body: [
            "username": username,
            "password": password
        ])
    }

    func register(username: String, password: String) async -> Bool {
        await auth(path: "/api/auth/register", body: [
            "username": username,
            "password": password
        ])
    }

    @discardableResult
    func addToWatchList(_ inviteCode: String) async -> Bool {
        guard let token else {
            errorMessage = "请先登录"
            return false
        }
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            errorMessage = "邀请码不能为空"
            return false
        }

        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

        do {
            var request = URLRequest(url: URL(string: Self.baseURL + "/api/auth/watch")!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["inviteCode": code])

            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.ensureSuccess(response: response, data: data)
            _ = await refreshMe()
            return true
        } catch {
            errorMessage = Self.errorMessage(from: error)
            return false
        }
    }

    func fetchWatchList() async -> [WatchListItem] {
        guard let token else { return [] }
        do {
            var request = URLRequest(url: URL(string: Self.baseURL + "/api/auth/watchlist")!)
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.ensureSuccess(response: response, data: data)
            let parsed = try JSONDecoder().decode(WatchListResponse.self, from: data)
            return parsed.watchList
        } catch {
            return []
        }
    }

    @discardableResult
    func removeFromWatchList(_ userId: String) async -> Bool {
        guard let token else { return false }
        isLoading = true
        defer { isLoading = false }
        do {
            var request = URLRequest(url: URL(string: Self.baseURL + "/api/auth/watch/\(userId)")!)
            request.httpMethod = "DELETE"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.ensureSuccess(response: response, data: data)
            _ = await refreshMe()
            return true
        } catch {
            errorMessage = Self.errorMessage(from: error)
            return false
        }
    }

    @available(*, deprecated, renamed: "addToWatchList")
    @discardableResult
    func bindInviteCode(_ inviteCode: String) async -> Bool {
        await addToWatchList(inviteCode)
    }

    func logout() {
        token = nil
        currentUser = nil
        errorMessage = ""
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    @discardableResult
    func refreshMe() async -> Bool {
        guard let token else { return false }
        isLoading = true
        defer { isLoading = false }

        do {
            var request = URLRequest(url: URL(string: Self.baseURL + "/api/auth/me")!)
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.ensureSuccess(response: response, data: data)
            let parsed = try JSONDecoder().decode(MeResponse.self, from: data)
            currentUser = parsed.user
            return true
        } catch {
            errorMessage = Self.errorMessage(from: error)
            logout()
            return false
        }
    }

    private func auth(path: String, body: [String: String]) async -> Bool {
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

        do {
            var request = URLRequest(url: URL(string: Self.baseURL + path)!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            // #region agent log
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let rawBody = String(data: data, encoding: .utf8) ?? "<not utf8>"
            print("[DEBUG-a30954] RAW RESPONSE status=\(httpCode) path=\(path) body=\(rawBody)")
            // #endregion

            try Self.ensureSuccess(response: response, data: data)

            let parsed = try JSONDecoder().decode(AuthResponse.self, from: data)
            token = parsed.token
            currentUser = parsed.user
            UserDefaults.standard.set(parsed.token, forKey: tokenKey)
            return true
        } catch {
            // #region agent log
            print("[DEBUG-a30954] AUTH ERROR type=\(type(of: error)) desc=\(error.localizedDescription) full=\(error)")
            // #endregion

            errorMessage = Self.errorMessage(from: error)
            return false
        }
    }

    private static func ensureSuccess(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            if let backend = try? JSONDecoder().decode(BackendError.self, from: data) {
                throw NSError(domain: "AuthService", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: backend.error
                ])
            }
            throw NSError(domain: "AuthService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "请求失败（\(http.statusCode)）"
            ])
        }
    }

    private static func errorMessage(from error: Error) -> String {
        (error as NSError).localizedDescription
    }
}

private struct AuthResponse: Codable {
    let token: String
    let user: AppUser
}

private struct MeResponse: Codable {
    let user: AppUser
}

private struct BackendError: Codable {
    let error: String
}

private struct WatchListResponse: Codable {
    let watchList: [WatchListItem]
}

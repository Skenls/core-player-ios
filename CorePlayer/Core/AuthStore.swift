import Foundation

extension Notification.Name {
    static let corePlayerDidLogin = Notification.Name("corePlayerDidLogin")
    static let corePlayerDidLogout = Notification.Name("corePlayerDidLogout")
}

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var user: UserDto?
    @Published private(set) var isRestoring = true
    @Published var isLoggingIn = false
    @Published var errorMessage: String?
    @Published var serverURLString: String

    private let api: APIClient
    private let defaults: UserDefaults
    private let sessionKey = "session_id"
    private let serverKey = "coreplayer.serverURL"
    private let userKey = "coreplayer.user"

    init(api: APIClient, defaults: UserDefaults = .standard) {
        self.api = api
        self.defaults = defaults
        self.serverURLString = defaults.string(forKey: serverKey) ?? "http://localhost:3000"
        restore()
    }

    var isAuthenticated: Bool {
        user != nil && api.sessionID != nil
    }

    func login(username: String, password: String) async {
        errorMessage = nil
        guard let serverURL = APIClient.normalizeServerURL(serverURLString) else {
            errorMessage = "Некорректный адрес сервера"
            return
        }

        isLoggingIn = true
        defer { isLoggingIn = false }

        do {
            let user = try await api.login(
                serverURL: serverURL,
                username: username,
                password: password
            )
            guard api.sessionID != nil else {
                errorMessage = "Сервер не выдал сессию"
                return
            }
            self.user = user
            self.serverURLString = serverURL.absoluteString
            defaults.set(serverURL.absoluteString, forKey: serverKey)
            persist(user: user)
            if let sessionID = api.sessionID {
                Keychain.set(sessionID, for: sessionKey)
            }
            NotificationCenter.default.post(name: .corePlayerDidLogin, object: nil)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func logout() {
        Task { await api.logout() }
        clearSession()
    }

    private func restore() {
        guard let serverURL = APIClient.normalizeServerURL(serverURLString),
              let sessionID = Keychain.get(sessionKey) else {
            isRestoring = false
            return
        }

        api.configure(baseURL: serverURL, sessionID: sessionID)

        if let data = defaults.data(forKey: userKey),
           let cached = try? JSONDecoder().decode(UserDto.self, from: data) {
            user = cached
        }

        Task {
            do {
                let current = try await api.me()
                user = current
                persist(user: current)
            } catch APIError.unauthorized {
                clearSession()
            } catch {
                // Сервер может быть временно недоступен — оставляем сохранённого пользователя.
            }
            isRestoring = false
        }
    }

    private func clearSession() {
        user = nil
        Keychain.delete(sessionKey)
        defaults.removeObject(forKey: userKey)
        if let serverURL = APIClient.normalizeServerURL(serverURLString) {
            api.configure(baseURL: serverURL, sessionID: nil)
        }
        NotificationCenter.default.post(name: .corePlayerDidLogout, object: nil)
    }

    private func persist(user: UserDto) {
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: userKey)
        }
    }
}

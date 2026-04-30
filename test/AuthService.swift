//
//  AuthService.swift
//  test
//
//  Direct Cognito User Pool auth — no Amplify iOS SDK required.
//
//  IMPORTANT: USER_PASSWORD_AUTH must be enabled on the Cognito App Client.
//  In the AWS Console → Cognito → User Pools → [pool] → App clients →
//  [client] → Authentication flows → check "ALLOW_USER_PASSWORD_AUTH".
//  Or add `enableUserPasswordAuth: true` to your Amplify Gen 2 auth resource.
//

import Foundation

@Observable
final class AuthService {

    static let shared = AuthService()
    private init() { restoreSession() }

    // MARK: - Observed state

    private(set) var isSignedIn  = false
    private(set) var username:  String?
    private(set) var idToken:   String?   // used by AWSPhotoService for authenticated S3
    private      var accessToken:  String?
    private      var refreshToken: String?
    private      var tokenExpiry:  Date?

    // MARK: - Config (from amplify_outputs.json)

    private let clientId   = "2b8aveqr85q08h5hukgm4fvv6v"
    let         userPoolId = "us-east-1_IfqtWLud8"
    let         region     = "us-east-1"

    private var cognitoURL: URL {
        URL(string: "https://cognito-idp.\(region).amazonaws.com/")!
    }

    // MARK: - Sign In

    func signIn(username: String, password: String) async throws {
        let body: [String: Any] = [
            "AuthFlow":  "USER_PASSWORD_AUTH",
            "ClientId":  clientId,
            "AuthParameters": ["USERNAME": username, "PASSWORD": password]
        ]
        let data = try await post(
            target: "AWSCognitoIdentityProviderService.InitiateAuth", body: body)
        let raw = String(data: data, encoding: .utf8) ?? ""

        if raw.contains("NotAuthorizedException")   { throw AuthError.invalidCredentials }
        if raw.contains("UserNotConfirmedException") { throw AuthError.notConfirmed(username) }
        if raw.contains("UserNotFoundException")    { throw AuthError.invalidCredentials }

        guard
            let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let result = json["AuthenticationResult"] as? [String: Any],
            let idTok  = result["IdToken"]     as? String,
            let accTok = result["AccessToken"] as? String
        else { throw AuthError.serverError(raw) }

        let refreshTok = result["RefreshToken"] as? String
        let expiresIn  = result["ExpiresIn"]    as? Int ?? 3600
        saveSession(username: username, idToken: idTok, accessToken: accTok,
                    refreshToken: refreshTok, expiresIn: expiresIn)

        // Invalidate any previously cached unauthenticated S3 credentials
        AWSPhotoService.shared.clearCachedCredentials()
    }

    // MARK: - Sign Up

    func signUp(username: String, password: String, email: String) async throws {
        let body: [String: Any] = [
            "ClientId":  clientId,
            "Username":  username,
            "Password":  password,
            "UserAttributes": [["Name": "email", "Value": email]]
        ]
        let data = try await post(
            target: "AWSCognitoIdentityProviderService.SignUp", body: body)
        let raw = String(data: data, encoding: .utf8) ?? ""

        if raw.contains("UsernameExistsException")            { throw AuthError.usernameExists }
        if raw.contains("InvalidPasswordException")           { throw AuthError.weakPassword }
        if raw.contains("InvalidParameterException")          { throw AuthError.weakPassword }
        if raw.contains("__type") && !raw.contains("UserSub") { throw AuthError.serverError(raw) }
    }

    // MARK: - Confirm Sign Up

    func confirmSignUp(username: String, code: String) async throws {
        let body: [String: Any] = [
            "ClientId": clientId, "Username": username, "ConfirmationCode": code
        ]
        let data = try await post(
            target: "AWSCognitoIdentityProviderService.ConfirmSignUp", body: body)
        let raw = String(data: data, encoding: .utf8) ?? ""

        if raw.contains("CodeMismatchException") { throw AuthError.badCode }
        if raw.contains("ExpiredCodeException")  { throw AuthError.expiredCode }
        if raw.contains("__type")                { throw AuthError.serverError(raw) }
    }

    // MARK: - Resend Confirmation Code

    func resendCode(username: String) async throws {
        let body: [String: Any] = ["ClientId": clientId, "Username": username]
        _ = try await post(
            target: "AWSCognitoIdentityProviderService.ResendConfirmationCode", body: body)
    }

    // MARK: - Sign Out

    func signOut() {
        isSignedIn    = false
        username      = nil
        idToken       = nil
        accessToken   = nil
        refreshToken  = nil
        tokenExpiry   = nil
        ["auth_username","auth_id_token","auth_access_token",
         "auth_refresh_token","auth_token_expiry"]
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
        AWSPhotoService.shared.clearCachedCredentials()
    }

    // MARK: - Session persistence (UserDefaults — use Keychain in production)

    private func saveSession(username: String, idToken: String, accessToken: String,
                              refreshToken: String?, expiresIn: Int) {
        self.username     = username
        self.idToken      = idToken
        self.accessToken  = accessToken
        self.refreshToken = refreshToken
        self.tokenExpiry  = Date().addingTimeInterval(Double(expiresIn - 60))
        self.isSignedIn   = true

        UserDefaults.standard.set(username,    forKey: "auth_username")
        UserDefaults.standard.set(idToken,     forKey: "auth_id_token")
        UserDefaults.standard.set(accessToken, forKey: "auth_access_token")
        if let rt = refreshToken {
            UserDefaults.standard.set(rt,      forKey: "auth_refresh_token")
        }
        UserDefaults.standard.set(tokenExpiry, forKey: "auth_token_expiry")
    }

    private func restoreSession() {
        guard
            let user   = UserDefaults.standard.string(forKey: "auth_username"),
            let idTok  = UserDefaults.standard.string(forKey: "auth_id_token"),
            let accTok = UserDefaults.standard.string(forKey: "auth_access_token")
        else { return }

        let expiry = UserDefaults.standard.object(forKey: "auth_token_expiry") as? Date
        guard let exp = expiry, exp > Date() else {
            // Expired — keep username for display, sign in again on next launch
            return
        }
        username     = user
        idToken      = idTok
        accessToken  = accTok
        refreshToken = UserDefaults.standard.string(forKey: "auth_refresh_token")
        tokenExpiry  = exp
        isSignedIn   = true
    }

    // MARK: - HTTP helper

    private func post(target: String, body: [String: Any]) async throws -> Data {
        var req = URLRequest(url: cognitoURL)
        req.httpMethod = "POST"
        req.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        req.setValue(target,                        forHTTPHeaderField: "X-Amz-Target")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    // MARK: - Errors

    enum AuthError: LocalizedError {
        case invalidCredentials
        case notConfirmed(String)
        case usernameExists
        case weakPassword
        case badCode
        case expiredCode
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .invalidCredentials:    return "Incorrect username or password."
            case .notConfirmed(let u):   return "Account not yet confirmed.\nUsername: \(u)"
            case .usernameExists:        return "That username is already taken."
            case .weakPassword:          return "Password must be 8+ characters with uppercase, number, and symbol."
            case .badCode:               return "Incorrect confirmation code."
            case .expiredCode:           return "Code has expired. Tap 'Resend Code' to get a new one."
            case .serverError(let m):    return "Server error: \(m)"
            }
        }
    }
}

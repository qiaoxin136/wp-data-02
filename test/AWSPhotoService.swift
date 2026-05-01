//
//  AWSPhotoService.swift
//  test
//
//  Generates SigV4 pre-signed S3 URLs using Cognito unauthenticated identities.
//  Requires CryptoKit (iOS 13+). No AWS SDK needed.
//

import Foundation
import CryptoKit

// MARK: - Credential cache

private struct AWSCredentials {
    let accessKeyId: String
    let secretKey: String
    let sessionToken: String
    let expiration: Date
    var isExpired: Bool { expiration.timeIntervalSinceNow < 60 }
}

// MARK: - AWSPhotoService

final class AWSPhotoService {

    static let shared = AWSPhotoService()
    private init() { loadConfig() }

    // Config loaded from amplify_outputs.json
    private var identityPoolId: String = ""
    private var region: String         = "us-east-1"
    private var bucketName: String     = ""

    private var cachedCredentials: AWSCredentials?
    private let credLock = NSLock()

    // MARK: - Config

    private func loadConfig() {
        guard
            let fileURL = Bundle.main.url(forResource: "amplify_outputs",
                                           withExtension: "json"),
            let data    = try? Data(contentsOf: fileURL),
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if let auth = json["auth"] as? [String: Any] {
            identityPoolId = auth["identity_pool_id"] as? String ?? ""
            region         = auth["aws_region"]       as? String ?? "us-east-1"
        }
        if let storage = json["storage"] as? [String: Any] {
            bucketName = storage["bucket_name"] as? String ?? ""
            if let r = storage["aws_region"] as? String { region = r }
        }
    }

    // MARK: - Public API

    /// Returns a pre-signed GET URL valid for 15 minutes, or nil on any error.
    func presignedURL(for key: String) async -> URL? {
        guard !bucketName.isEmpty, !key.isEmpty else { return nil }
        do {
            let creds = try await credentials()
            return presign(key: key, credentials: creds)
        } catch {
            print("AWSPhotoService presign error: \(error)")
            return nil
        }
    }

    /// Uploads JPEG data to S3 and returns the stored key.
    /// Key format: "originals/{uuid}/{filename}.jpg"
    @discardableResult
    func uploadPhoto(imageData: Data, key: String) async throws -> String {
        guard !bucketName.isEmpty else { throw PhotoError.cognitoError("Storage not configured") }

        let creds = try await credentials()

        let service = "s3"
        let host    = "s3.\(region).amazonaws.com"
        let rawPath = "/\(bucketName)/\(key)"
        let encodedPath = encodePath(rawPath)

        let now        = Date()
        let dateStamp  = isoDate(now)
        let amzDate    = isoDateTime(now)
        let credScope  = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let contentType = "image/jpeg"
        let payloadHash = "UNSIGNED-PAYLOAD"

        // Headers must be alphabetically sorted
        let signedHeaders = "content-type;host;x-amz-content-sha256;x-amz-date;x-amz-security-token"
        let canonicalHeaders =
            "content-type:\(contentType)\n" +
            "host:\(host)\n" +
            "x-amz-content-sha256:\(payloadHash)\n" +
            "x-amz-date:\(amzDate)\n" +
            "x-amz-security-token:\(creds.sessionToken)\n"

        let canonicalRequest = [
            "PUT", encodedPath, "",
            canonicalHeaders, signedHeaders, payloadHash
        ].joined(separator: "\n")

        let hashedCR    = sha256Hex(canonicalRequest)
        let stringToSign = "AWS4-HMAC-SHA256\n\(amzDate)\n\(credScope)\n\(hashedCR)"

        let signingKey = deriveSigningKey(secretKey: creds.secretKey,
                                          dateStamp: dateStamp,
                                          region: region, service: service)
        let signature  = hmacSHA256Hex(key: signingKey, data: stringToSign)

        let authorization =
            "AWS4-HMAC-SHA256 Credential=\(creds.accessKeyId)/\(credScope), " +
            "SignedHeaders=\(signedHeaders), Signature=\(signature)"

        var request = URLRequest(url: URL(string: "https://\(host)\(encodedPath)")!)
        request.httpMethod = "PUT"
        request.setValue(contentType,         forHTTPHeaderField: "Content-Type")
        request.setValue(payloadHash,         forHTTPHeaderField: "x-amz-content-sha256")
        request.setValue(amzDate,             forHTTPHeaderField: "x-amz-date")
        request.setValue(creds.sessionToken,  forHTTPHeaderField: "x-amz-security-token")
        request.setValue(authorization,       forHTTPHeaderField: "Authorization")
        request.httpBody = imageData

        let (respData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PhotoError.cognitoError("Invalid upload response")
        }
        if !(200...299).contains(http.statusCode) {
            let body = String(data: respData, encoding: .utf8) ?? ""
            throw PhotoError.cognitoError("Upload HTTP \(http.statusCode): \(body)")
        }
        return key
    }

    // MARK: - Cognito unauthenticated credentials

    private func credentials() async throws -> AWSCredentials {
        credLock.lock()
        if let c = cachedCredentials, !c.isExpired {
            credLock.unlock()
            return c
        }
        credLock.unlock()

        let identityId = try await getIdentityId()
        let creds      = try await getCredentialsForIdentity(identityId: identityId)

        credLock.lock()
        cachedCredentials = creds
        credLock.unlock()
        return creds
    }

    // MARK: - Public cache-clearing (called by AuthService on sign-in/out)

    func clearCachedCredentials() {
        credLock.lock()
        cachedCredentials = nil
        credLock.unlock()
    }

    // MARK: - Cognito identity helpers

    /// Builds the Logins map for authenticated identity if a Cognito idToken is available.
    private var loginsMap: [String: String]? {
        guard let idToken = AuthService.shared.idToken else { return nil }
        let auth = AuthService.shared
        return ["cognito-idp.\(auth.region).amazonaws.com/\(auth.userPoolId)": idToken]
    }

    private func getIdentityId() async throws -> String {
        let url = URL(string: "https://cognito-identity.\(region).amazonaws.com/")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        req.setValue("AWSCognitoIdentityService.GetId",
                     forHTTPHeaderField: "X-Amz-Target")
        var body: [String: Any] = ["IdentityPoolId": identityPoolId]
        if let logins = loginsMap { body["Logins"] = logins }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let identityId = json["IdentityId"] as? String
        else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw PhotoError.cognitoError("GetId failed: \(raw)")
        }
        return identityId
    }

    private func getCredentialsForIdentity(identityId: String) async throws -> AWSCredentials {
        let url = URL(string: "https://cognito-identity.\(region).amazonaws.com/")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        req.setValue("AWSCognitoIdentityService.GetCredentialsForIdentity",
                     forHTTPHeaderField: "X-Amz-Target")
        var body: [String: Any] = ["IdentityId": identityId]
        if let logins = loginsMap { body["Logins"] = logins }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard
            let json  = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let creds = json["Credentials"] as? [String: Any],
            let aki   = creds["AccessKeyId"]    as? String,
            let sk    = creds["SecretKey"]       as? String,
            let st    = creds["SessionToken"]    as? String,
            let expTs = creds["Expiration"]      as? Double
        else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw PhotoError.cognitoError("GetCredentialsForIdentity failed: \(raw)")
        }
        return AWSCredentials(
            accessKeyId:  aki,
            secretKey:    sk,
            sessionToken: st,
            expiration:   Date(timeIntervalSince1970: expTs)
        )
    }

    // MARK: - Path encoding

    private func encodePath(_ path: String) -> String {
        path
            .components(separatedBy: "/")
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathRFC3986) ?? $0 }
            .joined(separator: "/")
    }

    // MARK: - SigV4 pre-signed URL (query-string signing)

    private func presign(key: String, credentials: AWSCredentials,
                         expiresIn: Int = 900) -> URL? {
        let service   = "s3"
        let host      = "s3.\(region).amazonaws.com"
        let path      = "/\(bucketName)/\(key)"
        let encodedPath = encodePath(path)

        let now        = Date()
        let dateStamp  = isoDate(now)       // YYYYMMDD
        let amzDate    = isoDateTime(now)   // YYYYMMDDTHHmmssZ

        let credScope  = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let signedHeaders = "host"

        // Build query string (keys must be sorted)
        var queryItems: [(String, String)] = [
            ("X-Amz-Algorithm",      "AWS4-HMAC-SHA256"),
            ("X-Amz-Credential",     "\(credentials.accessKeyId)/\(credScope)".urlQueryEncoded),
            ("X-Amz-Date",           amzDate),
            ("X-Amz-Expires",        "\(expiresIn)"),
            ("X-Amz-Security-Token", credentials.sessionToken.urlQueryEncoded),
            ("X-Amz-SignedHeaders",  signedHeaders),
        ]
        queryItems.sort { $0.0 < $1.0 }
        let canonicalQuery = queryItems
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "&")

        // Canonical request
        let canonicalHeaders = "host:\(host)\n"
        let payloadHash      = "UNSIGNED-PAYLOAD"
        let canonicalRequest = [
            "GET", encodedPath, canonicalQuery,
            canonicalHeaders, signedHeaders, payloadHash
        ].joined(separator: "\n")

        // String to sign
        let hashedCR  = sha256Hex(canonicalRequest)
        let stringToSign = "AWS4-HMAC-SHA256\n\(amzDate)\n\(credScope)\n\(hashedCR)"

        // Signing key
        let signingKey = deriveSigningKey(secretKey: credentials.secretKey,
                                          dateStamp: dateStamp,
                                          region: region, service: service)
        let signature  = hmacSHA256Hex(key: signingKey, data: stringToSign)

        // Final URL
        let urlString = "https://\(host)\(encodedPath)?\(canonicalQuery)&X-Amz-Signature=\(signature)"
        return URL(string: urlString)
    }

    // MARK: - Crypto helpers

    private func deriveSigningKey(secretKey: String, dateStamp: String,
                                  region: String, service: String) -> SymmetricKey {
        let kDate    = hmacSHA256(key: SymmetricKey(data: Data(("AWS4" + secretKey).utf8)),
                                  data: dateStamp)
        let kRegion  = hmacSHA256(key: kDate,    data: region)
        let kService = hmacSHA256(key: kRegion,  data: service)
        let kSigning = hmacSHA256(key: kService, data: "aws4_request")
        return kSigning
    }

    private func hmacSHA256(key: SymmetricKey, data: String) -> SymmetricKey {
        let mac = HMAC<SHA256>.authenticationCode(for: Data(data.utf8), using: key)
        return SymmetricKey(data: Data(mac))
    }

    private func hmacSHA256Hex(key: SymmetricKey, data: String) -> String {
        let mac = HMAC<SHA256>.authenticationCode(for: Data(data.utf8), using: key)
        return Data(mac).hexString
    }

    private func sha256Hex(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return Data(digest).hexString
    }

    // MARK: - Date helpers

    private func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }

    private func isoDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return f.string(from: date)
    }

    // MARK: - Errors

    enum PhotoError: LocalizedError {
        case cognitoError(String)
        var errorDescription: String? {
            switch self { case .cognitoError(let m): return m }
        }
    }
}

// MARK: - Extensions

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private extension CharacterSet {
    /// RFC 3986 unreserved characters for URL path components.
    static let urlPathRFC3986: CharacterSet = {
        var cs = CharacterSet.alphanumerics
        cs.insert(charactersIn: "-._~")
        return cs
    }()
}

private extension String {
    var urlQueryEncoded: String {
        var cs = CharacterSet.alphanumerics
        cs.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: cs) ?? self
    }
}

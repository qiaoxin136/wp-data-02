//
//  LocationDataService.swift
//  test
//
//  Queries the Amplify Gen 2 AppSync endpoint directly via URLSession.
//  No Amplify iOS SDK required — just the amplify_outputs.json config file.
//

import Foundation

final class LocationDataService {

    static let shared = LocationDataService()
    private init() { loadConfig() }

    private var endpoint: URL?
    private var apiKey: String = ""
    private(set) var s3BucketName: String = ""
    private(set) var s3Region: String     = "us-east-1"

    // MARK: - Config loading

    private func loadConfig() {
        guard
            let fileURL = Bundle.main.url(forResource: "amplify_outputs",
                                           withExtension: "json"),
            let data = try? Data(contentsOf: fileURL),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dataSection = json["data"] as? [String: Any],
            let rawURL = dataSection["url"] as? String,
            let url   = URL(string: rawURL),
            let key   = dataSection["api_key"] as? String
        else {
            print("⚠️  LocationDataService: could not parse amplify_outputs.json")
            return
        }
        endpoint = url
        apiKey   = key

        // Optional storage config for photo URLs
        if let storage = json["storage"] as? [String: Any] {
            s3BucketName = storage["bucket_name"] as? String ?? ""
            s3Region     = storage["aws_region"]  as? String ?? "us-east-1"
        }
    }

    // MARK: - S3 photo URL helper

    /// Builds a public S3 URL for a photo key stored in the Location record.
    /// Returns nil if storage is not configured or the key looks invalid.
    func photoURL(for key: String) -> URL? {
        guard !s3BucketName.isEmpty,
              !s3BucketName.hasPrefix("REPLACE"),
              !key.isEmpty else { return nil }
        // If the key is already a full URL, return it directly
        if key.hasPrefix("http") { return URL(string: key) }
        let encoded = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        return URL(string: "https://\(s3BucketName).s3.\(s3Region).amazonaws.com/\(encoded)")
    }

    // MARK: - GraphQL query

    private let listLocationsQuery = """
    query ListLocations($limit: Int, $nextToken: String) {
      listLocations(limit: $limit, nextToken: $nextToken) {
        items {
          id date time track type
          diameter length lat lng
          username description photos joint
          createdAt updatedAt
        }
        nextToken
      }
    }
    """

    /// Fetches every Location record, following pagination tokens automatically.
    func fetchAllLocations() async throws -> [LocationRecord] {
        guard let endpoint else {
            throw ServiceError.notConfigured
        }

        var all: [LocationRecord] = []
        var nextToken: String?    = nil

        repeat {
            var variables: [String: Any] = ["limit": 1000]
            if let token = nextToken { variables["nextToken"] = token }

            let body: [String: Any] = [
                "query":     listLocationsQuery,
                "variables": variables
            ]

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey,             forHTTPHeaderField: "x-api-key")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw ServiceError.httpError(http.statusCode)
            }

            let decoded = try JSONDecoder().decode(GraphQLResponse.self, from: data)

            if let errors = decoded.errors, !errors.isEmpty {
                throw ServiceError.graphQL(errors.map(\.message).joined(separator: "; "))
            }

            guard let items = decoded.data?.listLocations.items else { break }
            all.append(contentsOf: items)
            nextToken = decoded.data?.listLocations.nextToken

        } while nextToken != nil

        return all
    }

    // MARK: - Create mutation

    private let createLocationMutation = """
    mutation CreateLocation($input: CreateLocationInput!) {
      createLocation(input: $input) {
        id date time track type
        diameter length lat lng
        username description photos joint
        createdAt updatedAt
      }
    }
    """

    func createLocation(input: CreateLocationInput) async throws -> LocationRecord {
        guard let endpoint else { throw ServiceError.notConfigured }

        var inputMap: [String: Any] = [
            "date":     input.date,
            "track":    input.track,
            "diameter": input.diameter,
            "length":   input.length,
            "lat":      input.lat,
            "lng":      input.lng,
        ]
        if let v = input.time        { inputMap["time"]        = v }
        if let v = input.type        { inputMap["type"]        = v }
        if let v = input.username    { inputMap["username"]    = v }
        if let v = input.description { inputMap["description"] = v }
        if let v = input.joint       { inputMap["joint"]       = v }
        if !input.photos.isEmpty     { inputMap["photos"]      = input.photos }

        let body: [String: Any] = [
            "query":     createLocationMutation,
            "variables": ["input": inputMap]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        #if DEBUG
        print("── createLocation request ──────────────────────────────")
        print(String(data: bodyData, encoding: .utf8) ?? "<unreadable>")
        #endif

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey,             forHTTPHeaderField: "x-api-key")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)

        #if DEBUG
        print("── createLocation response ─────────────────────────────")
        print(String(data: data, encoding: .utf8) ?? "<unreadable>")
        #endif

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ServiceError.httpError(http.statusCode)
        }

        struct CreateResponse: Codable {
            struct GQLData: Codable { let createLocation: LocationRecord }
            let data: GQLData?
            let errors: [GraphQLError]?
        }
        let decoded = try JSONDecoder().decode(CreateResponse.self, from: data)
        if let errors = decoded.errors, !errors.isEmpty {
            throw ServiceError.graphQL(errors.map(\.message).joined(separator: "; "))
        }
        guard let record = decoded.data?.createLocation else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.graphQL("No record in response: \(raw)")
        }
        return record
    }

    // MARK: - Delete mutation

    private let deleteLocationMutation = """
    mutation DeleteLocation($input: DeleteLocationInput!) {
      deleteLocation(input: $input) {
        id
      }
    }
    """

    func deleteLocation(id: String) async throws {
        guard let endpoint else { throw ServiceError.notConfigured }

        let body: [String: Any] = [
            "query":     deleteLocationMutation,
            "variables": ["input": ["id": id]]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey,             forHTTPHeaderField: "x-api-key")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ServiceError.httpError(http.statusCode)
        }

        struct DeleteResponse: Codable {
            struct GQLData: Codable { let deleteLocation: DeletedItem? }
            struct DeletedItem: Codable { let id: String }
            let data: GQLData?
            let errors: [GraphQLError]?
        }
        let decoded = try JSONDecoder().decode(DeleteResponse.self, from: data)
        if let errors = decoded.errors, !errors.isEmpty {
            throw ServiceError.graphQL(errors.map(\.message).joined(separator: "; "))
        }
    }

    // MARK: - Errors

    enum ServiceError: LocalizedError {
        case notConfigured
        case httpError(Int)
        case graphQL(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "amplify_outputs.json is missing or incomplete."
            case .httpError(let code):
                return "HTTP \(code) from AppSync."
            case .graphQL(let msg):
                return "GraphQL error: \(msg)"
            }
        }
    }
}

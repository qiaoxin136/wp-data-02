//
//  LocationRecord.swift
//  test
//

import CoreLocation
import UIKit

// MARK: - Domain Model

struct LocationRecord: Identifiable, Codable {
    let id: String
    let date: String
    let time: String?
    let track: Int
    let type: String?
    let diameter: Double
    let length: Double
    let lat: Double
    let lng: Double
    let username: String?
    let description: String?
    let photos: [String?]?
    let joint: Bool?
    let createdAt: String?
    let updatedAt: String?

    /// Non-nil photo keys (filters out null entries in the array).
    var photoKeys: [String] {
        photos?.compactMap { $0 } ?? []
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Pin colour keyed on actual type strings found in the database.
    /// Uses explicit RGB values so colours render correctly inside UIGraphicsImageRenderer.
    var markerColor: UIColor { Self.colorForType(type) }

    /// Static version so `NewLocationForm` can reference it without an instance.
    static func colorForType(_ type: String?) -> UIColor {
        switch type?.lowercased() {
        case "water":       return UIColor(red: 0.20, green: 0.45, blue: 1.00, alpha: 1) // blue
        case "wastewater":  return UIColor(red: 0.18, green: 0.75, blue: 0.30, alpha: 1) // green
        case "stormwater":  return UIColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1) // orange
        case "pavement":    return UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1) // grey
        default:            return UIColor(red: 0.00, green: 0.70, blue: 0.75, alpha: 1) // teal
        }
    }
}

// MARK: - Create Input

struct CreateLocationInput {
    let date: String
    let time: String?
    let track: Int
    let type: String?
    let diameter: Double
    let length: Double
    let lat: Double
    let lng: Double
    let username: String?
    let description: String?
    let joint: Bool?
    var photos: [String] = []
}

// MARK: - GraphQL Response Envelope

struct GraphQLResponse: Codable {
    let data: GraphQLData?
    let errors: [GraphQLError]?
}

struct GraphQLError: Codable {
    let message: String
}

struct GraphQLData: Codable {
    let listLocations: LocationConnection
}

struct LocationConnection: Codable {
    let items: [LocationRecord]
    let nextToken: String?
}

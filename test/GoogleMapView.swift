//
//  GoogleMapView.swift
//  test
//
//  UIViewRepresentable that wraps GMSMapView.
//  Handles data pins, user-location balloon, tap-to-place, and camera control.
//

import SwiftUI
import GoogleMaps
import CoreLocation
import UIKit

// MARK: - Map style: hide POIs & transit, keep roads + addresses

private let mapStyleJSON = """
[
  {"featureType":"poi",          "stylers":[{"visibility":"off"}]},
  {"featureType":"poi.business", "stylers":[{"visibility":"off"}]},
  {"featureType":"transit",      "stylers":[{"visibility":"off"}]}
]
"""

// MARK: - GoogleMapView

struct GoogleMapView: UIViewRepresentable {

    // ── Data ─────────────────────────────────────────────────────────────
    var records: [LocationRecord]

    // ── User balloon ──────────────────────────────────────────────────────
    var userCoord: CLLocationCoordinate2D?
    var showUserBalloon: Bool
    var onBalloonTapped: () -> Void      // tap on balloon → dismiss

    // ── Placement mode ────────────────────────────────────────────────────
    var isPlacingPin: Bool
    var onMapTapped:    (CLLocationCoordinate2D) -> Void
    var onRecordTapped: (LocationRecord) -> Void

    // ── Camera commands (token-based to prevent spurious re-animates) ─────
    var zoomToFitToken:  Int
    var zoomToCoord:     CLLocationCoordinate2D?
    var zoomToCoordToken: Int

    // MARK: makeUIView

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(
            target: CLLocationCoordinate2D(latitude: 26.0112, longitude: -80.1495),
            zoom: 14
        )
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.delegate = context.coordinator
        mapView.settings.compassButton = true
        mapView.settings.myLocationButton = false
        if let style = try? GMSMapStyle(jsonString: mapStyleJSON) {
            mapView.mapStyle = style
        }
        return mapView
    }

    // MARK: updateUIView

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        let c = context.coordinator
        c.parent = self

        // Rebuild markers only when records or balloon actually changed
        let newIDs = records.map(\.id)
        let balloonChanged = showUserBalloon != c.lastShowBalloon
            || userCoord?.latitude  != c.lastUserCoord?.latitude
            || userCoord?.longitude != c.lastUserCoord?.longitude

        if newIDs != c.lastRecordIDs || balloonChanged {
            mapView.clear()

            for record in records {
                let marker = GMSMarker(position: record.coordinate)
                marker.iconView  = makeCircleView(color: UIColor(Color(record.markerColor)))
                marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                marker.userData  = record
                marker.map       = mapView
            }

            if showUserBalloon, let uc = userCoord {
                let balloon = GMSMarker(position: uc)
                balloon.iconView    = makeBalloonView()
                balloon.groundAnchor = CGPoint(x: 0.5, y: 1.0)
                balloon.userData    = "userBalloon"
                balloon.map         = mapView
            }

            c.lastRecordIDs   = newIDs
            c.lastShowBalloon = showUserBalloon
            c.lastUserCoord   = userCoord
        }

        // Camera: zoom to fit all records
        if zoomToFitToken != c.lastFitToken {
            c.lastFitToken = zoomToFitToken
            if records.count == 1 {
                mapView.animate(to: GMSCameraPosition(target: records[0].coordinate, zoom: 16))
            } else if records.count > 1 {
                var bounds = GMSCoordinateBounds()
                for r in records { bounds = bounds.includingCoordinate(r.coordinate) }
                mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 60))
            }
        }

        // Camera: zoom to user location
        if zoomToCoordToken != c.lastCoordToken, let target = zoomToCoord {
            c.lastCoordToken = zoomToCoordToken
            mapView.animate(to: GMSCameraPosition(target: target, zoom: 17))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Pin icon (small coloured ring, transparent fill)

    private func makeCircleView(color: UIColor) -> UIView {
        let size: CGFloat = 14
        let view = UIView(frame: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
        view.backgroundColor = .clear
        view.isOpaque = false
        let ring = CAShapeLayer()
        ring.path        = UIBezierPath(ovalIn: CGRect(x: 1, y: 1, width: size - 2, height: size - 2)).cgPath
        ring.strokeColor = color.cgColor
        ring.fillColor   = UIColor.clear.cgColor
        ring.lineWidth   = 2
        view.layer.addSublayer(ring)
        return view
    }

    // MARK: - Balloon icon (red circle + pointer + × symbol)
    // Uses UIImageView with a SF Symbol instead of UILabel to avoid triggering
    // CoreText glyph shaping (shape_accum_add) on the main thread.

    private static let balloonImage: UIImage = {
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        return UIImage(systemName: "xmark", withConfiguration: cfg)?
            .withTintColor(.white, renderingMode: .alwaysOriginal) ?? UIImage()
    }()

    private func makeBalloonView() -> UIView {
        let balloonD: CGFloat = 36
        let pointerH: CGFloat = 10
        let totalH = balloonD + pointerH

        let view = UIView(frame: CGRect(origin: .zero, size: CGSize(width: balloonD, height: totalH)))
        view.backgroundColor = .clear
        view.isOpaque = false

        // Red circle body
        let circle = UIView(frame: CGRect(x: 0, y: 0, width: balloonD, height: balloonD))
        circle.backgroundColor    = .systemRed
        circle.layer.cornerRadius = balloonD / 2
        circle.layer.shadowColor  = UIColor.black.cgColor
        circle.layer.shadowOpacity = 0.3
        circle.layer.shadowRadius  = 3
        circle.layer.shadowOffset  = CGSize(width: 0, height: 2)
        circle.clipsToBounds = false
        view.addSubview(circle)

        // × icon — pre-rendered SF Symbol avoids CoreText shaping on every call
        let iconSize: CGFloat = 16
        let iconOrigin = CGPoint(x: (balloonD - iconSize) / 2, y: (balloonD - iconSize) / 2)
        let xIcon = UIImageView(frame: CGRect(origin: iconOrigin, size: CGSize(width: iconSize, height: iconSize)))
        xIcon.image = GoogleMapView.balloonImage
        xIcon.contentMode = .scaleAspectFit
        circle.addSubview(xIcon)

        // Downward-pointing triangle
        let pointer = CAShapeLayer()
        let path = UIBezierPath()
        let cx = balloonD / 2
        path.move(to:    CGPoint(x: cx - 6, y: balloonD))
        path.addLine(to: CGPoint(x: cx + 6, y: balloonD))
        path.addLine(to: CGPoint(x: cx,     y: balloonD + pointerH))
        path.close()
        pointer.path      = path.cgPath
        pointer.fillColor = UIColor.systemRed.cgColor
        view.layer.addSublayer(pointer)

        return view
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, GMSMapViewDelegate {

        var parent: GoogleMapView

        var lastRecordIDs:   [String] = []
        var lastShowBalloon  = false
        var lastUserCoord:   CLLocationCoordinate2D? = nil
        var lastFitToken     = -1
        var lastCoordToken   = -1

        init(_ parent: GoogleMapView) { self.parent = parent }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            guard parent.isPlacingPin else { return }
            parent.onMapTapped(coordinate)
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if parent.isPlacingPin { return true }
            if marker.userData is String {
                parent.onBalloonTapped()
            } else if let record = marker.userData as? LocationRecord {
                parent.onRecordTapped(record)
            }
            return true   // suppress default info window
        }
    }
}

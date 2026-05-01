//
//  ContentView.swift
//  test
//
//  Map screen shown after login. Displays location records as pins on Google Maps,
//  supports geolocating the user, and creating / deleting records by tapping the map.
//

import SwiftUI
import CoreLocation

struct ContentView: View {

    private let auth    = AuthService.shared
    private let service = LocationDataService.shared

    @State private var records: [LocationRecord] = []
    @State private var isLoading = false
    @State private var errorMsg: String?

    @State private var selectedRecord: LocationRecord?

    // Geolocation
    @State private var locTracker  = LocationTracker()
    @State private var userCoord: CLLocationCoordinate2D? = nil
    @State private var showBalloon = false

    // New pin placement
    @State private var isPlacingPin  = false
    @State private var newPinCoord: CLLocationCoordinate2D? = nil
    @State private var showNewForm   = false

    // Camera commands (token-based → GoogleMapView only acts when token changes)
    @State private var zoomToFitToken:   Int = 0
    @State private var zoomToCoordToken: Int = 0
    @State private var pendingZoomCoord: CLLocationCoordinate2D? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer

            // Placement mode banner
            if isPlacingPin {
                placementBanner
                    .zIndex(2)
            }

            // Detail card
            if let record = selectedRecord {
                LocationDetailCard(record: record,
                                   onDismiss: { selectedRecord = nil },
                                   onDelete:  { Task { await deleteRecord(record) } })
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }

            // Toolbar overlay (hidden while placing)
            if !isPlacingPin && selectedRecord == nil {
                toolbarOverlay
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedRecord?.id)
        .animation(.easeInOut(duration: 0.2), value: isPlacingPin)
        .sheet(isPresented: $showNewForm) {
            if let coord = newPinCoord {
                NewLocationForm(
                    coordinate: coord,
                    locationRecords: records,
                    onSave: { newRecord in
                        records.append(newRecord)
                        showNewForm = false
                    },
                    onDismiss: { showNewForm = false }
                )
            }
        }
        .task { await loadRecords() }
        .alert("Error", isPresented: Binding(
            get: { errorMsg != nil },
            set: { if !$0 { errorMsg = nil } }
        )) {
            Button("OK") { errorMsg = nil }
        } message: {
            Text(errorMsg ?? "")
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        GoogleMapView(
            records: records,
            userCoord: userCoord,
            showUserBalloon: showBalloon,
            onBalloonTapped: {
                withAnimation { showBalloon = false }
            },
            isPlacingPin: isPlacingPin,
            onMapTapped: { coord in
                newPinCoord  = coord
                isPlacingPin = false
                showNewForm  = true
            },
            onRecordTapped: { record in
                withAnimation { selectedRecord = record }
            },
            zoomToFitToken:  zoomToFitToken,
            zoomToCoord:     pendingZoomCoord,
            zoomToCoordToken: zoomToCoordToken
        )
        .ignoresSafeArea()
    }

    // MARK: - Placement banner

    private var placementBanner: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.red)
                Text("Tap the map to place a new point")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button("Cancel") {
                    isPlacingPin = false
                }
                .foregroundStyle(.red)
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            Spacer()
        }
    }

    // MARK: - Toolbar

    private var toolbarOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Washington Park")
                    .font(.headline)
                Spacer()
                if isLoading { ProgressView() }
                Button { Task { await loadRecords() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                Button { geolocate() } label: {
                    Image(systemName: "location.fill")
                }
                // New button
                Button {
                    selectedRecord = nil
                    isPlacingPin   = true
                } label: {
                    Text("New")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.red)
                        .clipShape(Capsule())
                }
                Button { auth.signOut() } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            Spacer()
        }
    }

    // MARK: - Actions

    private func geolocate() {
        locTracker.requestLocation { coord in
            userCoord        = coord
            showBalloon      = true
            pendingZoomCoord = coord
            zoomToCoordToken += 1
        }
    }

    private func loadRecords() async {
        isLoading = true
        do {
            records = try await service.fetchAllLocations()
            zoomToFitToken += 1
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteRecord(_ record: LocationRecord) async {
        do {
            try await service.deleteLocation(id: record.id)
            records.removeAll { $0.id == record.id }
            selectedRecord = nil
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}

// MARK: - Location tracker

// CLLocationManager must be created and used on the main thread.
@MainActor
final class LocationTracker: NSObject, CLLocationManagerDelegate {

    private let manager  = CLLocationManager()
    private var callback: ((CLLocationCoordinate2D) -> Void)?

    override init() {
        super.init()
        manager.delegate        = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation(_ callback: @escaping (CLLocationCoordinate2D) -> Void) {
        self.callback = callback
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.last?.coordinate else { return }
        Task { @MainActor in
            callback?(coord)
            callback = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationTracker error:", error.localizedDescription)
    }
}

#Preview {
    ContentView()
}

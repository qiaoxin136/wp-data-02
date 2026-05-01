//
//  NewLocationForm.swift
//  test
//
//  Sheet form for creating a new Location record with optional photos.
//

import SwiftUI
import PhotosUI
import CoreLocation

// MARK: - Photo item (tracks per-photo upload state)

private struct PhotoItem: Identifiable {
    let id   = UUID()
    let image: UIImage
    var s3Key:       String? = nil   // nil = not yet uploaded
    var isUploading: Bool    = false
    var uploadFailed: Bool   = false

    var isUploaded: Bool { s3Key != nil }
}

// MARK: - Form

struct NewLocationForm: View {
    let coordinate: CLLocationCoordinate2D
    let locationRecords: [LocationRecord]          // existing points for distance calc
    var onSave: (LocationRecord) -> Void
    var onDismiss: () -> Void

    // ── Form fields ──────────────────────────────────────────────────
    @State private var date         = Self.todayString()
    @State private var time         = Self.nowTimeString()
    @State private var trackText    = ""
    @State private var type         = "water"
    @State private var diameterText = ""
    @State private var lengthText   = ""
    @State private var lengthSource: String? = nil  // caption shown under Length row
    @State private var username     = AuthService.shared.username ?? ""
    @State private var description  = ""
    @State private var joint        = false

    // ── Photos ───────────────────────────────────────────────────────
    @State private var photos: [PhotoItem] = []
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showSourceDialog      = false
    @State private var showCamera            = false
    @State private var showTakeAnotherDialog = false  // after each camera shot
    @State private var isUploading           = false
    @State private var uploadCount           = 0      // progress numerator
    @State private var uploadTotal           = 0      // progress denominator

    // ── Save state ───────────────────────────────────────────────────
    @State private var isSaving    = false
    @State private var saveError:  String?
    @State private var showSaveErrorAlert = false

    @State private var showPhotoPickerPresented = false

    private let typeOptions = ["water", "wastewater", "stormwater", "pavement"]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Scrollable form ──────────────────────────────────
                Form {
                    Section("Location") {
                        LabeledContent("Latitude",
                            value: String(format: "%.6f", coordinate.latitude))
                        LabeledContent("Longitude",
                            value: String(format: "%.6f", coordinate.longitude))
                    }

                    Section("Classification") {
                        Picker("Type", selection: $type) {
                            ForEach(typeOptions, id: \.self) { t in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(LocationRecord.colorForType(t)))
                                        .frame(width: 10, height: 10)
                                    Text(t.capitalized)
                                }.tag(t)
                            }
                        }
                        .pickerStyle(.menu)

                        HStack {
                            Text("Track")
                            Spacer()
                            TextField("e.g. 1", text: $trackText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .onChange(of: trackText) { _, _ in autoFillLength() }
                        }
                        Toggle("Joint", isOn: $joint)
                    }

                    Section("Measurements") {
                        HStack {
                            Text("Diameter (in)")
                            Spacer()
                            TextField("e.g. 8", text: $diameterText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Length (ft)")
                                Spacer()
                                TextField("auto", text: $lengthText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                            }
                            if let src = lengthSource {
                                Text(src)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Date & Time") {
                        HStack {
                            Text("Date")
                            Spacer()
                            TextField("YYYY-MM-DD", text: $date)
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 130)
                        }
                        HStack {
                            Text("Time")
                            Spacer()
                            TextField("HH:mm:ss", text: $time)
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 130)
                        }
                    }

                    Section("Personnel") {
                        HStack {
                            Text("Username")
                            Spacer()
                            TextField("optional", text: $username)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Section("Notes") {
                        TextField("Description (optional)",
                                  text: $description, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    // ── Photo thumbnails ─────────────────────────────
                    if !photos.isEmpty {
                        Section(photoSectionTitle) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(photos.indices, id: \.self) { idx in
                                        photoThumbnail(idx: idx)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                            .listRowInsets(.init(top: 8, leading: 12, bottom: 8, trailing: 12))
                        }
                    }

                }   // end Form
                // ── Keyboard toolbar: down-arrow dismiss button ──────
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil)
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.system(size: 17, weight: .medium))
                        }
                    }
                }

                // ── Bottom button bar: [Photo] | [Upload] ────────────
                bottomBar
            }
            .navigationTitle("New Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                        .disabled(isSaving || isUploading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.8)
                            Text("Saving…").font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Save") { Task { await save() } }
                            .fontWeight(.semibold)
                            .disabled(!isValid || isUploading)
                    }
                }
            }
            // Save error alert
            .alert("Save Failed", isPresented: $showSaveErrorAlert, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(saveError ?? "Unknown error")
            })
            // Source choice
            .confirmationDialog("Add Photo", isPresented: $showSourceDialog,
                                titleVisibility: .visible) {
                Button("Photo Library") { showPhotoPickerPresented = true }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") { showCamera = true }
                }
                Button("Cancel", role: .cancel) {}
            }
            // "Take another?" after each camera shot
            .confirmationDialog("Photo added", isPresented: $showTakeAnotherDialog,
                                titleVisibility: .visible) {
                Button("Take Another Photo") { showCamera = true }
                Button("Done", role: .cancel) {}
            }
            // Camera
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(source: .camera) { img in
                    photos.append(PhotoItem(image: img))
                    showCamera = false
                    showTakeAnotherDialog = true   // ask for another
                } onCancel: {
                    showCamera = false
                }
                .ignoresSafeArea()
            }
            // Photo library
            .photosPicker(isPresented: $showPhotoPickerPresented,
                          selection: $photoPickerItems,
                          maxSelectionCount: 20,
                          matching: .images)
            .onChange(of: photoPickerItems) { _, items in
                Task {
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let img  = UIImage(data: data) {
                            photos.append(PhotoItem(image: img))
                        }
                    }
                    photoPickerItems = []
                }
            }
        }
    }

    // MARK: - Photo thumbnail

    @ViewBuilder
    private func photoThumbnail(idx: Int) -> some View {
        let photo = photos[idx]
        ZStack(alignment: .topTrailing) {
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFill()
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .clipped()
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(photo.isUploaded ? Color.green : Color.clear, lineWidth: 2)
                )

            // Status badge (top-right)
            if photo.isUploading {
                ProgressView()
                    .tint(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.5), in: Circle())
                    .offset(x: 6, y: -6)
            } else if photo.isUploaded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .green)
                    .offset(x: 6, y: -6)
            } else if photo.uploadFailed {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red)
                    .offset(x: 6, y: -6)
            } else {
                // Remove button (only for not-yet-uploaded photos)
                Button {
                    photos.remove(at: idx)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .offset(x: 6, y: -6)
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {

                // ── Photo button ─────────────────────────────────────
                Button { showSourceDialog = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Photo")
                            .font(.system(size: 13, weight: .semibold))
                        if !photos.isEmpty {
                            Text("(\(photos.count))")
                                .font(.system(size: 12, weight: .medium))
                                .opacity(0.85)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.green)
                }
                .disabled(isSaving)

                // Vertical divider
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 1)

                // ── Upload button ────────────────────────────────────
                Button { Task { await uploadPhotos() } } label: {
                    HStack(spacing: 5) {
                        if isUploading {
                            ProgressView().tint(.white).scaleEffect(0.75)
                            Text("\(uploadCount)/\(uploadTotal)")
                                .font(.system(size: 13, weight: .semibold))
                        } else if allUploaded && !photos.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Uploaded")
                                .font(.system(size: 13, weight: .semibold))
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Upload")
                                .font(.system(size: 13, weight: .semibold))
                            if pendingCount > 0 {
                                Text("(\(pendingCount))")
                                    .font(.system(size: 12, weight: .medium))
                                    .opacity(0.85)
                            }
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(uploadButtonColor)
                }
                .disabled(pendingCount == 0 || isUploading || isSaving)
            }
            // Extend button colors into safe area
            HStack(spacing: 0) {
                Color.green.frame(maxWidth: .infinity)
                uploadButtonColor.frame(maxWidth: .infinity)
            }
            .frame(height: 0)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Computed helpers

    private var pendingCount: Int  { photos.filter { !$0.isUploaded }.count }
    private var allUploaded: Bool  { !photos.isEmpty && pendingCount == 0 }

    private var uploadButtonColor: Color {
        if allUploaded            { return Color(red: 0.20, green: 0.60, blue: 0.20) } // dim green
        if isUploading            { return Color.orange }
        if pendingCount > 0       { return Color.orange }
        return Color.gray
    }

    private var photoSectionTitle: String {
        let total    = photos.count
        let uploaded = photos.filter { $0.isUploaded }.count
        if total == 0 { return "Photos" }
        if uploaded == total { return "Photos (\(total) ✓)" }
        return "Photos (\(uploaded)/\(total) uploaded)"
    }

    // MARK: - Upload

    private func uploadPhotos() async {
        let pending = photos.indices.filter { !photos[$0].isUploaded && !photos[$0].isUploading }
        guard !pending.isEmpty else { return }

        isUploading  = true
        uploadCount  = 0
        uploadTotal  = pending.count

        for idx in pending {
            photos[idx].isUploading  = true
            photos[idx].uploadFailed = false
            uploadCount += 1

            guard let jpeg = photos[idx].image.jpegData(compressionQuality: 0.82) else {
                photos[idx].isUploading  = false
                photos[idx].uploadFailed = true
                continue
            }
            let key = "originals/\(UUID().uuidString)/photo_\(uploadCount).jpg"
            do {
                try await AWSPhotoService.shared.uploadPhoto(imageData: jpeg, key: key)
                photos[idx].s3Key      = key
                photos[idx].isUploading = false
            } catch {
                photos[idx].isUploading  = false
                photos[idx].uploadFailed = true
                print("Upload failed for photo \(uploadCount): \(error)")
            }
        }
        isUploading = false
    }

    // MARK: - Save

    private var isValid: Bool {
        !date.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(trackText)    != nil &&
        Double(diameterText) != nil &&
        Double(lengthText)   != nil
    }

    private func save() async {
        guard isValid else { return }
        isSaving  = true
        saveError = nil

        // Upload any remaining un-uploaded photos first
        if pendingCount > 0 { await uploadPhotos() }

        // Collect keys
        let photoKeys = photos.compactMap { $0.s3Key }

        // Create record
        var input = CreateLocationInput(
            date:        date.trimmingCharacters(in: .whitespaces),
            time:        time.isEmpty ? nil : time.trimmingCharacters(in: .whitespaces),
            track:       Int(trackText) ?? 0,
            type:        type,
            diameter:    Double(diameterText) ?? 0,
            length:      Double(lengthText)   ?? 0,
            lat:         coordinate.latitude,
            lng:         coordinate.longitude,
            username:    username.isEmpty    ? nil : username,
            description: description.isEmpty ? nil : description,
            joint:       joint
        )
        input.photos = photoKeys

        do {
            let created = try await LocationDataService.shared.createLocation(input: input)
            // Success — dismiss the form and add the new pin to the map
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await MainActor.run { onSave(created) }
        } catch {
            await MainActor.run {
                saveError         = error.localizedDescription
                showSaveErrorAlert = true
                isSaving          = false
            }
        }
    }

    // MARK: - Auto-fill length from previous track point

    /// Finds the most-recent record on the same track, computes the straight-line
    /// distance in feet to `coordinate`, and writes it into `lengthText`.
    private func autoFillLength() {
        guard let trackNum = Int(trackText) else {
            lengthText  = ""
            lengthSource = nil
            return
        }

        let same = locationRecords.filter { $0.track == trackNum }

        guard !same.isEmpty else {
            lengthText   = "0"
            lengthSource = "No previous point on track \(trackNum) — set to 0"
            return
        }

        // Sort descending by date+time; pick the most recent.
        let sorted = same.sorted {
            (parseDateTime(date: $0.date, time: $0.time) ?? .distantPast) >
            (parseDateTime(date: $1.date, time: $1.time) ?? .distantPast)
        }
        let prev = sorted[0]

        let prevLoc = CLLocation(latitude: prev.lat, longitude: prev.lng)
        let newLoc  = CLLocation(latitude: coordinate.latitude,
                                 longitude: coordinate.longitude)
        let feet = newLoc.distance(from: prevLoc) * 3.28084

        lengthText   = String(format: "%.1f", feet)
        lengthSource = "Auto: dist from track \(trackNum) prev pt (\(String(format: "%.1f", feet)) ft)"
    }

    /// Parses a `yyyy-MM-dd` date and optional `HH:mm:ss` time into a `Date`.
    private func parseDateTime(date: String, time: String?) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        if let t = time, !t.isEmpty {
            f.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return f.date(from: "\(date) \(t)")
        }
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: date)
    }

    // MARK: - Date / time defaults

    private static func todayString() -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    private static func nowTimeString() -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss"; return f.string(from: Date())
    }
}

// MARK: - Preview

#Preview {
    NewLocationForm(
        coordinate: CLLocationCoordinate2D(latitude: 26.0112, longitude: -80.1495),
        locationRecords: [],
        onSave: { _ in },
        onDismiss: {}
    )
}

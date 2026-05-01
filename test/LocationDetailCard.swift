//
//  LocationDetailCard.swift
//  test
//

import SwiftUI

struct LocationDetailCard: View {
    let record: LocationRecord
    var onDismiss: () -> Void
    var onDelete: () -> Void = {}

    @State private var photoURLs: [URL] = []
    @State private var isLoadingPhotos = false
    @State private var currentPhotoIndex = 0
    @State private var showPhotoViewer = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Drag handle ───────────────────────────────────────────
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.systemGray4))
                    .frame(width: 40, height: 5)
                Spacer()
            }
            .padding(.top, 10)
            .padding(.bottom, 8)

            // ── Header ────────────────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color(record.markerColor))
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Type \(record.type ?? "—")")
                        .font(.headline)
                    HStack(spacing: 8) {
                        Label("Track \(record.track)", systemImage: "number")
                        if let user = record.username {
                            Label(user, systemImage: "person.circle")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Photo gallery ─────────────────────────────────
                    if isLoadingPhotos {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text("Loading photos…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    } else if !photoURLs.isEmpty {
                        photoCarousel
                        Divider()
                    }

                    // ── Attribute grid ────────────────────────────────
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        AttrTile(label: "Date",     value: record.date)
                        AttrTile(label: "Time",     value: record.time ?? "—")
                        AttrTile(label: "Diameter", value: "\(fmt(record.diameter)) in")
                        AttrTile(label: "Length",   value: "\(fmt(record.length)) ft")
                        AttrTile(label: "Track",    value: "\(record.track)")
                        AttrTile(label: "Joint",    value: record.joint == true  ? "Yes"
                                                         : record.joint == false ? "No" : "—")
                        AttrTile(label: "Lat",      value: String(format: "%.5f", record.lat))
                        AttrTile(label: "Lng",      value: String(format: "%.5f", record.lng))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // ── Description ───────────────────────────────────
                    if let desc = record.description, !desc.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Description", systemImage: "text.alignleft")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(desc)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }

                    // ── Photo keys fallback ───────────────────────────
                    if !record.photoKeys.isEmpty && photoURLs.isEmpty && !isLoadingPhotos {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Label("\(record.photoKeys.count) photo(s) — could not load from S3",
                                  systemImage: "photo.on.rectangle.angled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
            }
            .frame(maxHeight: 420)

            // ── Delete button ─────────────────────────────────────────
            Divider()

            Button {
                showDeleteConfirm = true
            } label: {
                HStack(spacing: 6) {
                    if isDeleting {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text(isDeleting ? "Deleting…" : "Delete")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isDeleting ? Color.red.opacity(0.6) : Color.red)
            }
            .disabled(isDeleting)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .alert("Delete this point?",
               isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the record and cannot be undone.")
        }
        // ── Full-screen photo viewer ─────────────────────────────────
        .fullScreenCover(isPresented: $showPhotoViewer) {
            PhotoViewer(urls: photoURLs, initialIndex: currentPhotoIndex)
        }
        // ── Load pre-signed photo URLs whenever the record changes ───
        .task(id: record.id) {
            guard !record.photoKeys.isEmpty else { return }
            isLoadingPhotos = true
            photoURLs = []
            currentPhotoIndex = 0
            var urls: [URL] = []
            for key in record.photoKeys {
                if let url = await AWSPhotoService.shared.presignedURL(for: key) {
                    urls.append(url)
                }
            }
            photoURLs = urls
            isLoadingPhotos = false
        }
    }

    // MARK: - Photo carousel

    private var photoCarousel: some View {
        let total = photoURLs.count
        return ZStack {

            // ── Main photo ────────────────────────────────────────────
            AsyncImage(url: photoURLs[currentPhotoIndex]) { phase in
                switch phase {
                case .success(let img):
                    img
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "photo.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemBackground))
                default:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemBackground))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { showPhotoViewer = true }
            .id(currentPhotoIndex)   // re-renders on index change

            // ── Navigation arrows (only when >1 photo) ────────────────
            if total > 1 {
                HStack {
                    // Previous
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentPhotoIndex = max(0, currentPhotoIndex - 1)
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.black.opacity(currentPhotoIndex > 0 ? 0.45 : 0.15),
                                        in: Circle())
                    }
                    .disabled(currentPhotoIndex == 0)
                    .padding(.leading, 10)

                    Spacer()

                    // Next
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentPhotoIndex = min(total - 1, currentPhotoIndex + 1)
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.black.opacity(currentPhotoIndex < total - 1 ? 0.45 : 0.15),
                                        in: Circle())
                    }
                    .disabled(currentPhotoIndex == total - 1)
                    .padding(.trailing, 10)
                }
            }

            // ── Page counter badge ────────────────────────────────────
            if total > 1 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(currentPhotoIndex + 1) / \(total)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.5), in: Capsule())
                            .padding(8)
                    }
                }
            }
        }
        .frame(height: 200)
    }

    // MARK: - Helpers

    private func fmt(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v))
                                                   : String(format: "%.1f", v)
    }
}

// MARK: - Attribute Tile

private struct AttrTile: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Full-screen photo viewer

struct PhotoViewer: View {
    let urls: [URL]
    var initialIndex: Int = 0

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            // ── Photo ─────────────────────────────────────────────────
            AsyncImage(url: urls[currentIndex]) { phase in
                switch phase {
                case .success(let img):
                    img
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { scale = max(1, $0) }
                                .simultaneously(with:
                                    DragGesture()
                                        .onChanged { offset = $0.translation }
                                        .onEnded  { _ in
                                            if scale <= 1 { offset = .zero }
                                        }
                                )
                        )
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "photo.slash").font(.system(size: 48))
                        Text("Could not load photo").font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                default:
                    ProgressView()
                }
            }
            .ignoresSafeArea()
            .id(currentIndex)   // force re-render on index change

            // ── Top bar: close + counter ──────────────────────────────
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.5))
                }

                Spacer()

                if urls.count > 1 {
                    Text("\(currentIndex + 1) / \(urls.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.45), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)

            // ── Side navigation arrows ────────────────────────────────
            if urls.count > 1 {
                HStack {
                    Button {
                        resetZoom()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentIndex = max(0, currentIndex - 1)
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(Color.black.opacity(currentIndex > 0 ? 0.45 : 0.15),
                                        in: Circle())
                    }
                    .disabled(currentIndex == 0)

                    Spacer()

                    Button {
                        resetZoom()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentIndex = min(urls.count - 1, currentIndex + 1)
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(Color.black.opacity(currentIndex < urls.count - 1 ? 0.45 : 0.15),
                                        in: Circle())
                    }
                    .disabled(currentIndex == urls.count - 1)
                }
                .padding(.horizontal, 12)
            }

            // ── Dot page indicator (bottom) ───────────────────────────
            if urls.count > 1 {
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<urls.count, id: \.self) { i in
                            Circle()
                                .fill(i == currentIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: i == currentIndex ? 8 : 6,
                                       height: i == currentIndex ? 8 : 6)
                                .animation(.easeInOut(duration: 0.15), value: currentIndex)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { currentIndex = initialIndex }
    }

    private func resetZoom() {
        scale  = 1
        offset = .zero
    }
}

// MARK: - Preview

#Preview {
    ZStack(alignment: .bottom) {
        Color.gray.opacity(0.3).ignoresSafeArea()
        LocationDetailCard(record: LocationRecord(
            id: "1", date: "2024-06-15", time: "09:30:00",
            track: 3, type: "2", diameter: 8, length: 240,
            lat: 26.0112, lng: -80.1495,
            username: "inspector01",
            description: "Main line replacement at intersection",
            photos: ["originals/sample.jpg"],
            joint: false, createdAt: nil, updatedAt: nil
        )) {}
    }
}

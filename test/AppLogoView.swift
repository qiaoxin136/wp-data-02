//
//  AppLogoView.swift
//  test
//
//  Created by Xin Qiao on 4/16/26.
//

import SwiftUI

// MARK: - Street Grid Shape

/// Draws a full N×N grid of horizontal and vertical lines,
/// inset from the rect edges by `padding` (as a fraction of width).
private struct StreetGridShape: Shape {
    let divisions: Int
    let padding: CGFloat      // fraction of rect width, e.g. 0.08

    func path(in rect: CGRect) -> Path {
        let pad  = rect.width * padding
        let span = rect.width - 2 * pad
        let step = span / CGFloat(divisions)
        var p = Path()
        for i in 0...divisions {
            let pos = pad + step * CGFloat(i)
            // horizontal
            p.move(to: CGPoint(x: pad,        y: pos))
            p.addLine(to: CGPoint(x: pad + span, y: pos))
            // vertical
            p.move(to: CGPoint(x: pos, y: pad))
            p.addLine(to: CGPoint(x: pos, y: pad + span))
        }
        return p
    }
}

// MARK: - Route Path Shape

/// Draws a polyline that snaps to grid intersections
/// defined by (col, row) integer waypoints.
private struct RoutePathShape: Shape {
    let divisions: Int
    let padding: CGFloat
    let waypoints: [(Int, Int)]

    func path(in rect: CGRect) -> Path {
        let pad  = rect.width * padding
        let span = rect.width - 2 * pad
        let step = span / CGFloat(divisions)
        var p = Path()
        guard let first = waypoints.first else { return p }
        func pt(_ wp: (Int, Int)) -> CGPoint {
            CGPoint(x: pad + CGFloat(wp.0) * step,
                    y: pad + CGFloat(wp.1) * step)
        }
        p.move(to: pt(first))
        waypoints.dropFirst().forEach { p.addLine(to: pt($0)) }
        return p
    }
}

// MARK: - App Logo View

struct AppLogoView: View {
    /// Overall size of the square logo tile.
    var size: CGFloat = 100
    /// Corner radius; defaults to ~22 % of size for a rounded-rect icon shape.
    var cornerRadius: CGFloat? = nil
    /// Set to false to get a static snapshot (e.g. for app-icon export).
    var animated: Bool = true

    @State private var phase: CGFloat = 0

    // Grid + route configuration
    private let divisions = 6
    private let gridPadding: CGFloat = 0.08   // 8 % inset from each edge

    // Route waypoints on the 6×6 grid (col, row):
    //   (1,1)──►(5,1)
    //             │
    //   (2,2)◄───(5,2)
    //    │
    //   (2,4)──►(4,4)
    //             │
    //            (4,5)
    private let waypoints: [(Int, Int)] = [
        (1,1),(5,1),(5,2),(2,2),(2,4),(4,4),(4,5)
    ]

    // Fraction of total path length shown as the "snake" segment.
    private let tailLength: CGFloat = 0.38
    // Animation cycles from 0 → (1 + tailLength), then loops.
    private var cycleEnd: CGFloat { 1 + tailLength }

    var body: some View {
        let r = cornerRadius ?? size * 0.22

        ZStack {
            // ── Background ─────────────────────────────────────────
            RoundedRectangle(cornerRadius: r)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.15, blue: 0.36),
                            Color(red: 0.03, green: 0.09, blue: 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // ── Street grid ────────────────────────────────────────
            StreetGridShape(divisions: divisions, padding: gridPadding)
                .stroke(
                    Color.white.opacity(0.20),
                    style: StrokeStyle(lineWidth: max(0.8, size * 0.012),
                                       lineCap: .square)
                )

            // ── Animated red route ─────────────────────────────────
            RoutePathShape(divisions: divisions,
                           padding: gridPadding,
                           waypoints: waypoints)
                .trim(from: max(0, phase - tailLength),
                      to:   min(1, phase))
                .stroke(
                    Color(red: 1.0, green: 0.13, blue: 0.13),
                    style: StrokeStyle(
                        lineWidth: size * 0.062,
                        lineCap:   .round,
                        lineJoin:  .round
                    )
                )
                // Subtle glow under the red line
                .shadow(color: Color.red.opacity(0.55), radius: size * 0.04)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard animated else { return }
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                phase = cycleEnd
            }
        }
    }
}

// MARK: - Preview

#Preview("Animated") {
    ZStack {
        Color.black.ignoresSafeArea()
        AppLogoView(size: 220, animated: true)
    }
}

#Preview("Static") {
    ZStack {
        Color.black.ignoresSafeArea()
        AppLogoView(size: 220, animated: false)
    }
}
